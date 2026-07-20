import '../../services/firestore_sync_manager.dart';
import '../local/daos/sync_metadata_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import '../repositories/local_financial_plans_repository.dart';
import '../repositories/local_merchant_confirmations_repository.dart';
import '../repositories/local_merchant_rules_repository.dart';
import '../repositories/local_correction_feedback_repository.dart';
import '../repositories/local_investments_repository.dart';
import '../repositories/local_pending_transactions_repository.dart';
import '../repositories/local_recurring_transactions_repository.dart';
import '../repositories/local_savings_repository.dart';
import '../repositories/local_transactions_repository.dart';
import 'pull_sync_manager.dart';
import 'sync_queue_processor.dart';
import 'sync_reports.dart';

class LocalSyncPipeline {
  LocalSyncPipeline({
    required FirestoreSyncManager firestoreSyncManager,
    required SyncQueueDao syncQueueDao,
    required SyncMetadataDao syncMetadataDao,
    required LocalTransactionsRepository transactionsRepository,
    required LocalSavingsRepository savingsRepository,
    required LocalFinancialPlansRepository financialPlansRepository,
    required LocalInvestmentsRepository investmentsRepository,
    required LocalMerchantRulesRepository merchantRulesRepository,
    required LocalMerchantConfirmationsRepository
    merchantConfirmationsRepository,
    required LocalCorrectionFeedbackRepository correctionFeedbackRepository,
    required LocalRecurringTransactionsRepository
    recurringTransactionsRepository,
    required LocalPendingTransactionsRepository pendingTransactionsRepository,
  }) : _syncQueueProcessor = SyncQueueProcessor(
         syncQueueDao: syncQueueDao,
         firestoreSyncManager: firestoreSyncManager,
       ),
       _pullSyncManager = PullSyncManager(
         firestoreSyncManager: firestoreSyncManager,
         syncMetadataDao: syncMetadataDao,
         transactionsRepository: transactionsRepository,
         savingsRepository: savingsRepository,
         financialPlansRepository: financialPlansRepository,
         investmentsRepository: investmentsRepository,
         merchantRulesRepository: merchantRulesRepository,
         merchantConfirmationsRepository: merchantConfirmationsRepository,
         correctionFeedbackRepository: correctionFeedbackRepository,
         recurringTransactionsRepository: recurringTransactionsRepository,
         pendingTransactionsRepository: pendingTransactionsRepository,
       ),
       _syncQueueDao = syncQueueDao,
       _syncMetadataDao = syncMetadataDao;

  final SyncQueueProcessor _syncQueueProcessor;
  final PullSyncManager _pullSyncManager;
  final SyncQueueDao _syncQueueDao;
  final SyncMetadataDao _syncMetadataDao;
  bool _syncInProgress = false;

  bool get syncInProgress => _syncInProgress;
  static const Duration minAutoPullInterval = Duration(hours: 6);

  Future<int> queueCount() => _syncQueueDao.countQueued();

  Future<String?> lastPushSuccessAt() =>
      _syncMetadataDao.getLastPushSuccessAt();

  Future<String?> lastPullSuccessAt() =>
      _syncMetadataDao.getLastPullSuccessAt();

  Future<bool> hasPullCursor() async {
    final String? lastPull = await lastPullSuccessAt();
    if ((lastPull ?? '').trim().isNotEmpty) return true;
    final List<String?> cursors = await Future.wait<String?>(<Future<String?>>[
      _syncMetadataDao.getCursor('transactions'),
      _syncMetadataDao.getDeletedCursor('transactions'),
      _syncMetadataDao.getCursor('savings'),
      _syncMetadataDao.getDeletedCursor('savings'),
      _syncMetadataDao.getCursor('investments'),
      _syncMetadataDao.getDeletedCursor('investments'),
      _syncMetadataDao.getCursor('pending_transactions'),
      _syncMetadataDao.getDeletedCursor('pending_transactions'),
      _syncMetadataDao.getCursor('recurring_transactions'),
      _syncMetadataDao.getDeletedCursor('recurring_transactions'),
      _syncMetadataDao.getCursor('financial_plans'),
      _syncMetadataDao.getDeletedCursor('financial_plans'),
      _syncMetadataDao.getCursor('correction_feedback'),
      _syncMetadataDao.getDeletedCursor('correction_feedback'),
      _syncMetadataDao.getCursor('merchant_confirmations'),
      _syncMetadataDao.getDeletedCursor('merchant_confirmations'),
      _syncMetadataDao.getCursor('merchant_rules'),
      _syncMetadataDao.getDeletedCursor('merchant_rules'),
    ]);
    return cursors.any((String? cursor) => (cursor ?? '').trim().isNotEmpty);
  }

