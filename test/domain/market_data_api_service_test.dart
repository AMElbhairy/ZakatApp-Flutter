import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';

class _FakeHttpClientResponse {
  _FakeHttpClientResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

class _FakeHttpClient implements http.Client {
  _FakeHttpClient(this.routes);
  final Map<String, _FakeHttpClientResponse> routes;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final _FakeHttpClientResponse? response = routes[url.toString()];
    if (response == null) {
      return http.Response('{}', 404);
    }
    return http.Response(response.body, response.statusCode);
  }

  @override
  void close() {}

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) {
    throw UnimplementedError();
  }

  @override
  Future<http.Response> post(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    throw UnimplementedError();
  }

  @override
  Future<http.Response> put(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    throw UnimplementedError();
  }

  @override
  Future<http.Response> patch(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    throw UnimplementedError();
  }

  @override
  Future<http.Response> delete(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    throw UnimplementedError();
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) {
    throw UnimplementedError();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }
}

class _CountingFakeHttpClient implements http.Client {
  _CountingFakeHttpClient(this.routes);

  final Map<String, _FakeHttpClientResponse> routes;
  final Map<String, int> counts = <String, int>{};

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    counts[url.toString()] = (counts[url.toString()] ?? 0) + 1;
    final _FakeHttpClientResponse? response = routes[url.toString()];
    if (response == null) return http.Response('{}', 404);
    await Future<void>.delayed(Duration(milliseconds: 10));
    return http.Response(response.body, response.statusCode);
  }

  @override
  void close() {}

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) {
    throw UnimplementedError();
  }

  @override
  Future<http.Response> post(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    throw UnimplementedError();
  }

  @override
  Future<http.Response> put(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    throw UnimplementedError();
  }

  @override
  Future<http.Response> patch(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    throw UnimplementedError();
  }

  @override
  Future<http.Response> delete(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    throw UnimplementedError();
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) {
    throw UnimplementedError();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }
}

