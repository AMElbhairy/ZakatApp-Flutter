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

class FirestoreSyncManager {
  FirestoreSyncManager({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const String captureInboxCollection = 'captureInboxItems';
  static const String merchantRulesCollection = 'merchantRules';
  static const String transactionsCollection = 'transactions';
  static const String savingsCollection = 'savings';
  static const String recurringTransactionsCollection = 'recurringTransactions';
  static const String investmentsCollection = 'investments';
  static const String financialPlansCollection = 'financialPlans';
  static const String correctionFeedbackCollection = 'correctionFeedback';
  static const String merchantConfirmationsCollection = 'merchantConfirmations';
  static const String userSettingsCollection = 'userSettings';
  static const String userSettingsPreferencesDocument = 'preferences';

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

  Future<void> syncCaptureInbox({
    required String uid,
    required List<PendingTransaction> items,
  }) async {
    await syncCollection<PendingTransaction>(
      uid: uid,
      collection: captureInboxCollection,
      items: items,
      idSelector: (PendingTransaction item) => item.id,
      encoder: (PendingTransaction item) => item.toJson(),
    );
  }

  Future<void> syncMerchantRules({
    required String uid,
    required Iterable<MerchantRule> rules,
  }) async {
    await syncCollection<MerchantRule>(
      uid: uid,
      collection: merchantRulesCollection,
      items: rules,
      idSelector: (MerchantRule rule) => rule.merchantName.toLowerCase().trim(),
      encoder: (MerchantRule rule) => rule.toJson(),
    );
  }

  Future<void> syncTransactions({
    required String uid,
    required Iterable<Transaction> items,
  }) async {
    await syncCollection<Transaction>(
      uid: uid,
      collection: transactionsCollection,
      items: items,
      idSelector: (Transaction item) => item.id,
      encoder: (Transaction item) => item.toJson(),
    );
  }

  Future<void> syncSavings({
    required String uid,
    required Iterable<Saving> items,
  }) async {
    await syncCollection<Saving>(
      uid: uid,
      collection: savingsCollection,
      items: items,
      idSelector: (Saving item) => item.id,
      encoder: (Saving item) => item.toJson(),
    );
  }

  Future<void> syncRecurringTransactions({
    required String uid,
    required Iterable<RecurringTransaction> items,
  }) async {
    await syncCollection<RecurringTransaction>(
      uid: uid,
      collection: recurringTransactionsCollection,
      items: items,
      idSelector: (RecurringTransaction item) => item.id,
      encoder: (RecurringTransaction item) => item.toJson(),
    );
  }

  Future<void> syncInvestments({
    required String uid,
    required Iterable<InvestmentAsset> items,
  }) async {
    await syncCollection<InvestmentAsset>(
      uid: uid,
      collection: investmentsCollection,
      items: items,
      idSelector: (InvestmentAsset item) => item.id,
      encoder: (InvestmentAsset item) => item.toJson(),
    );
  }

  Future<void> syncFinancialPlans({
    required String uid,
    required Iterable<FinancialPlan> items,
  }) async {
    await syncCollection<FinancialPlan>(
      uid: uid,
      collection: financialPlansCollection,
      items: items,
      idSelector: (FinancialPlan item) => item.id,
      encoder: (FinancialPlan item) => item.toJson(),
    );
  }

  Future<void> syncCorrectionFeedback({
    required String uid,
    required Iterable<CorrectionFeedback> items,
  }) async {
    await syncCollection<CorrectionFeedback>(
      uid: uid,
      collection: correctionFeedbackCollection,
      items: items,
      idSelector: (CorrectionFeedback item) => item.id,
      encoder: (CorrectionFeedback item) => item.toJson(),
    );
  }

  Future<void> syncMerchantConfirmations({
    required String uid,
    required Iterable<MerchantConfirmation> items,
  }) async {
    await syncCollection<MerchantConfirmation>(
      uid: uid,
      collection: merchantConfirmationsCollection,
      items: items,
      idSelector: (MerchantConfirmation item) =>
          '${item.merchantName.toLowerCase().trim()}|${item.categoryId.toLowerCase().trim()}',
      encoder: (MerchantConfirmation item) => item.toJson(),
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
  }) async {
    final Exception? accessError = _validateUidAccess(uid);
    if (accessError != null) throw accessError;
    try {
      final CollectionReference<Map<String, dynamic>> collectionRef =
          _userCollection(uid, collection);
      final QuerySnapshot<Map<String, dynamic>> existingSnapshot =
          await collectionRef.get();
      final Map<String, DocumentReference<Map<String, dynamic>>> existingDocs =
          <String, DocumentReference<Map<String, dynamic>>>{
            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                in existingSnapshot.docs)
              doc.id: doc.reference,
          };

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
      await _commitDeleteOperations(existingDocs, payloads.keys.toSet());
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
    Map<String, DocumentReference<Map<String, dynamic>>> existingDocs,
    Set<String> nextIds,
  ) async {
    const int maxBatchSize = 450;
    final List<DocumentReference<Map<String, dynamic>>>
    deletions = <DocumentReference<Map<String, dynamic>>>[
      for (final MapEntry<String, DocumentReference<Map<String, dynamic>>> entry
          in existingDocs.entries)
        if (!nextIds.contains(entry.key)) entry.value,
    ];
    for (int index = 0; index < deletions.length; index += maxBatchSize) {
      final WriteBatch batch = _firestore.batch();
      final int end = (index + maxBatchSize < deletions.length)
          ? index + maxBatchSize
          : deletions.length;
      for (int i = index; i < end; i++) {
        batch.delete(deletions[i]);
      }
      await batch.commit();
    }
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
