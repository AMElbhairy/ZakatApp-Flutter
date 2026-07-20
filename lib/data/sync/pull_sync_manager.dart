import 'package:flutter/foundation.dart';
import '../../models/investment_asset.dart';
import '../../models/financial_plan.dart';
import '../../models/transaction.dart';
import '../../models/saving.dart';
import '../../models/recurring_transaction.dart';
import '../../models/pending_transaction.dart';
import '../../models/merchant_rule.dart';
import '../../models/merchant_confirmation.dart';
import '../../models/correction_feedback.dart';
import '../local/daos/sync_metadata_dao.dart';
import '../repositories/local_correction_feedback_repository.dart';
import '../repositories/local_investments_repository.dart';
import '../repositories/local_financial_plans_repository.dart';
import '../repositories/local_merchant_confirmations_repository.dart';
import '../repositories/local_merchant_rules_repository.dart';
import '../repositories/local_pending_transactions_repository.dart';
import '../repositories/local_recurring_transactions_repository.dart';
import '../repositories/local_savings_repository.dart';
import '../repositories/local_transactions_repository.dart';
import '../../services/firestore_sync_manager.dart';
import '../../services/sync_diagnostics_service.dart';
import 'sync_reports.dart';

class PullSyncManager {
  PullSyncManager({
    required this._firestoreSyncManager,
    required this._syncMetadataDao,
    required this._transactionsRepository,
    required this._savingsRepository,
    required this._investmentsRepository,
    required this._financialPlansRepository,
    required this._recurringTransactionsRepository,
    required this._pendingTransactionsRepository,
    required this._merchantRulesRepository,
    required this._merchantConfirmationsRepository,
    required this._correctionFeedbackRepository,
  });

  final FirestoreSyncManager _firestoreSyncManager;
  final SyncMetadataDao _syncMetadataDao;
  final LocalTransactionsRepository _transactionsRepository;
  final LocalSavingsRepository _savingsRepository;
  final LocalInvestmentsRepository _investmentsRepository;
  final LocalFinancialPlansRepository _financialPlansRepository;
  final LocalRecurringTransactionsRepository _recurringTransactionsRepository;
  final LocalPendingTransactionsRepository _pendingTransactionsRepository;
  final LocalMerchantRulesRepository _merchantRulesRepository;
  final LocalMerchantConfirmationsRepository _merchantConfirmationsRepository;
  final LocalCorrectionFeedbackRepository _correctionFeedbackRepository;

  static const String _pendingTransactionsCollection = 'pending_transactions';

