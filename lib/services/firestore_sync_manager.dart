import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/correction_feedback.dart';
import '../models/financial_plan.dart';
import '../models/investment_asset.dart';
import '../models/merchant_confirmation.dart';
import '../models/merchant_rule.dart';
import '../models/pending_transaction.dart';
import '../models/recurring_transaction.dart';
import '../models/saving.dart';
import '../models/transaction.dart';

class FirestoreSyncAuthExpiredException implements Exception {
  const FirestoreSyncAuthExpiredException(this.message);

  final String message;

  @override
  String toString() => 'FirestoreSyncAuthExpiredException: $message';
}

class FirestoreSyncPermissionException implements Exception {
  const FirestoreSyncPermissionException(this.message);

  final String message;

  @override
  String toString() => 'FirestoreSyncPermissionException: $message';
}

class FirestoreCollectionDelta<T> {
  const FirestoreCollectionDelta({required this.items, required this.cursor});

  final List<T> items;
  final String cursor;
}

class FirestoreDeletedIdsDelta {
  const FirestoreDeletedIdsDelta({required this.ids, required this.cursor});

  final List<String> ids;
  final String cursor;
}

class FirestoreSyncManager {
  FirestoreSyncManager({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const String captureInboxCollection = 'captureInboxItems';
  static const String merchantRulesCollection = 'merchantRules';
  static const String transactionsCollection = 'transactions';
  static const String deletedTransactionsCollection = 'transactionsDeleted';
  static const String savingsCollection = 'savings';
  static const String deletedSavingsCollection = 'savingsDeleted';
  static const String recurringTransactionsCollection = 'recurringTransactions';
  static const String deletedRecurringTransactionsCollection =
      'recurringTransactionsDeleted';
  static const String investmentsCollection = 'investments';
  static const String deletedInvestmentsCollection = 'investmentsDeleted';
  static const String financialPlansCollection = 'financialPlans';
  static const String deletedFinancialPlansCollection = 'financialPlansDeleted';
  static const String correctionFeedbackCollection = 'correctionFeedback';
  static const String deletedCorrectionFeedbackCollection =
      'correctionFeedbackDeleted';
  static const String merchantConfirmationsCollection = 'merchantConfirmations';
  static const String deletedMerchantConfirmationsCollection =
      'merchantConfirmationsDeleted';
  static const String deletedMerchantRulesCollection = 'merchantRulesDeleted';
  static const String userSettingsCollection = 'userSettings';
  static const String userSettingsPreferencesDocument = 'preferences';
  static const String deletedCaptureInboxCollection = 'captureInboxDeleted';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<PendingTransaction>> watchCaptureInbox({required String uid}) {
    return watchCollection<PendingTransaction>(
      uid: uid,
      collection: captureInboxCollection,
      decoder: (String id, Map<String, dynamic> json) {
        return PendingTransaction.fromJson(<String, dynamic>{
          'id': id,
          ...json,
        });
      },
    );
  }

  Stream<List<MerchantRule>> watchMerchantRules({required String uid}) {
    return watchCollection<MerchantRule>(
      uid: uid,
      collection: merchantRulesCollection,
      decoder: (String _, Map<String, dynamic> json) =>
          MerchantRule.fromJson(json),
    );
  }

  Stream<List<Transaction>> watchTransactions({required String uid}) {
    return watchCollection<Transaction>(
      uid: uid,
      collection: transactionsCollection,
      decoder: (String id, Map<String, dynamic> json) {
        return Transaction.fromJson(<String, dynamic>{'id': id, ...json});
      },
    );
  }

  Stream<List<Saving>> watchSavings({required String uid}) {
    return watchCollection<Saving>(
      uid: uid,
      collection: savingsCollection,
      decoder: (String id, Map<String, dynamic> json) {
        return Saving.fromJson(<String, dynamic>{'id': id, ...json});
      },
    );
  }

  Stream<List<RecurringTransaction>> watchRecurringTransactions({
    required String uid,
  }) {
    return watchCollection<RecurringTransaction>(
      uid: uid,
      collection: recurringTransactionsCollection,
      decoder: (String id, Map<String, dynamic> json) {
        return RecurringTransaction.fromJson(<String, dynamic>{
          'id': id,
          ...json,
        });
      },
    );
  }

  Future<List<RecurringTransaction>> loadRecurringTransactions({
    required String uid,
  }) {
    return loadCollection<RecurringTransaction>(
      uid: uid,
      collection: recurringTransactionsCollection,
      decoder: (String id, Map<String, dynamic> json) {
        return RecurringTransaction.fromJson(<String, dynamic>{
          'id': id,
          ...json,
        });
      },
    );
  }

  Stream<List<InvestmentAsset>> watchInvestments({required String uid}) {
    return watchCollection<InvestmentAsset>(
      uid: uid,
      collection: investmentsCollection,
      decoder: (String id, Map<String, dynamic> json) {
        return InvestmentAsset.fromJson(<String, dynamic>{'id': id, ...json});
      },
    );
  }

  Stream<List<FinancialPlan>> watchFinancialPlans({required String uid}) {
    return watchCollection<FinancialPlan>(
      uid: uid,
      collection: financialPlansCollection,
      decoder: (String id, Map<String, dynamic> json) {
        return FinancialPlan.fromJson(<String, dynamic>{'id': id, ...json});
      },
    );
  }

  Future<List<FinancialPlan>> loadFinancialPlans({required String uid}) {
    return loadCollection<FinancialPlan>(
      uid: uid,
      collection: financialPlansCollection,
      decoder: (String id, Map<String, dynamic> json) {
        return FinancialPlan.fromJson(<String, dynamic>{'id': id, ...json});
      },
    );
  }

  Stream<List<CorrectionFeedback>> watchCorrectionFeedback({
    required String uid,
  }) {
    return watchCollection<CorrectionFeedback>(
      uid: uid,
      collection: correctionFeedbackCollection,
      decoder: (String id, Map<String, dynamic> json) {
        return CorrectionFeedback.fromJson(<String, dynamic>{
          'id': id,
          ...json,
        });
      },
    );
  }

  Future<List<CorrectionFeedback>> loadCorrectionFeedback({
    required String uid,
  }) {
    return loadCollection<CorrectionFeedback>(
      uid: uid,
      collection: correctionFeedbackCollection,
      decoder: (String id, Map<String, dynamic> json) {
        return CorrectionFeedback.fromJson(<String, dynamic>{
          'id': id,
          ...json,
        });
      },
    );
  }

  Stream<List<MerchantConfirmation>> watchMerchantConfirmations({
    required String uid,
  }) {
    return watchCollection<MerchantConfirmation>(
      uid: uid,
      collection: merchantConfirmationsCollection,
      decoder: (String id, Map<String, dynamic> json) {
        return MerchantConfirmation.fromJson(<String, dynamic>{
          'id': id,
          ...json,
        });
      },
    );
  }

  Future<List<MerchantConfirmation>> loadMerchantConfirmations({
    required String uid,
  }) {
    return loadCollection<MerchantConfirmation>(
      uid: uid,
      collection: merchantConfirmationsCollection,
      decoder: (String id, Map<String, dynamic> json) {
        return MerchantConfirmation.fromJson(<String, dynamic>{
          'id': id,
          ...json,
        });
      },
    );
  }

  Future<List<MerchantRule>> loadMerchantRules({required String uid}) {
    return loadCollection<MerchantRule>(
      uid: uid,
      collection: merchantRulesCollection,
      decoder: (String _, Map<String, dynamic> json) =>
          MerchantRule.fromJson(json),
    );
  }

  Stream<Map<String, dynamic>> watchUserSettings({required String uid}) {
    final Exception? accessError = _validateUidAccess(uid);
    if (accessError != null) {
      return Stream<Map<String, dynamic>>.error(accessError);
    }

    return _userSettingsDocument(uid)
        .snapshots()
        .map((snap) {
          return _stripFirestoreMetadata(snap.data() ?? <String, dynamic>{});
        })
        .handleError((Object error) {
          if (error is FirebaseException) throw _mapFirebaseException(error);
          throw error;
        });
  }

  Future<List<T>> loadCollection<T>({
    required String uid,
    required String collection,
    required T Function(String id, Map<String, dynamic> json) decoder,
  }) async {
    final Exception? accessError = _validateUidAccess(uid);
    if (accessError != null) throw accessError;

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _userCollection(
            uid,
            collection,
          ).orderBy('updatedAt', descending: true).get();
      final List<T> items = <T>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        try {
          items.add(decoder(doc.id, doc.data()));
        } catch (error, stack) {
          debugPrint(
            'FirestoreSyncManager.loadCollection: skipping malformed '
            'doc ${doc.id} — $error',
          );
          debugPrintStack(stackTrace: stack);
        }
      }
      return items;
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  Future<Map<String, dynamic>> loadUserSettings({required String uid}) async {
    final Exception? accessError = _validateUidAccess(uid);
    if (accessError != null) throw accessError;

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _userSettingsDocument(uid).get();
      return _stripFirestoreMetadata(snapshot.data() ?? <String, dynamic>{});
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  Future<void> syncCaptureInbox({
    required String uid,
    required List<PendingTransaction> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    await syncCollection<PendingTransaction>(
      uid: uid,
      collection: captureInboxCollection,
      items: items,
      idSelector: (PendingTransaction item) => item.id,
      encoder: (PendingTransaction item) => item.toJson(),
      deletedIds: deletedIds,
    );
    await _recordDeletedIds(
      uid: uid,
      collection: deletedCaptureInboxCollection,
      ids: deletedIds,
    );
  }

  Future<void> syncMerchantRules({
    required String uid,
    required Iterable<MerchantRule> rules,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    await syncCollection<MerchantRule>(
      uid: uid,
      collection: merchantRulesCollection,
      items: rules,
      idSelector: (MerchantRule rule) => rule.merchantName.toLowerCase().trim(),
      encoder: (MerchantRule rule) => rule.toJson(),
      deletedIds: deletedIds,
    );
    await _recordDeletedIds(
      uid: uid,
      collection: deletedMerchantRulesCollection,
      ids: deletedIds,
    );
  }

  Future<void> syncTransactions({
    required String uid,
    required Iterable<Transaction> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    await syncCollection<Transaction>(
      uid: uid,
      collection: transactionsCollection,
      items: items,
      idSelector: (Transaction item) => item.id,
      encoder: (Transaction item) => item.toJson(),
      deletedIds: deletedIds,
    );
    await _recordDeletedIds(
      uid: uid,
      collection: deletedTransactionsCollection,
      ids: deletedIds,
    );
  }

  Future<FirestoreCollectionDelta<Transaction>> loadTransactionsSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeltaSince<Transaction>(
      uid: uid,
      collection: transactionsCollection,
      sinceCursor: sinceCursor,
      decoder: (String id, Map<String, dynamic> json) =>
          Transaction.fromJson(<String, dynamic>{'id': id, ...json}),
    );
  }

  Future<FirestoreCollectionDelta<Saving>> loadSavingsSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeltaSince<Saving>(
      uid: uid,
      collection: savingsCollection,
      sinceCursor: sinceCursor,
      decoder: (String id, Map<String, dynamic> json) =>
          Saving.fromJson(<String, dynamic>{'id': id, ...json}),
    );
  }

  Future<FirestoreCollectionDelta<InvestmentAsset>> loadInvestmentsSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeltaSince<InvestmentAsset>(
      uid: uid,
      collection: investmentsCollection,
      sinceCursor: sinceCursor,
      decoder: (String id, Map<String, dynamic> json) =>
          InvestmentAsset.fromJson(<String, dynamic>{'id': id, ...json}),
    );
  }

  Future<FirestoreCollectionDelta<PendingTransaction>> loadCaptureInboxSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeltaSince<PendingTransaction>(
      uid: uid,
      collection: captureInboxCollection,
      sinceCursor: sinceCursor,
      decoder: (String id, Map<String, dynamic> json) =>
          PendingTransaction.fromJson(<String, dynamic>{'id': id, ...json}),
    );
  }

  Future<FirestoreCollectionDelta<RecurringTransaction>>
  loadRecurringTransactionsSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeltaSince<RecurringTransaction>(
      uid: uid,
      collection: recurringTransactionsCollection,
      sinceCursor: sinceCursor,
      decoder: (String id, Map<String, dynamic> json) =>
          RecurringTransaction.fromJson(<String, dynamic>{'id': id, ...json}),
    );
  }

  Future<FirestoreCollectionDelta<FinancialPlan>> loadFinancialPlansSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeltaSince<FinancialPlan>(
      uid: uid,
      collection: financialPlansCollection,
      sinceCursor: sinceCursor,
      decoder: (String id, Map<String, dynamic> json) =>
          FinancialPlan.fromJson(<String, dynamic>{'id': id, ...json}),
    );
  }

