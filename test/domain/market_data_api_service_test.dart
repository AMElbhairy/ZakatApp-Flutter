import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';

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
}
