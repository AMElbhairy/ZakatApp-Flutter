import '../models/app_state.dart';
import 'app_state_controller.dart';
import 'backup_service.dart';
import 'legacy_backup_migration_service.dart';

class RestoreResult {
  const RestoreResult({
    required this.mode,
    required this.counts,
    required this.warnings,
  });

  final String mode;
  final Map<String, int> counts;
  final List<String> warnings;
}

class BackupRestoreService {
  BackupRestoreService({
    required this.controller,
    LegacyBackupMigrationService? migrationService,
  }) : _migrationService = migrationService ?? LegacyBackupMigrationService();

  final AppStateController controller;
  final LegacyBackupMigrationService _migrationService;

  Future<RestoreResult> restoreReplace(
    String rawJson, {
    bool allowWhenLocalDataExists = false,
  }) async {
    _ensureConflictSafety(allowWhenLocalDataExists);

    final LegacyMigrationReport report =
        _migrationService.parseAndMigrateWithReport(rawJson);
    final AppStateModel next = AppStateModel.fromJson(report.state);
    await controller.updateState(next);

    return RestoreResult(
      mode: 'replace',
      counts: _stateCounts(next.toJson()),
      warnings: report.warnings,
    );
  }

  Future<RestoreResult> restoreMerge(
    String rawJson, {
    bool allowWhenLocalDataExists = false,
  }) async {
    _ensureConflictSafety(allowWhenLocalDataExists);

    final LegacyMigrationReport report =
        _migrationService.parseAndMigrateWithReport(rawJson);
    final Map<String, dynamic> current = controller.state.toJson();
    final Map<String, dynamic> incoming = report.state;

    final Map<String, dynamic> merged = <String, dynamic>{...current};
    merged['transactions'] = _mergeById(current['transactions'], incoming['transactions']);
    merged['savings'] = _mergeById(current['savings'], incoming['savings']);
    merged['investments'] = _mergeById(current['investments'], incoming['investments']);
    merged['recurringTransactions'] =
        _mergeById(current['recurringTransactions'], incoming['recurringTransactions']);
    merged['financialPlans'] = _mergeById(current['financialPlans'], incoming['financialPlans']);

    final Map<String, dynamic> categories = _mergeCategories(
      current['categories'],
      incoming['categories'],
    );
    merged['categories'] = categories;

    merged['mainCurrency'] = (incoming['mainCurrency'] ?? current['mainCurrency']).toString();
    merged['defaultEntryCurrency'] =
        (incoming['defaultEntryCurrency'] ?? current['defaultEntryCurrency']).toString();
    merged['zakatMethod'] = (incoming['zakatMethod'] ?? current['zakatMethod']).toString();
    merged['zakatAnnualDate'] =
        (incoming['zakatAnnualDate'] ?? current['zakatAnnualDate']).toString();
    merged['languagePreference'] =
        (incoming['languagePreference'] ?? current['languagePreference']).toString();
    merged['marketData'] = incoming['marketData'] is Map
        ? Map<String, dynamic>.from(incoming['marketData'] as Map)
        : current['marketData'];

    _resetRemainingAmountsIfNeeded(merged, report.warnings);
    report.warnings.add(
      'Merge completed by ID upsert. Reconciliation may be required because a full reconciliation engine is not implemented.',
    );

    final AppStateModel next = AppStateModel.fromJson(merged);
    await controller.updateState(next);

    return RestoreResult(
      mode: 'merge',
      counts: _stateCounts(next.toJson()),
      warnings: report.warnings,
    );
  }

  void _ensureConflictSafety(bool allowWhenLocalDataExists) {
    if (!allowWhenLocalDataExists && BackupService.hasData(controller.state.toJson())) {
      throw StateError('Local data exists. Explicit restore action is required.');
    }
  }

  List<Map<String, dynamic>> _mergeById(dynamic left, dynamic right) {
    final List<Map<String, dynamic>> lhs = _asMapList(left);
    final List<Map<String, dynamic>> rhs = _asMapList(right);
    final Map<String, Map<String, dynamic>> merged =
        <String, Map<String, dynamic>>{};

    for (final Map<String, dynamic> item in lhs) {
      merged[(item['id'] ?? '').toString()] = item;
    }
    for (final Map<String, dynamic> item in rhs) {
      merged[(item['id'] ?? '').toString()] = item;
    }

    return merged.values
        .where((Map<String, dynamic> e) => (e['id'] ?? '').toString().trim().isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> _mergeCategories(dynamic current, dynamic incoming) {
    final Map<String, dynamic> left = current is Map
        ? Map<String, dynamic>.from(current)
        : <String, dynamic>{};
    final Map<String, dynamic> right = incoming is Map
        ? Map<String, dynamic>.from(incoming)
        : <String, dynamic>{};

    final Set<String> income = <String>{
      ..._asStringList(left['income']),
      ..._asStringList(right['income']),
    };
    final Set<String> expense = <String>{
      ..._asStringList(left['expense']),
      ..._asStringList(right['expense']),
    };
    return <String, dynamic>{
      'income': income.toList(growable: false),
      'expense': expense.toList(growable: false),
    };
  }

  void _resetRemainingAmountsIfNeeded(Map<String, dynamic> state, List<String> warnings) {
    final List<Map<String, dynamic>> savings = _asMapList(state['savings']);
    for (final Map<String, dynamic> saving in savings) {
      if (saving['remainingAmount'] == null) {
        saving['remainingAmount'] = saving['amount'] ?? 0;
      }
    }
    final List<Map<String, dynamic>> investments = _asMapList(state['investments']);
    for (final Map<String, dynamic> investment in investments) {
      if (investment['remainingAmount'] == null) {
        final num totalPayable = _asNum(investment['totalPayable']);
        final num paidAmount = _asNum(investment['paidAmount']);
        investment['remainingAmount'] = totalPayable - paidAmount;
      }
      if (investment['loanBalance'] == null) {
        investment['loanBalance'] = investment['remainingAmount'] ?? 0;
      }
    }
    state['savings'] = savings;
    state['investments'] = investments;
    warnings.add('Normalized missing remaining balances where needed.');
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((Map e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  List<String> _asStringList(dynamic value) {
    if (value is! List) return <String>[];
    return value.map((dynamic e) => e.toString()).toList(growable: false);
  }

  Map<String, int> _stateCounts(Map<String, dynamic> state) {
    int count(dynamic value) => value is List ? value.length : 0;
    return <String, int>{
      'transactions': count(state['transactions']),
      'savings': count(state['savings']),
      'investments': count(state['investments']),
      'recurringTransactions': count(state['recurringTransactions']),
      'financialPlans': count(state['financialPlans']),
    };
  }

  num _asNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse((value ?? '').toString()) ?? 0;
  }
}
