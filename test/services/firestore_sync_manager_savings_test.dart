import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/services/firestore_sync_manager.dart';

void main() {
  test(
    'savings sync preserves gold silver and zero-remaining payloads',
    () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final MockFirebaseAuth auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'uid-1', email: 'user@example.com'),
      );
      final FirestoreSyncManager manager = FirestoreSyncManager(
        firestore: firestore,
        auth: auth,
      );

      const Saving gold = Saving(
        id: 'gold-saving',
        assetType: 'gold',
        dateAcquired: '2026-06-19',
        amount: 12.5,
        remainingAmount: 0,
        unit: '24',
        description: 'Closed gold lot',
        purchaseCurrency: 'USD',
        purchaseAmount: 800,
        createdAt: '2026-06-19T08:00:00.000Z',
        internalTransfer: true,
        internalTransferType: 'precious_metals_sale',
        transferActivityId: 'tx-gold',
      );
      const Saving silver = Saving(
        id: 'silver-saving',
        assetType: 'silver',
        dateAcquired: '2026-06-19',
        amount: 50,
        remainingAmount: 50,
        unit: 'g',
        description: 'Silver lot',
        purchaseCurrency: 'USD',
        purchaseAmount: 60,
        createdAt: '2026-06-19T08:00:00.000Z',
        fundingAllocations: <Map<String, dynamic>>[
          <String, dynamic>{
            'sourceId': 'income-1',
            'sourceType': 'income',
            'amount': 60,
            'currency': 'USD',
          },
        ],
      );

      await manager.syncSavings(
        uid: 'uid-1',
        items: const <Saving>[gold, silver],
      );

      final Map<String, dynamic> goldDoc =
          (await firestore
                  .collection('users')
                  .doc('uid-1')
                  .collection(FirestoreSyncManager.savingsCollection)
                  .doc('gold-saving')
                  .get())
              .data()!;
      final Map<String, dynamic> silverDoc =
          (await firestore
                  .collection('users')
                  .doc('uid-1')
                  .collection(FirestoreSyncManager.savingsCollection)
                  .doc('silver-saving')
                  .get())
              .data()!;

      for (final Map<String, dynamic> source in <Map<String, dynamic>>[
        gold.toJson(),
        silver.toJson(),
      ]) {
        final Map<String, dynamic> doc = source['id'] == 'gold-saving'
            ? goldDoc
            : silverDoc;
        for (final MapEntry<String, dynamic> entry in source.entries) {
          expect(doc[entry.key], entry.value, reason: 'field ${entry.key}');
        }
        expect(
          doc['schemaVersion'],
          FirestoreSyncManager.currentSyncSchemaVersion,
        );
        expect(doc['updatedAt'], isNotNull);
      }

      final FirestoreCollectionDelta<Saving> delta = await manager
          .loadSavingsSince(uid: 'uid-1', sinceCursor: '');
      expect(delta.items, hasLength(2));
      expect(
        delta.items.map((Saving item) => item.id),
        containsAll(<String>['gold-saving', 'silver-saving']),
      );
      expect(
        delta.items
            .firstWhere((Saving item) => item.id == 'gold-saving')
            .remainingAmount,
        0,
      );
    },
  );
}
