import SwiftUI
#if os(watchOS)
import WatchKit
#endif

/// Lightweight Watch-native flow for Currency Exchange with authoritative iPhone FX quoting.
public struct WatchCurrencyExchangeQuickAddView: View {
  @EnvironmentObject private var connectivity: WatchConnectivityManager
  @Environment(\.presentationMode) private var presentationMode

  @State private var fromCurrency: String = "USD"
  @State private var toCurrency: String = "SAR"
  @State private var sourceAmount: Double = 0.0

  @State private var targetAmount: Double = 0.0
  @State private var exchangeRate: Double = 0.0

  @State private var currentStep: FlowStep = .currencies
  @State private var isFetchingQuote: Bool = false
  @State private var quoteErrorMessage: String?

  private enum FlowStep {
    case currencies
    case amount
    case quoting
    case review
  }

  public init() {}

  private var isValidCurrencyPair: Bool {
    return !fromCurrency.isEmpty && !toCurrency.isEmpty && fromCurrency != toCurrency
  }

  public var body: some View {
    VStack {
      switch currentStep {
      case .currencies:
        currenciesView

      case .amount:
        WatchAmountPadView(
          amount: $sourceAmount,
          currency: fromCurrency,
          title: "Source Amount"
        ) {
          requestAuthoritativeQuote()
        }

      case .quoting:
        quotingLoadingView

      case .review:
        WatchQuickAddReviewView(
          actionTitle: "Exchange",
          amount: sourceAmount,
          currency: fromCurrency,
          targetAmount: targetAmount,
          targetCurrency: toCurrency,
          descriptionText: exchangeRate > 0 ? "Rate: 1 \(fromCurrency) = \(String(format: "%.4f", exchangeRate)) \(toCurrency)" : nil,
          submissionAction: "executeCurrencyExchange",
          extraFields: [
            "sourceCurrency": fromCurrency,
            "targetCurrency": toCurrency,
            "sourceAmount": sourceAmount,
            "targetAmount": targetAmount
          ],
          onDone: {
            presentationMode.wrappedValue.dismiss()
          }
        )
      }
    }
    .navigationTitle("Exchange")
    .onAppear {
      let mainCurr = connectivity.snapshot.mainCurrency.isEmpty ? "SAR" : connectivity.snapshot.mainCurrency
      toCurrency = mainCurr
      if let alternate = connectivity.snapshot.currencies.first(where: { $0 != mainCurr }) {
        fromCurrency = alternate
      } else {
        fromCurrency = "USD"
      }
    }
  }

  private var currenciesView: some View {
    ScrollView {
      VStack(spacing: 8) {
        // From Currency Picker
        VStack(alignment: .leading, spacing: 2) {
          Text("From Currency")
            .font(.system(size: 10))
            .foregroundColor(WatchTheme.slateMuted)

          Picker("", selection: $fromCurrency) {
            ForEach(connectivity.snapshot.currencies, id: \.self) { curr in
              Text(curr).tag(curr)
            }
          }
          .pickerStyle(.navigationLink)
          .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 34)
          .multilineTextAlignment(.center)
        }
        .padding(6)
        .background(WatchTheme.cardSurface)
        .cornerRadius(8)

        // Arrow
        Image(systemName: "arrow.down")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(WatchTheme.gold)

        // To Currency Picker
        VStack(alignment: .leading, spacing: 2) {
          Text("To Currency")
            .font(.system(size: 10))
            .foregroundColor(WatchTheme.slateMuted)

          Picker("", selection: $toCurrency) {
            ForEach(connectivity.snapshot.currencies, id: \.self) { curr in
              Text(curr).tag(curr)
            }
          }
          .pickerStyle(.navigationLink)
          .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 34)
          .multilineTextAlignment(.center)
        }
        .padding(6)
        .background(WatchTheme.cardSurface)
        .cornerRadius(8)

        if fromCurrency == toCurrency {
          Text("Currencies must be different.")
            .font(.system(size: 9))
            .foregroundColor(WatchTheme.errorRed)
        }

        // Continue to Amount
        Button {
          currentStep = .amount
        } label: {
          HStack {
            Text("Enter Amount")
              .font(.system(size: 13, weight: .bold))
            Image(systemName: "arrow.right")
              .font(.system(size: 11, weight: .bold))
          }
          .foregroundColor(isValidCurrencyPair ? WatchTheme.deepEmerald : WatchTheme.slateMuted)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 9)
          .background(isValidCurrencyPair ? WatchTheme.gold : WatchTheme.cardSurface)
          .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(!isValidCurrencyPair)
        .padding(.top, 4)
      }
      .padding(.horizontal, 4)
    }
  }

  private var quotingLoadingView: some View {
    VStack(spacing: 12) {
      if isFetchingQuote {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: WatchTheme.gold))
          .scaleEffect(1.2)

        Text("Requesting Authoritative Quote...")
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(WatchTheme.offWhite)
          .multilineTextAlignment(.center)

        Text("Using iPhone market exchange rates")
          .font(.system(size: 9))
          .foregroundColor(WatchTheme.slateMuted)
      } else if let error = quoteErrorMessage {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 28))
          .foregroundColor(WatchTheme.errorRed)

        Text("Quote Failed")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(WatchTheme.offWhite)

        Text(error)
          .font(.system(size: 10))
          .foregroundColor(WatchTheme.slateMuted)
          .multilineTextAlignment(.center)

        Button {
          requestAuthoritativeQuote()
        } label: {
          Text("Retry Quote")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(WatchTheme.deepEmerald)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(WatchTheme.gold)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)

        Button {
          currentStep = .amount
        } label: {
          Text("Back to Amount")
            .font(.system(size: 11))
            .foregroundColor(WatchTheme.slateMuted)
        }
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: .infinity)
    .padding()
  }

  private func requestAuthoritativeQuote() {
    currentStep = .quoting
    isFetchingQuote = true
    quoteErrorMessage = nil

    let quotePayload: [String: Any] = [
      "sourceCurrency": fromCurrency,
      "targetCurrency": toCurrency,
      "sourceAmount": sourceAmount
    ]

    connectivity.sendCommand(action: "quoteCurrencyExchange", extraFields: quotePayload) { result in
      isFetchingQuote = false
      if result.isSuccess, let quotedTarget = result.targetAmount {
        targetAmount = quotedTarget
        exchangeRate = result.rate ?? (sourceAmount > 0 ? (quotedTarget / sourceAmount) : 0.0)
        currentStep = .review
      } else {
        quoteErrorMessage = result.message ?? "iPhone unavailable for quote."
      }
    }
  }
}