  Future<bool> shouldPullNow() async {
    final String? lastPull = await lastPullSuccessAt();
    return _isStale(lastPull, minAutoPullInterval);
  }

  Future<SyncQueueProcessResult> pushOnly(String userId) async {
    if (_syncInProgress) {
      return const SyncQueueProcessResult(
        attempted: 0,
        succeeded: 0,
        failed: 0,
      );
    }
    _syncInProgress = true;
    try {
      return await _pushOnlyInternal(userId);
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> pullOnly(String userId) async {
    if (_syncInProgress) return;
    _syncInProgress = true;
    try {
      final PullSyncResult pullResult = await _pullOnlyInternal(userId);
      if (pullResult.success) {
        await markPullSuccess();
      }
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> pushThenPull(String userId) async {
    await pushThenPullDetailed(userId);
  }

  Future<LocalSyncRunResult?> pushThenPullDetailed(String userId) async {
    if (_syncInProgress) return null;
    _syncInProgress = true;
    try {
      final SyncQueueProcessResult pushResult = await _pushOnlyInternal(userId);
      final PullSyncResult pullResult = await _pullOnlyInternal(userId);
      if (pullResult.success) {
        await markPullSuccess();
      }
      return LocalSyncRunResult(pushResult: pushResult, pullResult: pullResult);
    } finally {
      _syncInProgress = false;
    }
  }

  Future<PullSyncResult> pullOnlyDetailed(String userId) {
    return _pullOnlyInternal(userId);
  }

  Future<void> _recordPushSuccess() async {
    final String now = DateTime.now().toUtc().toIso8601String();
    await _syncMetadataDao.setLastPushSuccessAt(now);
    await _syncMetadataDao.setValue(lastSyncSuccessAtKey, now);
  }

  Future<void> _recordPullSuccess() async {
    final String now = DateTime.now().toUtc().toIso8601String();
    await _syncMetadataDao.setLastPullSuccessAt(now);
    await _syncMetadataDao.setValue(lastSyncSuccessAtKey, now);
  }

  Future<void> markPullSuccess() => _recordPullSuccess();

  bool _isStale(String? timestamp, Duration maxAge) {
    final String raw = (timestamp ?? '').trim();
    if (raw.isEmpty) return true;
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return true;
    return DateTime.now().toUtc().difference(parsed.toUtc()) >= maxAge;
  }

  /// Trigger local-first synchronization: pushes local mutations, then pulls remote updates.
  Future<void> sync(String userId) async {
    await pushThenPull(userId);
  }

  Future<SyncQueueProcessResult> _pushOnlyInternal(String userId) async {
    final SyncQueueProcessResult result = await _syncQueueProcessor
        .processQueue(userId);
    if (result.hadAttempts && result.failed == 0 && result.hadSuccesses) {
      await _recordPushSuccess();
    }
    return result;
  }

  Future<PullSyncResult> _pullOnlyInternal(String userId) async {
    return _pullSyncManager.pullSyncDetailed(userId);
  }
}

class LocalSyncRunResult {
  const LocalSyncRunResult({
    required this.pushResult,
    required this.pullResult,
  });

  final SyncQueueProcessResult pushResult;
  final PullSyncResult pullResult;

  bool get success => pushResult.failed == 0 && pullResult.success;
}
