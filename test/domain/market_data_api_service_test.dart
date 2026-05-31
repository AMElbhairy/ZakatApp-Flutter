import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode, this.body)
      : _stream = Stream<List<int>>.fromIterable(<List<int>>[utf8.encode(body)]);

  @override
  final int statusCode;
  final String body;
  final Stream<List<int>> _stream;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this._response);

  final HttpClientResponse _response;
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _response;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this.routes);

  final Map<String, _FakeHttpClientResponse> routes;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final _FakeHttpClientResponse? response = routes[url.toString()];
    if (response == null) {
      return _FakeHttpClientRequest(_FakeHttpClientResponse(404, '{}'));
    }
    return _FakeHttpClientRequest(response);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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
