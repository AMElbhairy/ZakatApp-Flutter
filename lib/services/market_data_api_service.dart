import 'dart:convert';
import 'dart:io';

abstract class MarketDataApiService {
  Future<Map<String, double>?> fetchFxRatesToEgp();
  Future<double?> fetchGold24kPerGramEgp();
  Future<double?> fetchSilverPerGramEgp();
}

class MarketDataApiServiceImpl implements MarketDataApiService {
  MarketDataApiServiceImpl({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

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
    try {
      final Uri uri = Uri.parse('https://open.er-api.com/v6/latest/USD');
      final HttpClientRequest request = await _httpClient.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) return null;
      final String body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;
      if ((json['result'] ?? '').toString() != 'success') return null;

      final Map<String, dynamic> rawRates =
          Map<String, dynamic>.from((json['rates'] as Map?) ?? <String, dynamic>{});
      final double usdToEgp = _asDouble(rawRates['EGP']);
      if (usdToEgp <= 0) return null;

      final Map<String, double> toEgp = <String, double>{'EGP': 1, 'USD': usdToEgp};
      for (final String code in _supportedFx) {
        if (code == 'USD') continue;
        final double perUsd = _asDouble(rawRates[code]);
        if (perUsd <= 0) continue;
        toEgp[code] = usdToEgp / perUsd;
      }

      if (!toEgp.containsKey('SAR')) return null;
      return toEgp;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<double?> fetchGold24kPerGramEgp() async {
    // Placeholder until a stable metals provider is configured.
    return null;
  }

  @override
  Future<double?> fetchSilverPerGramEgp() async {
    // Placeholder until a stable metals provider is configured.
    return null;
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
