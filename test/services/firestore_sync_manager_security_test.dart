import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/models/merchant_rule.dart';
import 'package:zakatapp_flutter/models/pending_transaction.dart';
import 'package:zakatapp_flutter/services/firestore_sync_manager.dart';

void main() {
  group('FirestoreSyncManager account isolation', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('account A cannot write into account B collection', () async {
      final MockFirebaseAuth authA = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(
          uid: 'accountA',
          email: 'a@example.com',
          displayName: 'Account A',
        ),
      );

      final FirestoreSyncManager manager = FirestoreSyncManager(
        firestore: firestore,
        auth: authA,
      );

      await expectLater(
        manager.syncCaptureInbox(
          uid: 'accountB',
          items: <PendingTransaction>[
            const PendingTransaction(
              id: 'pending-1',
              source: PendingTransactionSource.manual,
              rawMessage: 'test',
              createdAt: '2026-06-18T00:00:00.000Z',
              suggestedType: 'expense',
              confidence: 0.8,
              status: CaptureStatus.pendingReview,
            ),
          ],
        ),
        throwsA(isA<FirestoreSyncAuthExpiredException>()),
      );
    });

    test('account A cannot read account B collection', () async {
      await firestore
          .collection('users')
          .doc('accountB')
          .collection(FirestoreSyncManager.merchantRulesCollection)
          .doc('rule-1')
          .set(
            const MerchantRule(
              merchantName: 'Coffee Shop',
              categoryId: 'Food & Dining',
              defaultType: 'expense',
              autoApprove: true,
              usageCount: 10,
              confidence: 0.95,
              source: 'custom',
            ).toJson(),
          );

      final MockFirebaseAuth authA = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(
          uid: 'accountA',
          email: 'a@example.com',
          displayName: 'Account A',
        ),
      );

      final FirestoreSyncManager manager = FirestoreSyncManager(
        firestore: firestore,
        auth: authA,
      );

      final Stream<List<MerchantRule>> stream = manager.watchMerchantRules(
        uid: 'accountB',
      );

      await expectLater(
        stream.first,
        throwsA(isA<FirestoreSyncAuthExpiredException>()),
      );
    });
  });
}
