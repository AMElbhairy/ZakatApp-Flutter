import '../models/app_state.dart';
import 'app_state_controller.dart';
import 'backup_service.dart';
import 'legacy_backup_migration_service.dart';
import 'sync_diagnostics_service.dart';

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
    String? expectedUserId,
  }) async {
    _ensureConflictSafety(allowWhenLocalDataExists);

    final LegacyMigrationReport report = _migrationService
        .parseAndMigrateWithReport(rawJson);
    _ensureOwnership(report.state, expectedUserId);
    final String effectiveUserId = _resolveEffectiveUserId(expectedUserId);
    final AppStateModel previous = controller.state;
    final Map<String, dynamic> normalized = Map<String, dynamic>.from(
      report.state,
    );
    if (effectiveUserId.isNotEmpty) {
      normalized['userId'] = effectiveUserId;
    }
    final AppStateModel next = AppStateModel.fromJson(normalized);
    await controller.updateState(next);
    await controller.enqueueAllLocalDataForCloudSync();
    await controller.syncRestoredStateToFirestore(
      previousState: previous,
      nextState: next,
    );
    final Map<String, int> counts = _stateCounts(next.toJson());
    await SyncDiagnosticsService.record(
      level: 'info',
      subsystem: 'restore',
      message: 'Import completed',
      metadata: <String, dynamic>{
        'mode': 'replace',
        'counts': counts,
      },
    );
    await SyncDiagnosticsService.record(
      level: 'info',
      subsystem: 'restore',
      message: 'Sync auto-triggered after import',
      metadata: <String, dynamic>{
        'reason': 'import_restore',
        'counts': counts,
      },
    );
    await controller.triggerSyncPipeline(reason: 'import_restore');

    return RestoreResult(
      mode: 'replace',
      counts: _stateCounts(next.toJson()),
      warnings: report.warnings,
    );
  }

  Future<RestoreResult> restoreMerge(
    String rawJson, {
    bool allowWhenLocalDataExists = false,
    String? expectedUserId,
  }) async {
    _ensureConflictSafety(allowWhenLocalDataExists);

    final LegacyMigrationReport report = _migrationService
        .parseAndMigrateWithReport(rawJson);
    _ensureOwnership(report.state, expectedUserId);
    final String effectiveUserId = _resolveEffectiveUserId(expectedUserId);
    final AppStateModel previous = controller.state;
    final Map<String, dynamic> current = controller.state.toJson();
    final Map<String, dynamic> incoming = report.state;

    final Map<String, dynamic> merged = <String, dynamic>{...current};
    if (effectiveUserId.isNotEmpty) {
      merged['userId'] = effectiveUserId;
    }
    merged['transactions'] = _mergeById(
      current['transactions'],
      incoming['transactions'],
    );
    merged['savings'] = _mergeById(current['savings'], incoming['savings']);
    merged['pendingTransactions'] = _mergeById(
      current['pendingTransactions'],
      incoming['pendingTransactions'],
    );
    merged['investments'] = _mergeById(
      current['investments'],
      incoming['investments'],
    );
    merged['recurringTransactions'] = _mergeById(
      current['recurringTransactions'],
      incoming['recurringTransactions'],
    );
    merged['financialPlans'] = _mergeById(
      current['financialPlans'],
      incoming['financialPlans'],
    );
    merged['correctionFeedback'] = _mergeById(
      current['correctionFeedback'],
      incoming['correctionFeedback'],
    );
    merged['merchantConfirmations'] = _mergeById(
      current['merchantConfirmations'],
      incoming['merchantConfirmations'],
    );

    final Map<String, dynamic> categories = _mergeCategories(
      current['categories'],
      incoming['categories'],
    );
    merged['categories'] = categories;
    merged['zakatPaidMonths'] = _mergeStringLists(
      current['zakatPaidMonths'],
      incoming['zakatPaidMonths'],
    );
    merged['processedExpenseIds'] = _mergeStringLists(
      current['processedExpenseIds'],
      incoming['processedExpenseIds'],
    );
    merged['zakatExpenseIds'] = _mergeStringMap(
      current['zakatExpenseIds'],
      incoming['zakatExpenseIds'],
    );
    merged['merchantRules'] = _mergeStringMap(
      current['merchantRules'],
      incoming['merchantRules'],
    );
    merged['merchantAliases'] = _mergeStringMap(
      current['merchantAliases'],
      incoming['merchantAliases'],
    );

    merged['mainCurrency'] =
        (incoming['mainCurrency'] ?? current['mainCurrency']).toString();
    merged['defaultEntryCurrency'] =
        (incoming['defaultEntryCurrency'] ?? current['defaultEntryCurrency'])
            .toString();
    merged['zakatMethod'] = (incoming['zakatMethod'] ?? current['zakatMethod'])
        .toString();
    merged['zakatAnnualDate'] =
        (incoming['zakatAnnualDate'] ?? current['zakatAnnualDate']).toString();
    merged['zakatNisabBasis'] =
        (incoming['zakatNisabBasis'] ?? current['zakatNisabBasis'] ?? 'gold85')
            .toString();
    merged['languagePreference'] =
        (incoming['languagePreference'] ?? current['languagePreference'])
            .toString();
    merged['themeMode'] =
        (incoming['themeMode'] ?? current['themeMode'] ?? 'system').toString();
    final Map<String, dynamic>? incomingMarketData =
        incoming['marketData'] is Map
        ? Map<String, dynamic>.from(incoming['marketData'] as Map)
        : null;
    final bool hasIncomingMarketData =
        incomingMarketData != null &&
        incomingMarketData.values.any(
          (dynamic value) =>
              value != null && value.toString().trim().isNotEmpty,
        );
    merged['marketData'] = hasIncomingMarketData
        ? incomingMarketData
        : current['marketData'];
    merged['aiSettings'] = incoming['aiSettings'] is Map
        ? Map<String, dynamic>.from(incoming['aiSettings'] as Map)
        : current['aiSettings'];

    _resetRemainingAmountsIfNeeded(merged, report.warnings);
    report.warnings.add(
      'Merge completed by ID upsert. Reconciliation may be required because a full reconciliation engine is not implemented.',
    );

    final AppStateModel next = AppStateModel.fromJson(merged);
    await controller.updateState(next);
    await controller.enqueueAllLocalDataForCloudSync();
    await controller.syncRestoredStateToFirestore(
      previousState: previous,
      nextState: next,
    );
    final Map<String, int> counts = _stateCounts(next.toJson());
    await SyncDiagnosticsService.record(
      level: 'info',
      subsystem: 'restore',
      message: 'Import completed',
      metadata: <String, dynamic>{
        'mode': 'merge',
        'counts': counts,
      },
    );
    await SyncDiagnosticsService.record(
      level: 'info',
      subsystem: 'restore',
      message: 'Sync auto-triggered after import',
      metadata: <String, dynamic>{
        'reason': 'import_restore',
        'counts': counts,
      },
    );
    await controller.triggerSyncPipeline(reason: 'import_restore');

    return RestoreResult(
      mode: 'merge',
      counts: _stateCounts(next.toJson()),
      warnings: report.warnings,
    );
  }

  void _ensureConflictSafety(bool allowWhenLocalDataExists) {
    if (!allowWhenLocalDataExists &&
        BackupService.hasData(controller.state.toJson())) {
      throw StateError(
        'Local data exists. Explicit restore action is required.',
      );
    }
  }

  void _ensureOwnership(Map<String, dynamic> state, [String? expectedUserId]) {
    final String backupUserId = (state['userId'] ?? '').toString().trim();
    final String currentUserId = _resolveEffectiveUserId(expectedUserId);
    if (backupUserId.isNotEmpty &&
        currentUserId.isNotEmpty &&
        backupUserId != currentUserId) {
      throw StateError('This backup belongs to another account.');
    }
  }

  String _resolveEffectiveUserId([String? expectedUserId]) {
    final String currentUserId = (controller.state.userId ?? '').trim();
    final String expected = (expectedUserId ?? '').trim();
    if (expected.isNotEmpty) return expected;
    if (currentUserId.isNotEmpty) return currentUserId;
    return '';
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
        .where(
          (Map<String, dynamic> e) =>
              (e['id'] ?? '').toString().trim().isNotEmpty,
        )
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

  void _resetRemainingAmountsIfNeeded(
    Map<String, dynamic> state,
    List<String> warnings,
  ) {
    final List<Map<String, dynamic>> savings = _asMapList(state['savings']);
    for (final Map<String, dynamic> saving in savings) {
      if (saving['remainingAmount'] == null) {
        saving['remainingAmount'] = saving['amount'] ?? 0;
      }
    }
    final List<Map<String, dynamic>> investments = _asMapList(
      state['investments'],
    );
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

  List<String> _mergeStringLists(dynamic left, dynamic right) {
    final Set<String> merged = <String>{
      ..._asStringList(left),
      ..._asStringList(right),
    };
    return merged.toList(growable: false);
  }

  Map<String, dynamic> _mergeStringMap(dynamic left, dynamic right) {
    final Map<String, dynamic> merged = left is Map
        ? Map<String, dynamic>.from(left)
        : <String, dynamic>{};
    if (right is Map) {
      merged.addAll(Map<String, dynamic>.from(right));
    }
    return merged;
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
