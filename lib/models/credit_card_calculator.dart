class CreditCardCalculator {
  CreditCardCalculator._();

  static double availableCredit({
    required double creditLimit,
    required double outstandingBalance,
  }) {
    return (creditLimit - outstandingBalance).clamp(0, double.infinity);
  }

  static double utilization({
    required double creditLimit,
    required double outstandingBalance,
  }) {
    if (creditLimit <= 0) return 0;
    return outstandingBalance / creditLimit;
  }

  static double total(List<({double limit, double owed})> cards) {
    return cards.fold<double>(0, (sum, card) => sum + card.owed);
  }

  static double totalLimit(List<({double limit, double owed})> cards) {
    return cards.fold<double>(0, (sum, card) => sum + card.limit);
  }

  static double overallUtilization(List<({double limit, double owed})> cards) {
    final double limit = totalLimit(cards);
    return limit <= 0 ? 0 : total(cards) / limit;
  }
}
