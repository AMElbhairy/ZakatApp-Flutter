import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../../models/correction_feedback.dart';
import '../../models/financial_plan.dart';
import '../../models/investment_asset.dart';
import '../../models/merchant_confirmation.dart';
import '../../models/merchant_rule.dart';
import '../../models/pending_transaction.dart';
import '../../models/recurring_transaction.dart';
import '../../models/saving.dart';
import '../../models/transaction.dart';
import '../../services/firestore_sync_manager.dart';
import '../../services/sync_diagnostics_service.dart';
import '../local/app_database.dart'
    hide
        Transaction,
        Saving,
        Investment,
        PendingTransaction,
        FinancialPlan,
        RecurringTransaction,
        MerchantRule,
        MerchantConfirmation,
        CorrectionFeedback;
import '../local/daos/sync_queue_dao.dart';

class SyncQueueProcessor {
  SyncQueueProcessor({
    required this._syncQueueDao,
    required this._firestoreSyncManager,
  });

  final SyncQueueDao _syncQueueDao;
  final FirestoreSyncManager _firestoreSyncManager;
  bool _isProcessing = false;

  bool get isProcessing => _isProcessing;

  /// Process any pending operations in the sync queue for the given user ID.
  Future<SyncQueueProcessResult> processQueue(String uid) async {
    if (_isProcessing) {
      return const SyncQueueProcessResult(
        attempted: 0,
        succeeded: 0,
        failed: 0,
      );
    }
    _isProcessing = true;

    if (kDebugMode) {
      print('[SYNC] processQueue start user=$uid');
    }

    int attempted = 0;
    int succeeded = 0;
    int failed = 0;
    try {
      while (true) {
        final String now = DateTime.now().toUtc().toIso8601String();
        final List<SyncQueueData> batch = await _syncQueueDao.loadReadyBatch(
          now: now,
          limit: 25,
        );

        if (batch.isEmpty) {
          if (kDebugMode) {
            print('[SYNC] ready items=0');
          }
          break;
        } else {
          if (kDebugMode) {
            print('[SYNC] ready items=${batch.length}');
          }
        }

        for (final SyncQueueData row in batch) {
          attempted += 1;
          if (kDebugMode) {
            print(
              '[SYNC] pushing ${row.collectionName}:${row.recordId} '
              '${row.operation} queueId=${row.id} attempt=${row.attemptCount} '
              'payload=${row.payloadJson ?? 'null'}',
            );
          }
          await SyncDiagnosticsService.record(
            level: 'info',
            subsystem: 'sync',
            message: 'Queue push attempt',
            metadata: <String, dynamic>{
              'collection': row.collectionName,
              'recordId': row.recordId,
              'operation': row.operation,
              'queueId': row.id,
              'attemptCount': row.attemptCount,
              'payload': row.payloadJson,
            },
          );
          try {
            await _pushRow(uid, row);
            if (kDebugMode) {
              print('[SYNC] success ${row.collectionName}:${row.recordId}');
            }
            await SyncDiagnosticsService.record(
              level: 'info',
              subsystem: 'sync',
              message: 'Queue push success',
              metadata: <String, dynamic>{
                'collection': row.collectionName,
                'recordId': row.recordId,
                'operation': row.operation,
                'queueId': row.id,
              },
            );
            await _syncQueueDao.deleteQueueRows([row.id]);
            succeeded += 1;
            if (kDebugMode) {
              print('[SYNC] deleted queue row ${row.id}');
            }
          } catch (error, stackTrace) {
            failed += 1;
            if (kDebugMode) {
              print(
                '[SYNC] failed ${row.collectionName}:${row.recordId} '
                'queueId=${row.id} error=$error payload=${row.payloadJson ?? 'null'}',
              );
              debugPrintStack(stackTrace: stackTrace);
            }
            await SyncDiagnosticsService.record(
              level: 'error',
              subsystem: 'sync',
              message: 'Queue push failure',
              metadata: <String, dynamic>{
                'collection': row.collectionName,
                'recordId': row.recordId,
                'operation': row.operation,
                'queueId': row.id,
                'attemptCount': row.attemptCount,
                'error': error.toString(),
                'stackTrace': stackTrace.toString(),
                'payload': row.payloadJson,
              },
            );
            final int nextAttempt = row.attemptCount + 1;
            // Backoff delay: delaySeconds = min(3600, pow(2, attemptCount) * 10)
            final double backoff = math.pow(2, nextAttempt) * 10.0;
            final int delaySeconds = math.min(3600, backoff.toInt());

            final String nextAvailable = DateTime.now()
                .toUtc()
                .add(Duration(seconds: delaySeconds))
                .toIso8601String();

            await _syncQueueDao.updateQueueRetry(
              id: row.id,
              attemptCount: nextAttempt,
              availableAt: nextAvailable,
              lastError: error.toString(),
            );
            if (kDebugMode) {
              print(
                '[SYNC] retry queueId=${row.id} attempt=$nextAttempt availableAt=$nextAvailable',
              );
            }
          }
        }
      }
    } finally {
      _isProcessing = false;
    }

    return SyncQueueProcessResult(
      attempted: attempted,
      succeeded: succeeded,
      failed: failed,
    );
  }

