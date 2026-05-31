import 'dart:convert';
import 'dart:io';

abstract class MarketDataApiService {
  Future<Map<String, double>?> fetchFxRatesToEgp();
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp});
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp});
}

class MarketDataApiServiceImpl implements MarketDataApiService {
  MarketDataApiServiceImpl({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  static const double _troyOunceToGrams = 31.1034768;
  static const String _hexaRateApiKey = String.fromEnvironment(
    'HEXA_RATE_API_KEY',
  );
  static const String _goldApiKey = String.fromEnvironment('GOLD_API_KEY');

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
    final Map<String, double>? fromHexaProxy = await _fetchFxFromHexaRateProxy();
    if (fromHexaProxy != null) return fromHexaProxy;
    final Map<String, double>? fromFrankfurter = await _fetchFxFromFrankfurter();
    if (fromFrankfurter != null) return fromFrankfurter;
    return _fetchFxFromOpenErApi();
  }

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async {
    if (usdToEgp <= 0) return null;
    final double? usdPerOunce =
        await _fetchMetalsLiveSpot('gold') ?? await _fetchGoldApiUsd('XAU');
    if (usdPerOunce == null || usdPerOunce <= 0) return null;
    return convertUsdPerOunceToEgpPerGram(
      usdPerOunce: usdPerOunce,
      usdToEgp: usdToEgp,
    );
  }

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async {
    if (usdToEgp <= 0) return null;
    final double? usdPerOunce =
        await _fetchMetalsLiveSpot('silver') ?? await _fetchGoldApiUsd('XAG');
    if (usdPerOunce == null || usdPerOunce <= 0) return null;
    return convertUsdPerOunceToEgpPerGram(
      usdPerOunce: usdPerOunce,
      usdToEgp: usdToEgp,
    );
  }

  Future<Map<String, double>?> _fetchFxFromHexaRate() async {
    if (_hexaRateApiKey.trim().isEmpty) return null;
    final Uri uri = Uri.parse(
      'https://hexarate.paikama.co/api/rates/latest/USD?target=EGP',
    );
    final Map<String, dynamic>? json = await _getJson(
      uri,
      headers: <String, String>{'Authorization': 'Bearer $_hexaRateApiKey'},
    );
    if (json == null) return null;
    final double usdToEgp = _asDouble(json['mid']);
    if (usdToEgp <= 0) return null;
    return <String, double>{'EGP': 1, 'USD': usdToEgp};
  }

  Future<Map<String, double>?> _fetchFxFromHexaRateProxy() async {
    if (_hexaRateApiKey.trim().isEmpty) return null;
    final Uri uri = Uri.parse(
      'https://api.allorigins.win/raw?url=https://hexarate.paikama.co/api/rates/latest/USD?target=EGP',
    );
    final Map<String, dynamic>? json = await _getJson(
      uri,
      headers: <String, String>{'Authorization': 'Bearer $_hexaRateApiKey'},
    );
    if (json == null) return null;
    final double usdToEgp = _asDouble(json['mid']);
    if (usdToEgp <= 0) return null;
    return <String, double>{'EGP': 1, 'USD': usdToEgp};
  }

  Future<Map<String, double>?> _fetchFxFromFrankfurter() async {
    final Uri uri = Uri.parse(
      'https://api.frankfurter.app/latest?from=USD&to=EGP,SAR',
    );
    final Map<String, dynamic>? json = await _getJson(uri);
    if (json == null) return null;
    final Map<String, dynamic> rates = Map<String, dynamic>.from(
      (json['rates'] as Map?) ?? <String, dynamic>{},
    );
    final double usdToEgp = _asDouble(rates['EGP']);
    final double usdToSar = _asDouble(rates['SAR']);
    if (usdToEgp <= 0 || usdToSar <= 0) return null;
    return <String, double>{
      'EGP': 1,
      'USD': usdToEgp,
      'SAR': usdToEgp / usdToSar,
    };
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

  Future<double?> _fetchMetalsLiveSpot(String symbol) async {
    final Uri uri = Uri.parse('https://api.metals.live/v1/spot');
    final dynamic json = await _getJsonDynamic(uri);
    if (json is List) {
      for (final dynamic row in json) {
        if (row is Map && row.containsKey(symbol)) {
          final double price = _asDouble(row[symbol]);
          if (price > 0) return price;
        }
      }
    }
    return null;
  }

  Future<double?> _fetchGoldApiUsd(String symbol) async {
    if (_goldApiKey.trim().isEmpty) return null;
    final Uri uri = Uri.parse('https://www.goldapi.io/api/$symbol/USD');
    final Map<String, dynamic>? json = await _getJson(
      uri,
      headers: <String, String>{'x-access-token': _goldApiKey},
    );
    if (json == null) return null;
    final double value = _asDouble(json['price']);
    return value > 0 ? value : null;
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
      if (response.statusCode != 200) return null;
      final String body = await response.transform(utf8.decoder).join();
      return jsonDecode(body);
    } catch (_) {
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
