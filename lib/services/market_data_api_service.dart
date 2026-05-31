import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

abstract class MarketDataApiService {
  Future<Map<String, double>?> fetchFxRatesToEgp();
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp});
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp});
}

class MarketDataApiServiceImpl implements MarketDataApiService {
  MarketDataApiServiceImpl({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  SharedPreferences? _prefs;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _cachePriceUsd(String symbol, double price) async {
    await _initPrefs();
    await _prefs?.setDouble('cached_price_usd_$symbol', price);
    // ignore: avoid_print
    print('MarketDataApiService: cached $symbol price USD $price');
  }

  Future<double?> _getCachedPriceUsd(String symbol) async {
    await _initPrefs();
    final double? cached = _prefs?.getDouble('cached_price_usd_$symbol');
    if (cached != null && cached > 0) {
      // ignore: avoid_print
      print('MarketDataApiService: using cached $symbol price USD $cached');
      return cached;
    }
    return null;
  }
  static const double _troyOunceToGrams = 31.1034768;
  static const String _hexaRateApiKey = String.fromEnvironment(
    'HEXA_RATE_API_KEY',
  );
  static const String _goldApiKey = String.fromEnvironment(
    'GOLD_API_KEY',
  );

  static const List<String> _supportedFx = <String>[
    'USD',
    'SAR',
    'AED',
    'KWD',
    'QAR',
    'EUR',
    'GBP',
    'BHD',
    'OMR',
    'JOD',
    'TRY',
    'MYR',
    'PKR',
    'IDR',
  ];

  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async {
    final Map<String, double>? fromHexa = await _fetchFxFromHexaRate();
    if (fromHexa != null) return fromHexa;
    final Map<String, double>? fromHexaProxy =
        await _fetchFxFromHexaRateProxy();
    if (fromHexaProxy != null) return fromHexaProxy;
    return _fetchFxFromOpenErApi();
  }

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async {
    if (usdToEgp <= 0) return null;
    final double? usdPerOunce = await _fetchGoldApiUsd('XAU');
    if (usdPerOunce == null || usdPerOunce <= 0) return null;
    return convertUsdPerOunceToEgpPerGram(
      usdPerOunce: usdPerOunce,
      usdToEgp: usdToEgp,
    );
  }

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async {
    if (usdToEgp <= 0) return null;
    final double? usdPerOunce = await _fetchGoldApiUsd('XAG');
    if (usdPerOunce == null || usdPerOunce <= 0) return null;
    return convertUsdPerOunceToEgpPerGram(
      usdPerOunce: usdPerOunce,
      usdToEgp: usdToEgp,
    );
  }

  Future<Map<String, double>?> _fetchFxFromHexaRate() async {
    final Uri uri = Uri.parse(
      'https://hexarate.paikama.co/api/rates/latest/USD?target=EGP',
    );
    final Map<String, String>? headers = _hexaRateApiKey.trim().isEmpty
        ? null
        : <String, String>{'Authorization': 'Bearer $_hexaRateApiKey'};
    final Map<String, dynamic>? json = await _getJson(
      uri,
      headers: headers,
    );
    if (json == null) return null;
    final double usdToEgp = _asDouble(json['mid']);
    if (usdToEgp <= 0) return null;
    return <String, double>{'EGP': 1, 'USD': usdToEgp};
  }

  Future<Map<String, double>?> _fetchFxFromHexaRateProxy() async {
    final Uri uri = Uri.parse(
      'https://api.allorigins.win/raw?url=https://hexarate.paikama.co/api/rates/latest/USD?target=EGP',
    );
    final Map<String, String>? headers = _hexaRateApiKey.trim().isEmpty
        ? null
        : <String, String>{'Authorization': 'Bearer $_hexaRateApiKey'};
    final Map<String, dynamic>? json = await _getJson(
      uri,
      headers: headers,
    );
    if (json == null) return null;
    final double usdToEgp = _asDouble(json['mid']);
    if (usdToEgp <= 0) return null;
    return <String, double>{'EGP': 1, 'USD': usdToEgp};
  }

  Future<Map<String, double>?> _fetchFxFromOpenErApi() async {
    final Uri uri = Uri.parse('https://open.er-api.com/v6/latest/USD');
    final Map<String, dynamic>? json = await _getJson(uri);
    if (json == null || (json['result'] ?? '').toString() != 'success') {
      return null;
    }
    final Map<String, dynamic> rawRates = Map<String, dynamic>.from(
      (json['rates'] as Map?) ?? <String, dynamic>{},
    );
    final double usdToEgp = _asDouble(rawRates['EGP']);
    if (usdToEgp <= 0) return null;
    final Map<String, double> toEgp = <String, double>{'EGP': 1, 'USD': usdToEgp};
    for (final String code in _supportedFx) {
      if (code == 'USD') continue;
      final double perUsd = _asDouble(rawRates[code]);
      if (perUsd <= 0) continue;
      toEgp[code] = usdToEgp / perUsd;
    }
    return toEgp;
  }

  Future<double?> _fetchGoldApiUsd(String symbol) async {
    // Note: metals.live fails on iOS with TLS SNI errors, so we skip it
    // and go directly to gold-api.com with retry logic

    Uri uri = Uri.parse('https://api.gold-api.com/price/$symbol');
    if (_goldApiKey.trim().isNotEmpty) {
      final Map<String, String> qp = Map<String, String>.from(uri.queryParameters);
      qp['apikey'] = _goldApiKey;
      uri = uri.replace(queryParameters: qp);
    }
    
    try {
      final HttpClientRequest request = await _httpClient.getUrl(uri);
      request.headers.add('accept', 'application/json');
      request.headers.add('user-agent', 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15');
      if (_goldApiKey.trim().isNotEmpty) {
        try {
          request.headers.add('x-api-key', _goldApiKey);
        } catch (_) {}
      }
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      
      if (response.statusCode != 200) {
        // ignore: avoid_print
        print('MarketDataApiService: gold-api returned ${response.statusCode} for $symbol');
        final double? cached = await _getCachedPriceUsd(symbol);
        return cached;
      }
      
      final Map<String, dynamic>? json = jsonDecode(body) as Map<String, dynamic>?;
      if (json == null) {
        final double? cached = await _getCachedPriceUsd(symbol);
        return cached;
      }
      
      final double value = extractUsdPerOunceFromGoldApiJson(json, symbol: symbol);
      if (value <= 0) {
        // ignore: avoid_print
        print('MarketDataApiService: gold-api payload missing usable price for $symbol');
        final double? cached = await _getCachedPriceUsd(symbol);
        return cached;
      }
      
      // Success — cache this price
      await _cachePriceUsd(symbol, value);
      return value;
    } catch (error) {
      // ignore: avoid_print
      print('MarketDataApiService: gold-api request failed for $symbol: $error');
      final double? cached = await _getCachedPriceUsd(symbol);
      return cached;
    }
  }

  static double extractUsdPerOunceFromGoldApiJson(
    Map<String, dynamic> json, {
    required String symbol,
  }) {
    final double fromPrice = _asDouble(json['price']);
    if (fromPrice > 0) return fromPrice;

    final double fromAsk = _asDouble(json['ask']);
    if (fromAsk > 0) return fromAsk;

    final double fromBid = _asDouble(json['bid']);
    if (fromBid > 0) return fromBid;

    final String metal = symbol.toUpperCase();
    if (metal == 'XAU') {
      final double gram24k = _asDouble(
        json['price_gram_24k'] ?? json['price_gram_9999'],
      );
      if (gram24k > 0) return gram24k * _troyOunceToGrams;
    }

    final double gramAny = _asDouble(
      json['price_gram'] ?? json['price_per_gram'],
    );
    if (gramAny > 0) return gramAny * _troyOunceToGrams;

    return 0;
  }

  Future<Map<String, dynamic>?> _getJson(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final dynamic value = await _getJsonDynamic(uri, headers: headers);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Future<dynamic> _getJsonDynamic(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    try {
      final HttpClientRequest request = await _httpClient.getUrl(uri);
      headers?.forEach(request.headers.add);
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) {
        // ignore: avoid_print
        print(
          'MarketDataApiService: request failed ${uri.toString()} with status ${response.statusCode}',
        );
        return null;
      }
      final String body = await response.transform(utf8.decoder).join();
      return jsonDecode(body);
    } catch (error) {
      // ignore: avoid_print
      print('MarketDataApiService: request error ${uri.toString()}: $error');
      return null;
    }
  }

  static double convertUsdPerOunceToEgpPerGram({
    required double usdPerOunce,
    required double usdToEgp,
  }) {
    return (usdPerOunce / _troyOunceToGrams) * usdToEgp;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }
}

class MarketRefreshResult {
  const MarketRefreshResult({
    required this.success,
    required this.updatedFields,
    required this.message,
  });

  final bool success;
  final int updatedFields;
  final String message;
}
