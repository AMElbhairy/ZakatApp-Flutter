import 'package:flutter_test/flutter_test.dart';

import 'package:zakatapp_flutter/models/credit_card_calculator.dart';

void main() {
  test('calculates available credit and utilization', () {
    expect(
      CreditCardCalculator.availableCredit(
        creditLimit: 50000,
        outstandingBalance: 12000,
      ),
      38000,
    );
    expect(
      CreditCardCalculator.utilization(
        creditLimit: 50000,
        outstandingBalance: 12000,
      ),
      0.24,
    );
  });

  test('aggregates multiple cards', () {
    const cards = <({double limit, double owed})>[
      (limit: 50000, owed: 10000),
      (limit: 30000, owed: 5000),
    ];
    expect(CreditCardCalculator.totalLimit(cards), 80000);
    expect(CreditCardCalculator.total(cards), 15000);
    expect(CreditCardCalculator.overallUtilization(cards), 0.1875);
  });

  test('does not return negative available credit or invalid utilization', () {
    expect(
      CreditCardCalculator.availableCredit(
        creditLimit: 100,
        outstandingBalance: 120,
      ),
      0,
    );
    expect(
      CreditCardCalculator.utilization(creditLimit: 0, outstandingBalance: 10),
      0,
    );
  });
}