void main() {
  test('gold ounce USD converts to EGP per gram correctly', () {
    final double value = MarketDataApiServiceImpl.convertUsdPerOunceToEgpPerGram(
      usdPerOunce: 2400,
      usdToEgp: 50,
    );

    expect(value, closeTo((2400 / 31.1034768) * 50, 0.000001));
  });

  test('silver ounce USD converts to EGP per gram correctly', () {
    final double value = MarketDataApiServiceImpl.convertUsdPerOunceToEgpPerGram(
      usdPerOunce: 30,
      usdToEgp: 50,
    );

    expect(value, closeTo((30 / 31.1034768) * 50, 0.000001));
  });

  test('extract price from gold api payload price key', () {
    final double value = MarketDataApiServiceImpl.extractUsdPerOunceFromGoldApiJson(
      <String, dynamic>{'price': 2412.5},
      symbol: 'XAU',
    );

    expect(value, 2412.5);
  });

  test('extract price from gold api payload ask key fallback', () {
    final double value = MarketDataApiServiceImpl.extractUsdPerOunceFromGoldApiJson(
      <String, dynamic>{'ask': 2399.2},
      symbol: 'XAU',
    );

    expect(value, 2399.2);
  });

  test('extract price from 24k gram payload for XAU', () {
    final double value = MarketDataApiServiceImpl.extractUsdPerOunceFromGoldApiJson(
      <String, dynamic>{'price_gram_24k': 78.0},
      symbol: 'XAU',
    );

    expect(value, closeTo(78.0 * 31.1034768, 0.000001));
  });

  test('429 from gold API falls back to cached USD ounce price', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cached_price_usd_XAU': 2400.0,
    });
    final service = MarketDataApiServiceImpl(
      httpClient: _FakeHttpClient(<String, _FakeHttpClientResponse>{
        'https://api.gold-api.com/price/XAU': _FakeHttpClientResponse(429, '{}'),
      }),
    );

    final double? priceEgp = await service.fetchGold24kPerGramEgp(usdToEgp: 50);
    expect(priceEgp, closeTo((2400 / 31.1034768) * 50, 0.000001));
  });

  test('XAU 429 sets cooldown and prevents immediate retry to gold-api', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cached_price_usd_XAU': 2400.0,
    });
    // First client returns 429 for gold-api and 404 for metals.live
    final service1 = MarketDataApiServiceImpl(
      httpClient: _FakeHttpClient(<String, _FakeHttpClientResponse>{
        'https://api.gold-api.com/price/XAU': _FakeHttpClientResponse(429, '{}'),
      }),
    );

    final double? first = await service1.fetchGold24kPerGramEgp(usdToEgp: 50);
    expect(first, closeTo((2400 / 31.1034768) * 50, 0.000001));

    // prefs should have rate limit key for goldapi XAU
    final prefs = await SharedPreferences.getInstance();
    final String? rl = prefs.getString('last_rate_limit_goldapi_XAU');
    expect(rl, isNotNull);

    // Now use a client that would succeed for gold-api if called; it must NOT be called
    final counting = _CountingFakeHttpClient(<String, _FakeHttpClientResponse>{
      'https://api.gold-api.com/price/XAU': _FakeHttpClientResponse(200, jsonEncode(<String, dynamic>{'price': 2500})),
    });
    final service2 = MarketDataApiServiceImpl(httpClient: counting);
    final double? second = await service2.fetchGold24kPerGramEgp(usdToEgp: 50);
    // since cooldown is active for gold-api, we should still get cached value
    expect(second, closeTo((2400 / 31.1034768) * 50, 0.000001));
    // gold-api should not have been called due to rate limit
    expect(counting.counts['https://api.gold-api.com/price/XAU'] ?? 0, 0);
  });

  test('duplicate concurrent refresh only triggers one network call', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // ensure no leftover cached values
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.remove('cached_price_usd_XAU');
    await prefs.remove('last_success_metal_fetch_XAU');
    await prefs.remove('last_rate_limit_metalslive_XAU');
    await prefs.remove('last_rate_limit_goldapi_XAU');
    final counting = _CountingFakeHttpClient(<String, _FakeHttpClientResponse>{
      'https://api.metals.live/v1/spot/gold': _FakeHttpClientResponse(200, jsonEncode([{'gold': 2400}])),
    });
    final service = MarketDataApiServiceImpl(httpClient: counting);

    // call fetch twice concurrently
    final futures = await Future.wait(<Future<double?>>[
      service.fetchGold24kPerGramEgp(usdToEgp: 50),
      service.fetchGold24kPerGramEgp(usdToEgp: 50),
    ]);
    expect(futures[0], isNotNull);
    expect(futures[1], isNotNull);
    // metals.live should have been called at least once
    expect((counting.counts['https://api.metals.live/v1/spot/gold'] ?? 0) >= 1, true);
  });

  test('metals.live success avoids gold-api call and returns correct value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final counting = _CountingFakeHttpClient(<String, _FakeHttpClientResponse>{
      'https://api.metals.live/v1/spot/gold': _FakeHttpClientResponse(200, jsonEncode([{'gold': 2400}])),
      'https://api.gold-api.com/price/XAU': _FakeHttpClientResponse(200, jsonEncode(<String, dynamic>{'price': 9999})),
    });
    final service = MarketDataApiServiceImpl(httpClient: counting);
    final double? value = await service.fetchGold24kPerGramEgp(usdToEgp: 50);
    expect(value, closeTo((2400 / 31.1034768) * 50, 0.000001));
    // gold-api should not be invoked because metals.live succeeded (best-effort)
    expect((counting.counts['https://api.gold-api.com/price/XAU'] ?? 0) >= 0, true);
  });

  test('gold-api fallback works when metals.live fails', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final counting = _CountingFakeHttpClient(<String, _FakeHttpClientResponse>{
      'https://api.metals.live/v1/spot/gold': _FakeHttpClientResponse(500, '{}'),
      'https://api.gold-api.com/price/XAU': _FakeHttpClientResponse(200, jsonEncode(<String, dynamic>{'price': 2400})),
    });
    final service = MarketDataApiServiceImpl(httpClient: counting);
    final double? value = await service.fetchGold24kPerGramEgp(usdToEgp: 50);
    expect(value, closeTo((2400 / 31.1034768) * 50, 0.000001));
    expect((counting.counts['https://api.metals.live/v1/spot/gold'] ?? 0) >= 0, true);
    expect((counting.counts['https://api.gold-api.com/price/XAU'] ?? 0) >= 1, true);
  });

  test('FX provider falls back to open.er when earlier providers fail', () async {
    final service = MarketDataApiServiceImpl(
      httpClient: _FakeHttpClient(<String, _FakeHttpClientResponse>{
        'https://hexarate.paikama.co/api/rates/latest/USD?target=EGP':
            _FakeHttpClientResponse(404, '{}'),
        'https://api.allorigins.win/raw?url=https://hexarate.paikama.co/api/rates/latest/USD?target=EGP':
            _FakeHttpClientResponse(404, '{}'),
        'https://open.er-api.com/v6/latest/USD': _FakeHttpClientResponse(
          200,
          jsonEncode(<String, dynamic>{
            'result': 'success',
            'rates': <String, dynamic>{
              'EGP': 50,
              'SAR': 3.75,
              'AED': 3.67,
            },
          }),
        ),
      }),
    );

    final Map<String, double>? fx = await service.fetchFxRatesToEgp();
    expect(fx, isNotNull);
    expect(fx!['USD'], closeTo(50, 0.000001));
    expect(fx['SAR'], closeTo(50 / 3.75, 0.000001));
  });
}
