import 'dart:convert';

import '../models/backup_preview.dart';
import 'legacy_backup_migration_service.dart';

class BackupService {
  static const String _appName = 'ZakatApp';
  static const int _schemaVersion = 1;

  static String exportBackup(
    Map<String, dynamic> appStateJson, {
    Map<String, dynamic>? cloudBackupMetadata,
  }) {
    final Map<String, dynamic> counts = _getCounts(appStateJson);
    final Map<String, dynamic> root = <String, dynamic>{
      'appName': _appName,
      'schemaVersion': _schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'counts': counts,
      'appState': appStateJson,
    };
    if (cloudBackupMetadata != null && cloudBackupMetadata.isNotEmpty) {
      root['cloudBackupMetadata'] = cloudBackupMetadata;
    }
    return jsonEncode(root);
  }

  static BackupPreview parseBackupPreview(String rawJson) {
    try {
      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        throw const FormatException('Backup is not a JSON object.');
      }
      final Map<String, dynamic> root = Map<String, dynamic>.from(decoded);
      final String exportedAt = (root['exportedAt'] ?? '').toString();

      String sourceType = 'unknown';
      bool isLegacy = false;
      String schemaOrVersion = 'unknown';

      if (root['appName'] == _appName && root['appState'] is Map) {
        sourceType = 'flutter';
        schemaOrVersion = 'schemaVersion=${root['schemaVersion'] ?? _schemaVersion}';
      } else if (root['version'] != null && root['data'] is String) {
        sourceType = 'legacyV1';
        isLegacy = true;
        schemaOrVersion = 'version=${root['version']}';
      } else if (root['schema'] == 'zakatapp.backup' && root['data'] is Map) {
        sourceType = 'legacyV2';
        isLegacy = true;
        schemaOrVersion = 'schema=${root['schema']}, version=${root['version'] ?? 'unknown'}';
      }

      if (sourceType == 'unknown') {
        return BackupPreview(
          exportedAt: exportedAt,
          schemaOrVersion: 'unknown',
          isLegacy: false,
          sourceType: 'unknown',
          transactionsCount: 0,
          savingsCount: 0,
          investmentsCount: 0,
          recurringTransactionsCount: 0,
          financialPlansCount: 0,
          hasMarketData: false,
          warnings: const <String>['Unrecognized backup schema.'],
          unsupportedFields: const <String>[],
          canRestore: false,
          rawJson: rawJson,
        );
      }

      final LegacyMigrationReport report =
          LegacyBackupMigrationService().parseAndMigrateWithReport(rawJson);
      final Map<String, dynamic> counts = _getCounts(report.state);

      return BackupPreview(
        exportedAt: exportedAt,
        schemaOrVersion: schemaOrVersion,
        isLegacy: isLegacy,
        sourceType: sourceType,
        transactionsCount: counts['transactions'] as int,
        savingsCount: counts['savings'] as int,
        investmentsCount: counts['investments'] as int,
        recurringTransactionsCount: counts['recurringTransactions'] as int,
        financialPlansCount: counts['financialPlans'] as int,
        hasMarketData: report.state['marketData'] is Map &&
            (report.state['marketData'] as Map).isNotEmpty,
        warnings: report.warnings,
        unsupportedFields: report.unsupportedFields,
        canRestore: true,
        rawJson: rawJson,
      );
    } on FormatException catch (e) {
      return BackupPreview(
        exportedAt: '',
        schemaOrVersion: 'unknown',
        isLegacy: false,
        sourceType: 'unknown',
        transactionsCount: 0,
        savingsCount: 0,
        investmentsCount: 0,
        recurringTransactionsCount: 0,
        financialPlansCount: 0,
        hasMarketData: false,
        warnings: <String>[e.message],
        unsupportedFields: const <String>[],
        canRestore: false,
        rawJson: rawJson,
      );
    } catch (e) {
      return BackupPreview(
        exportedAt: '',
        schemaOrVersion: 'unknown',
        isLegacy: false,
        sourceType: 'unknown',
        transactionsCount: 0,
        savingsCount: 0,
        investmentsCount: 0,
        recurringTransactionsCount: 0,
        financialPlansCount: 0,
        hasMarketData: false,
        warnings: <String>['Failed to parse backup file: $e'],
        unsupportedFields: const <String>[],
        canRestore: false,
        rawJson: rawJson,
      );
    }
  }

  static Map<String, dynamic> extractRawState(String rawJson) {
    return LegacyBackupMigrationService().parseAndMigrate(rawJson);
  }

  static bool hasData(Map<String, dynamic> state) {
    final Map<String, dynamic> counts = _getCounts(state);
    return (counts['transactions'] as int) +
            (counts['savings'] as int) +
            (counts['investments'] as int) +
            (counts['recurringTransactions'] as int) +
            (counts['financialPlans'] as int) >
        0;
  }

  static Map<String, dynamic> _getCounts(Map<String, dynamic> state) {
    int safeCount(dynamic value) => value is List ? value.length : 0;

    return <String, dynamic>{
      'transactions': safeCount(state['transactions']),
      'savings': safeCount(state['savings']),
      'investments': safeCount(state['investments']),
      'recurringTransactions': safeCount(state['recurringTransactions']),
      'financialPlans': safeCount(state['financialPlans']),
    };
  }
}