  /// Pull remote updates and deletions from Firestore and advance cursors only
  /// after all remote reads complete successfully.
  Future<PullSyncResult> pullSyncDetailed(String uid) async {
    if (kDebugMode) {
      print('[PULL] pullSync start user=$uid');
    }
    try {
      final String transactionsCursor =
          await _syncMetadataDao.getCursor('transactions') ?? '';
      final String transactionsDeletedCursor =
          await _syncMetadataDao.getDeletedCursor('transactions') ?? '';
      final txDelta = await _firestoreSyncManager.loadTransactionsSince(
        uid: uid,
        sinceCursor: transactionsCursor,
      );
      final txDeletedDelta = await _firestoreSyncManager
          .loadDeletedTransactionIdsSince(
            uid: uid,
            sinceCursor: transactionsDeletedCursor,
          );

      final String savingsCursor =
          await _syncMetadataDao.getCursor('savings') ?? '';
      final String savingsDeletedCursor =
          await _syncMetadataDao.getDeletedCursor('savings') ?? '';
      final savDelta = await _firestoreSyncManager.loadSavingsSince(
        uid: uid,
        sinceCursor: savingsCursor,
      );
      final savDeletedDelta = await _firestoreSyncManager
          .loadDeletedSavingsSince(uid: uid, sinceCursor: savingsDeletedCursor);

      final String investmentsCursor =
          await _syncMetadataDao.getCursor('investments') ?? '';
      final String investmentsDeletedCursor =
          await _syncMetadataDao.getDeletedCursor('investments') ?? '';
      final invDelta = await _firestoreSyncManager.loadInvestmentsSince(
        uid: uid,
        sinceCursor: investmentsCursor,
      );
      final invDeletedDelta = await _firestoreSyncManager
          .loadDeletedInvestmentsSince(
            uid: uid,
            sinceCursor: investmentsDeletedCursor,
          );

      final String plansCursor =
          await _syncMetadataDao.getCursor('financial_plans') ?? '';
      final String plansDeletedCursor =
          await _syncMetadataDao.getDeletedCursor('financial_plans') ?? '';
      final planDelta = await _firestoreSyncManager.loadFinancialPlansSince(
        uid: uid,
        sinceCursor: plansCursor,
      );
      final planDeletedDelta = await _firestoreSyncManager
          .loadDeletedFinancialPlansSince(
            uid: uid,
            sinceCursor: plansDeletedCursor,
          );

      final String recurringCursor =
          await _syncMetadataDao.getCursor('recurring_transactions') ?? '';
      final String recurringDeletedCursor =
          await _syncMetadataDao.getDeletedCursor('recurring_transactions') ??
          '';
      final recurringDelta = await _firestoreSyncManager
          .loadRecurringTransactionsSince(
            uid: uid,
            sinceCursor: recurringCursor,
          );
      final recurringDeletedDelta = await _firestoreSyncManager
          .loadDeletedRecurringTransactionsSince(
            uid: uid,
            sinceCursor: recurringDeletedCursor,
          );

      final String pendingCursor =
          await _syncMetadataDao.getCursor('pending_transactions') ?? '';
      final String pendingDeletedCursor =
          await _syncMetadataDao.getDeletedCursor('pending_transactions') ?? '';
      final pendingDelta = await _firestoreSyncManager.loadCaptureInboxSince(
        uid: uid,
        sinceCursor: pendingCursor,
      );
      final pendingDeletedDelta = await _firestoreSyncManager
          .loadDeletedCaptureInboxSince(
            uid: uid,
            sinceCursor: pendingDeletedCursor,
          );

      final String rulesCursor =
          await _syncMetadataDao.getCursor('merchant_rules') ?? '';
      final String rulesDeletedCursor =
          await _syncMetadataDao.getDeletedCursor('merchant_rules') ?? '';
      final rulesDelta = await _firestoreSyncManager.loadMerchantRulesSince(
        uid: uid,
        sinceCursor: rulesCursor,
      );
      final rulesDeletedDelta = await _firestoreSyncManager
          .loadDeletedMerchantRulesSince(
            uid: uid,
            sinceCursor: rulesDeletedCursor,
          );

      final String confirmationsCursor =
          await _syncMetadataDao.getCursor('merchant_confirmations') ?? '';
      final String confirmationsDeletedCursor =
          await _syncMetadataDao.getDeletedCursor('merchant_confirmations') ??
          '';
      final confirmationsDelta = await _firestoreSyncManager
          .loadMerchantConfirmationsSince(
            uid: uid,
            sinceCursor: confirmationsCursor,
          );
      final confirmationsDeletedDelta = await _firestoreSyncManager
          .loadDeletedMerchantConfirmationsSince(
            uid: uid,
            sinceCursor: confirmationsDeletedCursor,
          );

      final String feedbackCursor =
          await _syncMetadataDao.getCursor('correction_feedback') ?? '';
      final String feedbackDeletedCursor =
          await _syncMetadataDao.getDeletedCursor('correction_feedback') ?? '';
      final feedbackDelta = await _firestoreSyncManager
          .loadCorrectionFeedbackSince(uid: uid, sinceCursor: feedbackCursor);
      final feedbackDeletedDelta = await _firestoreSyncManager
          .loadDeletedCorrectionFeedbackSince(
            uid: uid,
            sinceCursor: feedbackDeletedCursor,
          );

      final List<PullCollectionResult> results = <PullCollectionResult>[
        await _applyTransactions(
          uid: uid,
          delta: txDelta,
          deletedDelta: txDeletedDelta,
          currentCursor: transactionsCursor,
          currentDeletedCursor: transactionsDeletedCursor,
        ),
        await _applySavings(
          uid: uid,
          delta: savDelta,
          deletedDelta: savDeletedDelta,
          currentCursor: savingsCursor,
          currentDeletedCursor: savingsDeletedCursor,
        ),
        await _applyInvestments(
          uid: uid,
          delta: invDelta,
          deletedDelta: invDeletedDelta,
          currentCursor: investmentsCursor,
          currentDeletedCursor: investmentsDeletedCursor,
        ),
        await _applyFinancialPlans(
          uid: uid,
          delta: planDelta,
          deletedDelta: planDeletedDelta,
          currentCursor: plansCursor,
          currentDeletedCursor: plansDeletedCursor,
        ),
        await _applyRecurringTransactions(
          uid: uid,
          delta: recurringDelta,
          deletedDelta: recurringDeletedDelta,
          currentCursor: recurringCursor,
          currentDeletedCursor: recurringDeletedCursor,
        ),
        await _applyPendingTransactions(
          uid: uid,
          delta: pendingDelta,
          deletedDelta: pendingDeletedDelta,
          currentCursor: pendingCursor,
          currentDeletedCursor: pendingDeletedCursor,
        ),
        await _applyMerchantRules(
          uid: uid,
          delta: rulesDelta,
          deletedDelta: rulesDeletedDelta,
          currentCursor: rulesCursor,
          currentDeletedCursor: rulesDeletedCursor,
        ),
        await _applyMerchantConfirmations(
          uid: uid,
          delta: confirmationsDelta,
          deletedDelta: confirmationsDeletedDelta,
          currentCursor: confirmationsCursor,
          currentDeletedCursor: confirmationsDeletedCursor,
        ),
        await _applyCorrectionFeedback(
          uid: uid,
          delta: feedbackDelta,
          deletedDelta: feedbackDeletedDelta,
          currentCursor: feedbackCursor,
          currentDeletedCursor: feedbackDeletedCursor,
        ),
      ];

      return PullSyncResult(
        uid: uid,
        firestoreUserPath: 'users/$uid',
        collections: results,
        success: true,
      );
    } catch (error) {
      if (kDebugMode) {
        print('[PULL] pullSync failed user=$uid error=$error');
      }
      return PullSyncResult(
        uid: uid,
        firestoreUserPath: 'users/$uid',
        collections: const <PullCollectionResult>[],
        success: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> pullSync(String uid) async {
    await pullSyncDetailed(uid);
  }

  Future<PullCollectionResult> _applyTransactions({
    required String uid,
    required FirestoreCollectionDelta<Transaction> delta,
    required FirestoreDeletedIdsDelta deletedDelta,
    required String currentCursor,
    required String currentDeletedCursor,
  }) async {
    if (kDebugMode) {
      print('[PULL] transactions cursorBefore=$currentCursor');
    }
    for (final tx in delta.items) {
      await _transactionsRepository.applyRemoteUpsertTransaction(
        tx,
        updatedAt: delta.cursor,
      );
    }
    await _syncMetadataDao.setCursor(
      'transactions',
      _resolvedCursor(delta.cursor),
    );
    for (final id in deletedDelta.ids) {
      await _transactionsRepository.applyRemoteDeleteTransaction(
        id,
        deletedAt: deletedDelta.cursor,
      );
    }
    await _syncMetadataDao.setDeletedCursor(
      'transactions',
      _resolvedCursor(deletedDelta.cursor),
    );
    if (kDebugMode) {
      final String finalCursor = delta.cursor.isNotEmpty
          ? delta.cursor
          : currentCursor;
      print(
        '[PULL] transactions upserts=${delta.items.length} deletes=${deletedDelta.ids.length} cursorAfter=$finalCursor',
      );
    }
    return PullCollectionResult(
      collection: 'transactions',
      path: _firestoreSyncManager.collectionPathForUid(uid, 'transactions'),
      upsertsApplied: delta.items.length,
      deletesApplied: deletedDelta.ids.length,
      cursorUpdates: 2,
    );
  }

  Future<PullCollectionResult> _applySavings({
    required String uid,
    required FirestoreCollectionDelta<Saving> delta,
    required FirestoreDeletedIdsDelta deletedDelta,
    required String currentCursor,
    required String currentDeletedCursor,
  }) async {
    if (kDebugMode) {
      print(
        '[PULL] savings path=${_firestoreSyncManager.savingsCollectionPath(uid)} cursorBefore=$currentCursor',
      );
    }
    for (final saving in delta.items) {
      await _savingsRepository.applyRemoteUpsertSaving(
        saving,
        updatedAt: delta.cursor,
      );
    }
    await _syncMetadataDao.setCursor('savings', _resolvedCursor(delta.cursor));
    for (final id in deletedDelta.ids) {
      await _savingsRepository.applyRemoteDeleteSaving(
        id,
        deletedAt: deletedDelta.cursor,
      );
    }
    await _syncMetadataDao.setDeletedCursor(
      'savings',
      _resolvedCursor(deletedDelta.cursor),
    );
    if (kDebugMode) {
      final String finalCursor = delta.cursor.isNotEmpty
          ? delta.cursor
          : currentCursor;
      print(
        '[PULL] savings upserts=${delta.items.length} deletes=${deletedDelta.ids.length} cursorAfter=$finalCursor',
      );
    }
    await SyncDiagnosticsService.recordFirebasePullResult(
      collection: 'savings',
      path: _firestoreSyncManager.savingsCollectionPath(uid),
      upserts: delta.items.length,
      deletes: deletedDelta.ids.length,
      cursor: delta.cursor.isNotEmpty ? delta.cursor : currentCursor,
    );
    return PullCollectionResult(
      collection: 'savings',
      path: _firestoreSyncManager.savingsCollectionPath(uid),
      upsertsApplied: delta.items.length,
      deletesApplied: deletedDelta.ids.length,
      cursorUpdates: 2,
    );
  }

  Future<PullCollectionResult> _applyInvestments({
    required String uid,
    required FirestoreCollectionDelta<InvestmentAsset> delta,
    required FirestoreDeletedIdsDelta deletedDelta,
    required String currentCursor,
    required String currentDeletedCursor,
  }) async {
    if (kDebugMode) {
      print('[PULL] investments cursorBefore=$currentCursor');
    }
    for (final investment in delta.items) {
      await _investmentsRepository.applyRemoteUpsertInvestment(
        investment,
        updatedAt: delta.cursor,
      );
    }
    await _syncMetadataDao.setCursor(
      'investments',
      _resolvedCursor(delta.cursor),
    );
    for (final id in deletedDelta.ids) {
      await _investmentsRepository.applyRemoteDeleteInvestment(
        id,
        deletedAt: deletedDelta.cursor,
      );
    }
    await _syncMetadataDao.setDeletedCursor(
      'investments',
      _resolvedCursor(deletedDelta.cursor),
    );
    if (kDebugMode) {
      final String finalCursor = delta.cursor.isNotEmpty
          ? delta.cursor
          : currentCursor;
      print(
        '[PULL] investments upserts=${delta.items.length} deletes=${deletedDelta.ids.length} cursorAfter=$finalCursor',
      );
    }
    return PullCollectionResult(
      collection: 'investments',
      path: _firestoreSyncManager.collectionPathForUid(uid, 'investments'),
      upsertsApplied: delta.items.length,
      deletesApplied: deletedDelta.ids.length,
      cursorUpdates: 2,
    );
  }

  Future<PullCollectionResult> _applyFinancialPlans({
    required String uid,
    required FirestoreCollectionDelta<FinancialPlan> delta,
    required FirestoreDeletedIdsDelta deletedDelta,
    required String currentCursor,
    required String currentDeletedCursor,
  }) async {
    if (kDebugMode) {
      print('[PULL] financial_plans cursorBefore=$currentCursor');
    }
    for (final plan in delta.items) {
      await _financialPlansRepository.applyRemoteUpsertFinancialPlan(
        plan,
        updatedAt: delta.cursor,
      );
    }
    await _syncMetadataDao.setCursor(
      'financial_plans',
      _resolvedCursor(delta.cursor),
    );
    for (final id in deletedDelta.ids) {
      await _financialPlansRepository.applyRemoteDeleteFinancialPlan(
        id,
        deletedAt: deletedDelta.cursor,
      );
    }
    await _syncMetadataDao.setDeletedCursor(
      'financial_plans',
      _resolvedCursor(deletedDelta.cursor),
    );
    if (kDebugMode) {
      final String finalCursor = delta.cursor.isNotEmpty
          ? delta.cursor
          : currentCursor;
      print(
        '[PULL] financial_plans upserts=${delta.items.length} deletes=${deletedDelta.ids.length} cursorAfter=$finalCursor',
      );
    }
    return PullCollectionResult(
      collection: 'financial_plans',
      path: _firestoreSyncManager.collectionPathForUid(uid, 'financial_plans'),
      upsertsApplied: delta.items.length,
      deletesApplied: deletedDelta.ids.length,
      cursorUpdates: 2,
    );
  }

  Future<PullCollectionResult> _applyRecurringTransactions({
    required String uid,
    required FirestoreCollectionDelta<RecurringTransaction> delta,
    required FirestoreDeletedIdsDelta deletedDelta,
    required String currentCursor,
    required String currentDeletedCursor,
  }) async {
    if (kDebugMode) {
      print('[PULL] recurring_transactions cursorBefore=$currentCursor');
    }
    for (final recurring in delta.items) {
      await _recurringTransactionsRepository
          .applyRemoteUpsertRecurringTransaction(
            recurring,
            updatedAt: delta.cursor,
          );
    }
    await _syncMetadataDao.setCursor(
      'recurring_transactions',
      _resolvedCursor(delta.cursor),
    );
    for (final id in deletedDelta.ids) {
      await _recurringTransactionsRepository
          .applyRemoteDeleteRecurringTransaction(
            id,
            deletedAt: deletedDelta.cursor,
          );
    }
    await _syncMetadataDao.setDeletedCursor(
      'recurring_transactions',
      _resolvedCursor(deletedDelta.cursor),
    );
    if (kDebugMode) {
      final String finalCursor = delta.cursor.isNotEmpty
          ? delta.cursor
          : currentCursor;
      print(
        '[PULL] recurring_transactions upserts=${delta.items.length} deletes=${deletedDelta.ids.length} cursorAfter=$finalCursor',
      );
    }
    return PullCollectionResult(
      collection: 'recurring_transactions',
      path: _firestoreSyncManager.collectionPathForUid(
        uid,
        'recurring_transactions',
      ),
      upsertsApplied: delta.items.length,
      deletesApplied: deletedDelta.ids.length,
      cursorUpdates: 2,
    );
  }

  Future<PullCollectionResult> _applyPendingTransactions({
    required String uid,
    required FirestoreCollectionDelta<PendingTransaction> delta,
    required FirestoreDeletedIdsDelta deletedDelta,
    required String currentCursor,
    required String currentDeletedCursor,
  }) async {
    if (kDebugMode) {
      print('[PULL] pending_transactions cursorBefore=$currentCursor');
    }
    for (final pending in delta.items) {
      await _pendingTransactionsRepository.applyRemoteUpsertPendingTransaction(
        pending,
        updatedAt: delta.cursor,
      );
    }
    await _syncMetadataDao.setCursor(
      'pending_transactions',
      _resolvedCursor(delta.cursor),
    );
    for (final id in deletedDelta.ids) {
      await _pendingTransactionsRepository.applyRemoteDeletePendingTransaction(
        id,
        deletedAt: deletedDelta.cursor,
      );
    }
    await _syncMetadataDao.setDeletedCursor(
      'pending_transactions',
      _resolvedCursor(deletedDelta.cursor),
    );
    if (kDebugMode) {
      final String finalCursor = delta.cursor.isNotEmpty
          ? delta.cursor
          : currentCursor;
      print(
        '[PULL] pending_transactions upserts=${delta.items.length} deletes=${deletedDelta.ids.length} cursorAfter=$finalCursor',
      );
    }
    return PullCollectionResult(
      collection: _pendingTransactionsCollection,
      path: _firestoreSyncManager.collectionPathForUid(
        uid,
        _pendingTransactionsCollection,
      ),
      upsertsApplied: delta.items.length,
      deletesApplied: deletedDelta.ids.length,
      cursorUpdates: 2,
    );
  }

  Future<PullCollectionResult> _applyMerchantRules({
    required String uid,
    required FirestoreCollectionDelta<MerchantRule> delta,
    required FirestoreDeletedIdsDelta deletedDelta,
    required String currentCursor,
    required String currentDeletedCursor,
  }) async {
    if (kDebugMode) {
      print('[PULL] merchant_rules cursorBefore=$currentCursor');
    }
    for (final rule in delta.items) {
      await _merchantRulesRepository.applyRemoteUpsertMerchantRule(
        rule,
        updatedAt: delta.cursor,
      );
    }
    await _syncMetadataDao.setCursor(
      'merchant_rules',
      _resolvedCursor(delta.cursor),
    );
    for (final id in deletedDelta.ids) {
      await _merchantRulesRepository.applyRemoteDeleteMerchantRule(
        id,
        deletedAt: deletedDelta.cursor,
      );
    }
    await _syncMetadataDao.setDeletedCursor(
      'merchant_rules',
      _resolvedCursor(deletedDelta.cursor),
    );
    if (kDebugMode) {
      final String finalCursor = delta.cursor.isNotEmpty
          ? delta.cursor
          : currentCursor;
      print(
        '[PULL] merchant_rules upserts=${delta.items.length} deletes=${deletedDelta.ids.length} cursorAfter=$finalCursor',
      );
    }
    return PullCollectionResult(
      collection: 'merchant_rules',
      path: _firestoreSyncManager.collectionPathForUid(uid, 'merchant_rules'),
      upsertsApplied: delta.items.length,
      deletesApplied: deletedDelta.ids.length,
      cursorUpdates: 2,
    );
  }

  Future<PullCollectionResult> _applyMerchantConfirmations({
    required String uid,
    required FirestoreCollectionDelta<MerchantConfirmation> delta,
    required FirestoreDeletedIdsDelta deletedDelta,
    required String currentCursor,
    required String currentDeletedCursor,
  }) async {
    if (kDebugMode) {
      print('[PULL] merchant_confirmations cursorBefore=$currentCursor');
    }
    for (final item in delta.items) {
      await _merchantConfirmationsRepository
          .applyRemoteUpsertMerchantConfirmation(item, updatedAt: delta.cursor);
    }
    await _syncMetadataDao.setCursor(
      'merchant_confirmations',
      _resolvedCursor(delta.cursor),
    );
    for (final id in deletedDelta.ids) {
      await _merchantConfirmationsRepository
          .applyRemoteDeleteMerchantConfirmation(
            id,
            deletedAt: deletedDelta.cursor,
          );
    }
    await _syncMetadataDao.setDeletedCursor(
      'merchant_confirmations',
      _resolvedCursor(deletedDelta.cursor),
    );
    if (kDebugMode) {
      final String finalCursor = delta.cursor.isNotEmpty
          ? delta.cursor
          : currentCursor;
      print(
        '[PULL] merchant_confirmations upserts=${delta.items.length} deletes=${deletedDelta.ids.length} cursorAfter=$finalCursor',
      );
    }
    return PullCollectionResult(
      collection: 'merchant_confirmations',
      path: _firestoreSyncManager.collectionPathForUid(
        uid,
        'merchant_confirmations',
      ),
      upsertsApplied: delta.items.length,
      deletesApplied: deletedDelta.ids.length,
      cursorUpdates: 2,
    );
  }

  Future<PullCollectionResult> _applyCorrectionFeedback({
    required String uid,
    required FirestoreCollectionDelta<CorrectionFeedback> delta,
    required FirestoreDeletedIdsDelta deletedDelta,
    required String currentCursor,
    required String currentDeletedCursor,
  }) async {
    if (kDebugMode) {
      print('[PULL] correction_feedback cursorBefore=$currentCursor');
    }
    for (final item in delta.items) {
      await _correctionFeedbackRepository.applyRemoteUpsertCorrectionFeedback(
        item,
        updatedAt: delta.cursor,
      );
    }
    await _syncMetadataDao.setCursor(
      'correction_feedback',
      _resolvedCursor(delta.cursor),
    );
    for (final id in deletedDelta.ids) {
      await _correctionFeedbackRepository.applyRemoteDeleteCorrectionFeedback(
        id,
        deletedAt: deletedDelta.cursor,
      );
    }
    await _syncMetadataDao.setDeletedCursor(
      'correction_feedback',
      _resolvedCursor(deletedDelta.cursor),
    );
    if (kDebugMode) {
      final String finalCursor = delta.cursor.isNotEmpty
          ? delta.cursor
          : currentCursor;
      print(
        '[PULL] correction_feedback upserts=${delta.items.length} deletes=${deletedDelta.ids.length} cursorAfter=$finalCursor',
      );
    }
    return PullCollectionResult(
      collection: 'correction_feedback',
      path: _firestoreSyncManager.collectionPathForUid(
        uid,
        'correction_feedback',
      ),
      upsertsApplied: delta.items.length,
      deletesApplied: deletedDelta.ids.length,
      cursorUpdates: 2,
    );
  }

  String _resolvedCursor(String cursor) {
    final String trimmed = cursor.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return DateTime.now().toUtc().toIso8601String();
  }
}
