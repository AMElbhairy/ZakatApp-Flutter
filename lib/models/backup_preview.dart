class BackupPreview {
  const BackupPreview({
    required this.exportedAt,
    required this.schemaOrVersion,
    required this.isLegacy,
    required this.sourceType,
    required this.transactionsCount,
    required this.savingsCount,
    required this.investmentsCount,
    required this.recurringTransactionsCount,
    required this.financialPlansCount,
    required this.hasMarketData,
    required this.warnings,
    required this.unsupportedFields,
    required this.canRestore,
    required this.rawJson,
  });

  final String exportedAt;
  final String schemaOrVersion;
  final bool isLegacy;
  final String sourceType;
  final int transactionsCount;
  final int savingsCount;
  final int investmentsCount;
  final int recurringTransactionsCount;
  final int financialPlansCount;
  final bool hasMarketData;
  final List<String> warnings;
  final List<String> unsupportedFields;
  final bool canRestore;
  final String rawJson;
}