  Future<void> _pushRow(String uid, SyncQueueData row) async {
    final String collection = row.collectionName;
    final String operation = row.operation;
    final String recordId = row.recordId;
    final String? payloadJson = row.payloadJson;

    if (collection == 'transactions') {
      if (operation == 'upsert') {
        if (payloadJson == null) {
          throw StateError(
            'Upsert operation on transactions is missing payloadJson.',
          );
        }
        final Map<String, dynamic> json =
            jsonDecode(payloadJson) as Map<String, dynamic>;
        final Transaction tx = Transaction.fromJson(json);
        await _firestoreSyncManager.syncTransactions(
          uid: uid,
          items: [tx],
          deletedIds: [],
        );
      } else if (operation == 'delete') {
        await _firestoreSyncManager.syncTransactions(
          uid: uid,
          items: [],
          deletedIds: [recordId],
        );
      }
    } else if (collection == 'savings') {
      if (operation == 'upsert') {
        if (payloadJson == null) {
          throw StateError(
            'Upsert operation on savings is missing payloadJson.',
          );
        }
        final Map<String, dynamic> json =
            jsonDecode(payloadJson) as Map<String, dynamic>;
        final Saving saving = Saving.fromJson(json);
        await _firestoreSyncManager.syncSavings(
          uid: uid,
          items: [saving],
          deletedIds: [],
        );
      } else if (operation == 'delete') {
        await _firestoreSyncManager.syncSavings(
          uid: uid,
          items: [],
          deletedIds: [recordId],
        );
      }
    } else if (collection == 'investments') {
      if (operation == 'upsert') {
        if (payloadJson == null) {
          throw StateError(
            'Upsert operation on investments is missing payloadJson.',
          );
        }
        final Map<String, dynamic> json =
            jsonDecode(payloadJson) as Map<String, dynamic>;
        final InvestmentAsset investment = InvestmentAsset.fromJson(json);
        await _firestoreSyncManager.syncInvestments(
          uid: uid,
          items: [investment],
          deletedIds: [],
        );
      } else if (operation == 'delete') {
        await _firestoreSyncManager.syncInvestments(
          uid: uid,
          items: [],
          deletedIds: [recordId],
        );
      }
    } else if (collection == 'pending_transactions') {
      if (operation == 'upsert') {
        if (payloadJson == null) {
          throw StateError(
            'Upsert operation on pending_transactions is missing payloadJson.',
          );
        }
        final Map<String, dynamic> json =
            jsonDecode(payloadJson) as Map<String, dynamic>;
        final PendingTransaction pending = PendingTransaction.fromJson(json);
        await _firestoreSyncManager.syncCaptureInbox(
          uid: uid,
          items: [pending],
          deletedIds: [],
        );
      } else if (operation == 'delete') {
        await _firestoreSyncManager.syncCaptureInbox(
          uid: uid,
          items: [],
          deletedIds: [recordId],
        );
      }
    } else if (collection == 'financial_plans') {
      if (operation == 'upsert') {
        if (payloadJson == null) {
          throw StateError(
            'Upsert operation on financial_plans is missing payloadJson.',
          );
        }
        final Map<String, dynamic> json =
            jsonDecode(payloadJson) as Map<String, dynamic>;
        final FinancialPlan plan = FinancialPlan.fromJson(json);
        await _firestoreSyncManager.syncFinancialPlans(
          uid: uid,
          items: [plan],
          deletedIds: [],
        );
      } else if (operation == 'delete') {
        await _firestoreSyncManager.syncFinancialPlans(
          uid: uid,
          items: [],
          deletedIds: [recordId],
        );
      }
    } else if (collection == 'recurring_transactions') {
      if (operation == 'upsert') {
        if (payloadJson == null) {
          throw StateError(
            'Upsert operation on recurring_transactions is missing payloadJson.',
          );
        }
        final Map<String, dynamic> json =
            jsonDecode(payloadJson) as Map<String, dynamic>;
        final RecurringTransaction recurring = RecurringTransaction.fromJson(
          json,
        );
        await _firestoreSyncManager.syncRecurringTransactions(
          uid: uid,
          items: [recurring],
          deletedIds: [],
        );
      } else if (operation == 'delete') {
        await _firestoreSyncManager.syncRecurringTransactions(
          uid: uid,
          items: [],
          deletedIds: [recordId],
        );
      }
    } else if (collection == 'merchant_rules') {
      if (operation == 'upsert') {
        if (payloadJson == null) {
          throw StateError(
            'Upsert operation on merchant_rules is missing payloadJson.',
          );
        }
        final Map<String, dynamic> json =
            jsonDecode(payloadJson) as Map<String, dynamic>;
        final MerchantRule rule = MerchantRule.fromJson(json);
        await _firestoreSyncManager.syncMerchantRules(
          uid: uid,
          rules: <MerchantRule>[rule],
          deletedIds: const <String>[],
        );
      } else if (operation == 'delete') {
        await _firestoreSyncManager.syncMerchantRules(
          uid: uid,
          rules: const <MerchantRule>[],
          deletedIds: <String>[recordId],
        );
      }
    } else if (collection == 'merchant_confirmations') {
      if (operation == 'upsert') {
        if (payloadJson == null) {
          throw StateError(
            'Upsert operation on merchant_confirmations is missing payloadJson.',
          );
        }
        final Map<String, dynamic> json =
            jsonDecode(payloadJson) as Map<String, dynamic>;
        final MerchantConfirmation confirmation = MerchantConfirmation.fromJson(
          json,
        );
        await _firestoreSyncManager.syncMerchantConfirmations(
          uid: uid,
          items: <MerchantConfirmation>[confirmation],
          deletedIds: const <String>[],
        );
      } else if (operation == 'delete') {
        await _firestoreSyncManager.syncMerchantConfirmations(
          uid: uid,
          items: const <MerchantConfirmation>[],
          deletedIds: <String>[recordId],
        );
      }
    } else if (collection == 'correction_feedback') {
      if (operation == 'upsert') {
        if (payloadJson == null) {
          throw StateError(
            'Upsert operation on correction_feedback is missing payloadJson.',
          );
        }
        final Map<String, dynamic> json =
            jsonDecode(payloadJson) as Map<String, dynamic>;
        final CorrectionFeedback feedback = CorrectionFeedback.fromJson(json);
        await _firestoreSyncManager.syncCorrectionFeedback(
          uid: uid,
          items: <CorrectionFeedback>[feedback],
          deletedIds: const <String>[],
        );
      } else if (operation == 'delete') {
        await _firestoreSyncManager.syncCorrectionFeedback(
          uid: uid,
          items: const <CorrectionFeedback>[],
          deletedIds: <String>[recordId],
        );
      }
    } else {
      throw StateError('Unsupported sync queue collection: $collection');
    }
  }
}

class SyncQueueProcessResult {
  const SyncQueueProcessResult({
    required this.attempted,
    required this.succeeded,
    required this.failed,
  });

  final int attempted;
  final int succeeded;
  final int failed;

  bool get hadAttempts => attempted > 0;
  bool get hadSuccesses => succeeded > 0;
}
