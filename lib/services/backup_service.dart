import 'dart:convert';

import '../models/backup_preview.dart';

class BackupService {
  static const String _appName = 'ZakatApp';
  static const int _schemaVersion = 1;

  /// Exports current AppState JSON to a string matching the new format.
  static String exportBackup(Map<String, dynamic> appStateJson) {
    final counts = _getCounts(appStateJson);
    final data = <String, dynamic>{
      'appName': _appName,
      'schemaVersion': _schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'appState': appStateJson,
      'counts': counts,
    };
    return jsonEncode(data);
  }

  static Map<String, dynamic> _getCounts(Map<String, dynamic> state) {
    return <String, dynamic>{
      'transactions': (state['transactions'] as List<dynamic>?)?.length ?? 0,
      'savings': (state['savings'] as List<dynamic>?)?.length ?? 0,
      'investments': (state['investments'] as List<dynamic>?)?.length ?? 0,
      'recurring': (state['recurringTransactions'] as List<dynamic>?)?.length ?? 0,
      'financialPlans': (state['financialPlans'] as List<dynamic>?)?.length ?? 0,
    };
  }

  /// Parses a JSON backup string and returns a BackupPreview.
  static BackupPreview parseBackup(String jsonString) {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid backup format: Not a JSON object');
      }

      // Detect Old ZakatApp Legacy Schemas (V1 and V2 JS App)
      if (decoded['schema'] == 'zakatapp.backup' ||
          (decoded['version'] != null && decoded['data'] != null)) {
        return _parseLegacy(decoded, jsonString);
      }

      // Enforce Current Flutter App Schema Signature
      if (decoded['appName'] != _appName || decoded['appState'] == null) {
        throw const FormatException('Unrecognized backup file signature');
      }

      final Map<String, dynamic> state = decoded['appState'] as Map<String, dynamic>;
      final Map<String, dynamic> counts =
          (decoded['counts'] as Map<String, dynamic>?) ?? _getCounts(state);

      return BackupPreview(
        transactionsCount: counts['transactions'] as int? ?? 0,
        savingsCount: counts['savings'] as int? ?? 0,
        investmentsCount: counts['investments'] as int? ?? 0,
        recurringCount: counts['recurring'] as int? ?? 0,
        financialPlansCount: counts['financialPlans'] as int? ?? 0,
        exportedAt: decoded['exportedAt']?.toString() ?? '',
        version: decoded['schemaVersion'] as int? ?? 1,
        isLegacy: false,
        rawJson: jsonString,
        hasMarketData: state['marketData'] != null,
      );
    } catch (e) {
      throw FormatException('Failed to parse backup file: $e');
    }
  }

  /// Handles older JS ZakatApp Backup formats safely.
  static BackupPreview _parseLegacy(Map<String, dynamic> decoded, String rawJson) {
    final dynamic dataRaw = decoded['data'];
    Map<String, dynamic> data = <String, dynamic>{};

    // Legacy V1 stringified the internal `data` block.
    if (dataRaw is String) {
      try {
        data = jsonDecode(dataRaw) as Map<String, dynamic>;
      } catch (_) {}
    } else if (dataRaw is Map<String, dynamic>) {
      data = dataRaw;
    }

    return BackupPreview(
      transactionsCount: (data['transactions'] as List<dynamic>?)?.length ?? 0,
      savingsCount: (data['savings'] as List<dynamic>?)?.length ?? 0,
      investmentsCount: (data['investments'] as List<dynamic>?)?.length ?? 0,
      recurringCount: (data['recurringTransactions'] as List<dynamic>?)?.length ?? 0,
      financialPlansCount: (data['financialPlans'] as List<dynamic>?)?.length ?? 0,
      exportedAt: decoded['exportedAt']?.toString() ?? '',
      version: decoded['version'] as int? ?? 1,
      isLegacy: true,
      rawJson: rawJson,
      hasMarketData: data['marketData'] != null,
    );
  }

  /// Extracts the pure AppState map from either format to be restored.
  static Map<String, dynamic> extractAppState(String jsonString) {
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) return <String, dynamic>{};

    // Legacy extraction
    if (decoded['schema'] == 'zakatapp.backup' ||
        (decoded['version'] != null && decoded['data'] != null)) {
      final dynamic dataRaw = decoded['data'];
      if (dataRaw is String) {
        return jsonDecode(dataRaw) as Map<String, dynamic>;
      }
      return dataRaw as Map<String, dynamic>;
    }

    // Current extraction
    return decoded['appState'] as Map<String, dynamic>;
  }

  /// Used to detect if the local app already has existing data (to prevent silent overwrites)
  static bool hasData(Map<String, dynamic> state) {
    final int txCount = (state['transactions'] as List<dynamic>?)?.length ?? 0;
    final int savCount = (state['savings'] as List<dynamic>?)?.length ?? 0;
    final int invCount = (state['investments'] as List<dynamic>?)?.length ?? 0;
    final int plansCount = (state['financialPlans'] as List<dynamic>?)?.length ?? 0;
    return (txCount + savCount + invCount + plansCount) > 0;
  }
}