  Future<FirestoreCollectionDelta<CorrectionFeedback>>
  loadCorrectionFeedbackSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeltaSince<CorrectionFeedback>(
      uid: uid,
      collection: correctionFeedbackCollection,
      sinceCursor: sinceCursor,
      decoder: (String id, Map<String, dynamic> json) =>
          CorrectionFeedback.fromJson(<String, dynamic>{'id': id, ...json}),
    );
  }

  Future<FirestoreCollectionDelta<MerchantConfirmation>>
  loadMerchantConfirmationsSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeltaSince<MerchantConfirmation>(
      uid: uid,
      collection: merchantConfirmationsCollection,
      sinceCursor: sinceCursor,
      decoder: (String id, Map<String, dynamic> json) =>
          MerchantConfirmation.fromJson(<String, dynamic>{'id': id, ...json}),
    );
  }

  Future<FirestoreCollectionDelta<MerchantRule>> loadMerchantRulesSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeltaSince<MerchantRule>(
      uid: uid,
      collection: merchantRulesCollection,
      sinceCursor: sinceCursor,
      decoder: (String _, Map<String, dynamic> json) =>
          MerchantRule.fromJson(json),
    );
  }

  Future<FirestoreCollectionDelta<T>> _loadDeltaSince<T>({
    required String uid,
    required String collection,
    required String sinceCursor,
    required T Function(String id, Map<String, dynamic> json) decoder,
  }) async {
    final Exception? accessError = _validateUidAccess(uid);
    if (accessError != null) throw accessError;
    try {
      Query<Map<String, dynamic>> query = _userCollection(
        uid,
        collection,
      ).orderBy('updatedAt', descending: false);
      final Timestamp? since = _parseCursor(sinceCursor);
      if (since != null) {
        query = query.where('updatedAt', isGreaterThan: since);
      }
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      String cursor = sinceCursor;
      final List<T> items = <T>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        try {
          items.add(decoder(doc.id, doc.data()));
          cursor = _maxCursor(cursor, _cursorFromMap(doc.data(), 'updatedAt'));
        } catch (error, stack) {
          debugPrint(
            'FirestoreSyncManager._loadDeltaSince: skipping malformed '
            'doc ${doc.id} — $error',
          );
          debugPrintStack(stackTrace: stack);
        }
      }
      return FirestoreCollectionDelta<T>(items: items, cursor: cursor);
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  Future<FirestoreDeletedIdsDelta> loadDeletedTransactionIdsSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeletedIdsSince(
      uid: uid,
      collection: deletedTransactionsCollection,
      sinceCursor: sinceCursor,
    );
  }

  Future<FirestoreDeletedIdsDelta> loadDeletedSavingsSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeletedIdsSince(
      uid: uid,
      collection: deletedSavingsCollection,
      sinceCursor: sinceCursor,
    );
  }

  Future<FirestoreDeletedIdsDelta> loadDeletedInvestmentsSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeletedIdsSince(
      uid: uid,
      collection: deletedInvestmentsCollection,
      sinceCursor: sinceCursor,
    );
  }

  Future<FirestoreDeletedIdsDelta> loadDeletedCaptureInboxSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeletedIdsSince(
      uid: uid,
      collection: deletedCaptureInboxCollection,
      sinceCursor: sinceCursor,
    );
  }

  Future<FirestoreDeletedIdsDelta> loadDeletedRecurringTransactionsSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeletedIdsSince(
      uid: uid,
      collection: deletedRecurringTransactionsCollection,
      sinceCursor: sinceCursor,
    );
  }

  Future<FirestoreDeletedIdsDelta> loadDeletedFinancialPlansSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeletedIdsSince(
      uid: uid,
      collection: deletedFinancialPlansCollection,
      sinceCursor: sinceCursor,
    );
  }

  Future<FirestoreDeletedIdsDelta> loadDeletedCorrectionFeedbackSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeletedIdsSince(
      uid: uid,
      collection: deletedCorrectionFeedbackCollection,
      sinceCursor: sinceCursor,
    );
  }

  Future<FirestoreDeletedIdsDelta> loadDeletedMerchantConfirmationsSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeletedIdsSince(
      uid: uid,
      collection: deletedMerchantConfirmationsCollection,
      sinceCursor: sinceCursor,
    );
  }

  Future<FirestoreDeletedIdsDelta> loadDeletedMerchantRulesSince({
    required String uid,
    required String sinceCursor,
  }) {
    return _loadDeletedIdsSince(
      uid: uid,
      collection: deletedMerchantRulesCollection,
      sinceCursor: sinceCursor,
    );
  }

  Future<FirestoreDeletedIdsDelta> _loadDeletedIdsSince({
    required String uid,
    required String collection,
    required String sinceCursor,
  }) async {
    final Exception? accessError = _validateUidAccess(uid);
    if (accessError != null) throw accessError;
    try {
      Query<Map<String, dynamic>> query = _userCollection(
        uid,
        collection,
      ).orderBy('deletedAt', descending: false);
      final Timestamp? since = _parseCursor(sinceCursor);
      if (since != null) {
        query = query.where('deletedAt', isGreaterThan: since);
      }
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      String cursor = sinceCursor;
      final List<String> ids = <String>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final String id = (doc.data()['id'] ?? doc.id).toString().trim();
        if (id.isNotEmpty) {
          ids.add(id);
        }
        cursor = _maxCursor(cursor, _cursorFromMap(doc.data(), 'deletedAt'));
      }
      return FirestoreDeletedIdsDelta(ids: ids, cursor: cursor);
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  Future<void> syncSavings({
    required String uid,
    required Iterable<Saving> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    await syncCollection<Saving>(
      uid: uid,
      collection: savingsCollection,
      items: items,
      idSelector: (Saving item) => item.id,
      encoder: (Saving item) => item.toJson(),
      deletedIds: deletedIds,
    );
    await _recordDeletedIds(
      uid: uid,
      collection: deletedSavingsCollection,
      ids: deletedIds,
    );
  }

  Future<void> syncRecurringTransactions({
    required String uid,
    required Iterable<RecurringTransaction> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    await syncCollection<RecurringTransaction>(
      uid: uid,
      collection: recurringTransactionsCollection,
      items: items,
      idSelector: (RecurringTransaction item) => item.id,
      encoder: (RecurringTransaction item) => item.toJson(),
      deletedIds: deletedIds,
    );
    await _recordDeletedIds(
      uid: uid,
      collection: deletedRecurringTransactionsCollection,
      ids: deletedIds,
    );
  }

  Future<void> syncInvestments({
    required String uid,
    required Iterable<InvestmentAsset> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    await syncCollection<InvestmentAsset>(
      uid: uid,
      collection: investmentsCollection,
      items: items,
      idSelector: (InvestmentAsset item) => item.id,
      encoder: (InvestmentAsset item) => item.toJson(),
      deletedIds: deletedIds,
    );
    await _recordDeletedIds(
      uid: uid,
      collection: deletedInvestmentsCollection,
      ids: deletedIds,
    );
  }

  Future<void> syncFinancialPlans({
    required String uid,
    required Iterable<FinancialPlan> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    await syncCollection<FinancialPlan>(
      uid: uid,
      collection: financialPlansCollection,
      items: items,
      idSelector: (FinancialPlan item) => item.id,
      encoder: (FinancialPlan item) => item.toJson(),
      deletedIds: deletedIds,
    );
    await _recordDeletedIds(
      uid: uid,
      collection: deletedFinancialPlansCollection,
      ids: deletedIds,
    );
  }

  Future<void> syncCorrectionFeedback({
    required String uid,
    required Iterable<CorrectionFeedback> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    await syncCollection<CorrectionFeedback>(
      uid: uid,
      collection: correctionFeedbackCollection,
      items: items,
      idSelector: (CorrectionFeedback item) => item.id,
      encoder: (CorrectionFeedback item) => item.toJson(),
      deletedIds: deletedIds,
    );
    await _recordDeletedIds(
      uid: uid,
      collection: deletedCorrectionFeedbackCollection,
      ids: deletedIds,
    );
  }

  Future<void> syncMerchantConfirmations({
    required String uid,
    required Iterable<MerchantConfirmation> items,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    await syncCollection<MerchantConfirmation>(
      uid: uid,
      collection: merchantConfirmationsCollection,
      items: items,
      idSelector: (MerchantConfirmation item) =>
          '${item.merchantName.toLowerCase().trim()}|${item.categoryId.toLowerCase().trim()}',
      encoder: (MerchantConfirmation item) => item.toJson(),
      deletedIds: deletedIds,
    );
    await _recordDeletedIds(
      uid: uid,
      collection: deletedMerchantConfirmationsCollection,
      ids: deletedIds,
    );
  }

  Future<void> syncUserSettings({
    required String uid,
    required Map<String, dynamic> settings,
  }) async {
    final Exception? accessError = _validateUidAccess(uid);
    if (accessError != null) throw accessError;

    try {
      await _userSettingsDocument(uid).set(<String, dynamic>{
        ...settings,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  Future<void> deleteAllUserData({required String uid}) async {
    final Exception? accessError = _validateUidAccess(uid);
    if (accessError != null) throw accessError;
    try {
      await _deleteCollection(uid, captureInboxCollection);
      await _deleteCollection(uid, merchantRulesCollection);
      await _deleteCollection(uid, transactionsCollection);
      await _deleteCollection(uid, savingsCollection);
      await _deleteCollection(uid, recurringTransactionsCollection);
      await _deleteCollection(uid, investmentsCollection);
      await _deleteCollection(uid, financialPlansCollection);
      await _deleteCollection(uid, correctionFeedbackCollection);
      await _deleteCollection(uid, merchantConfirmationsCollection);
      await _userSettingsDocument(uid).delete();
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  Stream<List<T>> watchCollection<T>({
    required String uid,
    required String collection,
    required T Function(String id, Map<String, dynamic> json) decoder,
  }) {
    final Exception? accessError = _validateUidAccess(uid);
    if (accessError != null) return Stream<List<T>>.error(accessError);

    return _userCollection(uid, collection)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
          final List<T> items = <T>[];
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in snap.docs) {
            try {
              items.add(decoder(doc.id, doc.data()));
            } catch (error, stack) {
              debugPrint(
                'FirestoreSyncManager.watchCollection: skipping malformed '
                'doc ${doc.id} — $error',
              );
              debugPrintStack(stackTrace: stack);
            }
          }
          return items;
        })
        .handleError((Object error) {
          if (error is FirebaseException) throw _mapFirebaseException(error);
          throw error;
        });
  }

  Future<void> syncCollection<T>({
    required String uid,
    required String collection,
    required Iterable<T> items,
    required String Function(T item) idSelector,
    required Map<String, dynamic> Function(T item) encoder,
    Iterable<String> deletedIds = const <String>[],
  }) async {
    final Exception? accessError = _validateUidAccess(uid);
    if (accessError != null) throw accessError;
    try {
      final CollectionReference<Map<String, dynamic>> collectionRef =
          _userCollection(uid, collection);
      final Map<String, Map<String, dynamic>> payloads =
          <String, Map<String, dynamic>>{};
      for (final T item in items) {
        final String id = idSelector(item).trim();
        if (id.isEmpty) continue;
        payloads[id] = <String, dynamic>{
          ...encoder(item),
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }

      await _commitSetOperations(collectionRef, payloads);
      await _commitDeleteOperations(collectionRef, deletedIds);
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  Future<void> deleteItem({
    required String uid,
    required String collection,
    required String id,
  }) async {
    final Exception? accessError = _validateUidAccess(uid);
    if (accessError != null) throw accessError;
    try {
      await _userCollection(uid, collection).doc(id).delete();
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  CollectionReference<Map<String, dynamic>> _userCollection(
    String uid,
    String collection,
  ) => _firestore.collection('users').doc(uid).collection(collection);

  DocumentReference<Map<String, dynamic>> _userSettingsDocument(String uid) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection(userSettingsCollection)
          .doc(userSettingsPreferencesDocument);

  Map<String, dynamic> _stripFirestoreMetadata(Map<String, dynamic> data) {
    final Map<String, dynamic> copy = Map<String, dynamic>.from(data);
    copy.remove('updatedAt');
    copy.remove('createdAt');
    copy.remove('serverTimestamp');
    return copy;
  }

  Future<void> _commitSetOperations(
    CollectionReference<Map<String, dynamic>> collectionRef,
    Map<String, Map<String, dynamic>> payloads,
  ) async {
    const int maxBatchSize = 450;
    final List<MapEntry<String, Map<String, dynamic>>> entries = payloads
        .entries
        .toList(growable: false);
    for (int index = 0; index < entries.length; index += maxBatchSize) {
      final WriteBatch batch = _firestore.batch();
      final int end = (index + maxBatchSize < entries.length)
          ? index + maxBatchSize
          : entries.length;
      for (int i = index; i < end; i++) {
        final MapEntry<String, Map<String, dynamic>> entry = entries[i];
        batch.set(
          collectionRef.doc(entry.key),
          entry.value,
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  Future<void> _commitDeleteOperations(
    CollectionReference<Map<String, dynamic>> collectionRef,
    Iterable<String> deletedIds,
  ) async {
    const int maxBatchSize = 450;
    final List<String> deletions = deletedIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    for (int index = 0; index < deletions.length; index += maxBatchSize) {
      final WriteBatch batch = _firestore.batch();
      final int end = (index + maxBatchSize < deletions.length)
          ? index + maxBatchSize
          : deletions.length;
      for (int i = index; i < end; i++) {
        batch.delete(collectionRef.doc(deletions[i]));
      }
      await batch.commit();
    }
  }

  Future<void> _recordDeletedIds({
    required String uid,
    required String collection,
    required Iterable<String> ids,
  }) async {
    final List<String> cleaned = ids
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (cleaned.isEmpty) return;
    const int maxBatchSize = 450;
    final CollectionReference<Map<String, dynamic>> collectionRef =
        _userCollection(uid, collection);
    for (int index = 0; index < cleaned.length; index += maxBatchSize) {
      final WriteBatch batch = _firestore.batch();
      final int end = (index + maxBatchSize < cleaned.length)
          ? index + maxBatchSize
          : cleaned.length;
      for (int i = index; i < end; i++) {
        final String id = cleaned[i];
        batch.set(collectionRef.doc(id), <String, dynamic>{
          'id': id,
          'deletedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  Timestamp? _parseCursor(String cursor) {
    final String raw = cursor.trim();
    if (raw.isEmpty) return null;
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return Timestamp.fromDate(parsed.toUtc());
  }

  String _cursorFromMap(Map<String, dynamic> data, String field) {
    final dynamic value = data[field];
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    return '';
  }

  String _maxCursor(String left, String right) {
    if (left.trim().isEmpty) return right;
    if (right.trim().isEmpty) return left;
    final DateTime? leftDate = DateTime.tryParse(left);
    final DateTime? rightDate = DateTime.tryParse(right);
    if (leftDate == null) return right;
    if (rightDate == null) return left;
    return rightDate.isAfter(leftDate) ? right : left;
  }

  Future<void> _deleteCollection(String uid, String collection) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _userCollection(
      uid,
      collection,
    ).get();
    if (snapshot.docs.isEmpty) return;
    const int maxBatchSize = 450;
    for (int index = 0; index < snapshot.docs.length; index += maxBatchSize) {
      final WriteBatch batch = _firestore.batch();
      final int end = (index + maxBatchSize < snapshot.docs.length)
          ? index + maxBatchSize
          : snapshot.docs.length;
      for (int i = index; i < end; i++) {
        batch.delete(snapshot.docs[i].reference);
      }
      await batch.commit();
    }
  }

  Exception? _validateUidAccess(String uid) {
    final User? current = _auth.currentUser;
    if (current == null || current.uid != uid) {
      return const FirestoreSyncAuthExpiredException(
        'Session missing or expired. Please sign in again.',
      );
    }
    return null;
  }

  Exception _mapFirebaseException(FirebaseException error) {
    final String code = error.code.toLowerCase();
    final String message = error.message ?? 'Cloud sync failed.';
    final bool isUnauth =
        code == 'unauthenticated' ||
        code == 'user-token-expired' ||
        message.contains('401') ||
        message.toLowerCase().contains('expired') ||
        message.toLowerCase().contains('unauth');
    if (isUnauth) return FirestoreSyncAuthExpiredException(message);
    if (code == 'permission-denied') {
      return FirestoreSyncPermissionException(message);
    }
    return Exception(message);
  }
}
