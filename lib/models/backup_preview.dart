class BackupPreview {
  const BackupPreview({
    required this.transactionsCount,
    required this.savingsCount,
    required this.investmentsCount,
    required this.recurringCount,
    required this.financialPlansCount,
    required this.exportedAt,
    required this.version,
    required this.isLegacy,
    required this.rawJson,
    required this.hasMarketData,
  });

  final int transactionsCount;
  final int savingsCount;
  final int investmentsCount;
  final int recurringCount;
  final int financialPlansCount;
  final String exportedAt;
  final int version;
  final bool isLegacy;
  final String rawJson;
  final bool hasMarketData;

  int get totalAssets => savingsCount + investmentsCount;
}