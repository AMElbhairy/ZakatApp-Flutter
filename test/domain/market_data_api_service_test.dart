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
}
