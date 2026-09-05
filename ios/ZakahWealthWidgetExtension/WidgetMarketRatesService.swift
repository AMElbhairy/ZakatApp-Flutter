import Foundation

struct WidgetMarketRates: Codable {
    let goldPrice24kEgp: Double
    let silverPriceEgp: Double
    let ratesToEgp: [String: Double]
    let fetchedAt: Date
}

struct WidgetMarketRatesCache: Codable {
    let baseCurrency: String
    let goldPrice24kEgp: Double
    let silverPriceEgp: Double
    let ratesToEgp: [String: Double]
    let fetchedAt: String
    let schemaVersion: Int
}

final class WidgetMarketRatesService {
    private static let suiteName = "group.com.zakahwealth.app"
    private static let cacheKey = "widget_market_rates_cache"
    private static let troyOunceToGrams = 31.1034768

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func loadCache(baseCurrency: String) -> WidgetMarketRates? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        do {
            let cache = try JSONDecoder().decode(WidgetMarketRatesCache.self, from: data)
            guard cache.schemaVersion == 1, cache.baseCurrency == baseCurrency else {
                NSLog("[WidgetRatesService] Cache base currency mismatch or unsupported schemaVersion")
                return nil
            }
            let formatter = ISO8601DateFormatter()
            let date = formatter.date(from: cache.fetchedAt) ?? Date()
            return WidgetMarketRates(
                goldPrice24kEgp: cache.goldPrice24kEgp,
                silverPriceEgp: cache.silverPriceEgp,
                ratesToEgp: cache.ratesToEgp,
                fetchedAt: date
            )
        } catch {
            NSLog("[WidgetRatesService] Failed to load cache: %@", error.localizedDescription)
            return nil
        }
    }

    static func saveCache(rates: WidgetMarketRates, baseCurrency: String) {
        let formatter = ISO8601DateFormatter()
        let cache = WidgetMarketRatesCache(
            baseCurrency: baseCurrency,
            goldPrice24kEgp: rates.goldPrice24kEgp,
            silverPriceEgp: rates.silverPriceEgp,
            ratesToEgp: rates.ratesToEgp,
            fetchedAt: formatter.string(from: rates.fetchedAt),
            schemaVersion: 1
        )
        do {
            let data = try JSONEncoder().encode(cache)
            defaults.set(data, forKey: cacheKey)
            NSLog("[WidgetRatesService] Saved rates to cache for currency: %@", baseCurrency)
        } catch {
            NSLog("[WidgetRatesService] Failed to save cache: %@", error.localizedDescription)
        }
    }

    static func fetchRates(baseCurrency: String) async -> WidgetMarketRates {
        let cached = loadCache(baseCurrency: baseCurrency)

        // Perform parallel tasks
        let session = URLSession(configuration: .ephemeral)
        
        async let fxResult = fetchFX(session: session)
        async let goldResult = fetchMetal(symbol: "XAU", session: session)
        async let silverResult = fetchMetal(symbol: "XAG", session: session)

        let fxRates = await fxResult
        let goldOunce = await goldResult
        let silverOunce = await silverResult

        let finalRatesToEgp: [String: Double]
        let usdToEgp: Double
        
        if let fx = fxRates {
            finalRatesToEgp = fx
            usdToEgp = fx["USD"] ?? 0.0
        } else {
            finalRatesToEgp = cached?.ratesToEgp ?? ["EGP": 1.0, "USD": 50.0, "SAR": 13.3]
            usdToEgp = finalRatesToEgp["USD"] ?? 50.0
        }

        let finalGoldEgp: Double
        if let goldUsd = goldOunce, usdToEgp > 0 {
            finalGoldEgp = (goldUsd / troyOunceToGrams) * usdToEgp
        } else {
            finalGoldEgp = cached?.goldPrice24kEgp ?? 3000.0
        }

        let finalSilverEgp: Double
        if let silverUsd = silverOunce, usdToEgp > 0 {
            finalSilverEgp = (silverUsd / troyOunceToGrams) * usdToEgp
        } else {
            finalSilverEgp = cached?.silverPriceEgp ?? 40.0
        }

        let result = WidgetMarketRates(
            goldPrice24kEgp: finalGoldEgp,
            silverPriceEgp: finalSilverEgp,
            ratesToEgp: finalRatesToEgp,
            fetchedAt: Date()
        )

        // Save successful elements to cache
        saveCache(rates: result, baseCurrency: baseCurrency)

        return result
    }

    private static func fetchFX(session: URLSession) async -> [String: Double]? {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let rates = json?["rates"] as? [String: Any], let usdToEgp = rates["EGP"] as? Double else { return nil }
            
            var toEgp: [String: Double] = ["EGP": 1.0, "USD": usdToEgp]
            let supportedFx = ["SAR", "AED", "KWD", "QAR", "EUR", "GBP", "BHD", "OMR", "JOD", "TRY", "MYR", "PKR", "IDR"]
            for code in supportedFx {
                if let perUsd = rates[code] as? Double, perUsd > 0 {
                    toEgp[code] = usdToEgp / perUsd
                }
            }
            return toEgp;
        } catch {
            NSLog("[WidgetRatesService] FX fetch failed: %@", error.localizedDescription)
            return nil
        }
    }

    private static func fetchMetal(symbol: String, session: URLSession) async -> Double? {
        guard let url = URL(string: "https://api.gold-api.com/price/\(symbol)") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["price"] as? Double
        } catch {
            NSLog("[WidgetRatesService] Metal \(symbol) fetch failed: %@", error.localizedDescription)
            return nil
        }
    }
}
