import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/utils/amount_parser.dart';

void main() {
  test('amount parser accepts comma and space thousand separators', () {
    expect(tryParseAmount('1,000'), 1000);
    expect(tryParseAmount('10,000.50'), 10000.50);
    expect(tryParseAmount('1 000'), 1000);
    expect(tryParseAmount('10 000.50'), 10000.50);
  });

  test('amount parser still rejects invalid numeric input', () {
    expect(tryParseAmount('1,00x.50'), isNull);
    expect(tryParseAmount(''), isNull);
  });
}
