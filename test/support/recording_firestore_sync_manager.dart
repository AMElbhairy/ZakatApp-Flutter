import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

import 'package:zakatapp_flutter/models/correction_feedback.dart';
import 'package:zakatapp_flutter/models/financial_plan.dart';
import 'package:zakatapp_flutter/models/investment_asset.dart';
import 'package:zakatapp_flutter/models/merchant_confirmation.dart';
import 'package:zakatapp_flutter/models/merchant_rule.dart';
import 'package:zakatapp_flutter/models/pending_transaction.dart';
import 'package:zakatapp_flutter/models/recurring_transaction.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/services/firestore_sync_manager.dart';

class RecordingFirestoreSyncManager extends FirestoreSyncManager {
  RecordingFirestoreSyncManager({String uid = 'user-1'})
      : this._(FakeFirebaseFirestore(), uid);

  RecordingFirestoreSyncManager._(FakeFirebaseFirestore firestore, String uid)
      : firestore = firestore,
        super(
          firestore: firestore,
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(
              uid: uid,
              email: '$uid@example.com',
              displayName: uid,
            ),
          ),
        );

  final FakeFirebaseFirestore firestore;

  int transactionSyncCalls = 0;
  int savingsSyncCalls = 0;
  int captureInboxSyncCalls = 0;
  int merchantRulesSyncCalls = 0;
  int recurringTransactionsSyncCalls = 0;
  int investmentsSyncCalls = 0;
  int financialPlansSyncCalls = 0;
  int correctionFeedbackSyncCalls = 0;
  int merchantConfirmationsSyncCalls = 0;
  int userSettingsSyncCalls = 0;
  int userSettingsLoadCalls = 0;
  int userSettingsWatchCalls = 0;

  @override
  Future<void> syncTransactions({
    required String uid,
    required Iterable<Transaction> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    transactionSyncCalls += 1;
  }

  @override
  Future<void> syncSavings({
    required String uid,
    required Iterable<Saving> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    savingsSyncCalls += 1;
  }

  @override
  Future<void> syncCaptureInbox({
    required String uid,
    required Iterable<PendingTransaction> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    captureInboxSyncCalls += 1;
  }

  @override
  Future<void> syncMerchantRules({
    required String uid,
    required Iterable<MerchantRule> rules,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    merchantRulesSyncCalls += 1;
  }

  @override
  Future<void> syncRecurringTransactions({
    required String uid,
    required Iterable<RecurringTransaction> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    recurringTransactionsSyncCalls += 1;
  }

  @override
  Future<void> syncInvestments({
    required String uid,
    required Iterable<InvestmentAsset> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    investmentsSyncCalls += 1;
  }

  @override
  Future<void> syncFinancialPlans({
    required String uid,
    required Iterable<FinancialPlan> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    financialPlansSyncCalls += 1;
  }

  @override
  Future<void> syncCorrectionFeedback({
    required String uid,
    required Iterable<CorrectionFeedback> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    correctionFeedbackSyncCalls += 1;
  }

  @override
  Future<void> syncMerchantConfirmations({
    required String uid,
    required Iterable<MerchantConfirmation> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    merchantConfirmationsSyncCalls += 1;
  }

  @override
  Future<void> syncUserSettings({
    required String uid,
    required Map<String, dynamic> settings,
  }) async {
    userSettingsSyncCalls += 1;
  }

  @override
  Future<FirestoreCollectionDelta<Transaction>> loadTransactionsSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreCollectionDelta<Transaction>(
      items: <Transaction>[],
      cursor: '',
    );
  }

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedTransactionIdsSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreDeletedIdsDelta(ids: <String>[], cursor: '');
  }

  @override
  Future<FirestoreCollectionDelta<Saving>> loadSavingsSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreCollectionDelta<Saving>(
      items: <Saving>[],
      cursor: '',
    );
  }

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedSavingsSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreDeletedIdsDelta(ids: <String>[], cursor: '');
  }

  @override
  Future<FirestoreCollectionDelta<InvestmentAsset>> loadInvestmentsSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreCollectionDelta<InvestmentAsset>(
      items: <InvestmentAsset>[],
      cursor: '',
    );
  }

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedInvestmentsSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreDeletedIdsDelta(ids: <String>[], cursor: '');
  }

  @override
  Future<FirestoreCollectionDelta<PendingTransaction>> loadCaptureInboxSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreCollectionDelta<PendingTransaction>(
      items: <PendingTransaction>[],
      cursor: '',
    );
  }

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedCaptureInboxSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreDeletedIdsDelta(ids: <String>[], cursor: '');
  }

  @override
  Future<FirestoreCollectionDelta<RecurringTransaction>>
  loadRecurringTransactionsSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreCollectionDelta<RecurringTransaction>(
      items: <RecurringTransaction>[],
      cursor: '',
    );
  }

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedRecurringTransactionsSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreDeletedIdsDelta(ids: <String>[], cursor: '');
  }

  @override
  Future<FirestoreCollectionDelta<FinancialPlan>> loadFinancialPlansSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreCollectionDelta<FinancialPlan>(
      items: <FinancialPlan>[],
      cursor: '',
    );
  }

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedFinancialPlansSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreDeletedIdsDelta(ids: <String>[], cursor: '');
  }

  @override
  Future<FirestoreCollectionDelta<CorrectionFeedback>>
  loadCorrectionFeedbackSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreCollectionDelta<CorrectionFeedback>(
      items: <CorrectionFeedback>[],
      cursor: '',
    );
  }

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedCorrectionFeedbackSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreDeletedIdsDelta(ids: <String>[], cursor: '');
  }

  @override
  Future<FirestoreCollectionDelta<MerchantConfirmation>>
  loadMerchantConfirmationsSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreCollectionDelta<MerchantConfirmation>(
      items: <MerchantConfirmation>[],
      cursor: '',
    );
  }

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedMerchantConfirmationsSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreDeletedIdsDelta(ids: <String>[], cursor: '');
  }

  @override
  Future<FirestoreCollectionDelta<MerchantRule>> loadMerchantRulesSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreCollectionDelta<MerchantRule>(
      items: <MerchantRule>[],
      cursor: '',
    );
  }

  @override
  Future<FirestoreDeletedIdsDelta> loadDeletedMerchantRulesSince({
    required String uid,
    required String sinceCursor,
  }) async {
    return const FirestoreDeletedIdsDelta(ids: <String>[], cursor: '');
  }

  @override
  Future<Map<String, dynamic>> loadUserSettings({required String uid}) async {
    userSettingsLoadCalls += 1;
    return <String, dynamic>{};
  }

  @override
  Stream<Map<String, dynamic>> watchUserSettings({required String uid}) {
    userSettingsWatchCalls += 1;
    return const Stream<Map<String, dynamic>>.empty();
  }
}
