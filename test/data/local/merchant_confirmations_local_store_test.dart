import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart'
    as db
    hide MerchantConfirmation;
import 'package:zakatapp_flutter/data/local/daos/merchant_confirmations_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/repositories/local_merchant_confirmations_repository.dart';
import 'package:zakatapp_flutter/models/merchant_confirmation.dart' as model;

model.MerchantConfirmation _item({
  required String merchantName,
  required String categoryId,
}) {
  return model.MerchantConfirmation(
    merchantName: merchantName,
    categoryId: categoryId,
    confirmations: 3,
    corrections: 1,
  );
}

void main() {
  late db.AppDatabase database;
  late MerchantConfirmationsDao dao;
  late SyncQueueDao syncQueueDao;
  late LocalMerchantConfirmationsRepository repository;

  setUp(() {
    database = db.AppDatabase(executor: NativeDatabase.memory());
    dao = MerchantConfirmationsDao(database);
    syncQueueDao = SyncQueueDao(database);
    repository = LocalMerchantConfirmationsRepository(
      merchantConfirmationsDao: dao,
      syncQueueDao: syncQueueDao,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'repository saves, loads, and soft deletes merchant confirmations',
    () async {
      final model.MerchantConfirmation active = _item(
        merchantName: 'Coffee Shop',
        categoryId: 'Food',
      );
      final model.MerchantConfirmation inactive = _item(
        merchantName: 'Bakery',
        categoryId: 'Food',
      );

      await repository.importMerchantConfirmations(<model.MerchantConfirmation>[
        active,
        inactive,
      ]);
      final List<model.MerchantConfirmation> loaded = await repository
          .getActiveMerchantConfirmations();

      expect(loaded, hasLength(2));
      expect(
        loaded.map((model.MerchantConfirmation item) => item.merchantName),
        containsAll(<String>['Coffee Shop', 'Bakery']),
      );

      await repository.deleteMerchantConfirmation('coffee shop|food');
      final List<model.MerchantConfirmation> afterDelete = await repository
          .getActiveMerchantConfirmations();
      expect(afterDelete, hasLength(1));
      expect(afterDelete.single.merchantName, 'Bakery');
    },
  );

  test('save and delete enqueue merchant confirmation queue rows', () async {
    final model.MerchantConfirmation item = _item(
      merchantName: 'Coffee Shop',
      categoryId: 'Food',
    );

    await repository.saveMerchantConfirmation(item);
    await repository.deleteMerchantConfirmation('coffee shop|food');

    final List<db.SyncQueueData> queueRows = await syncQueueDao
        .loadReadyBatch();
    expect(queueRows, hasLength(1));
    expect(queueRows.single.collectionName, 'merchant_confirmations');
    expect(queueRows.single.operation, 'delete');
  });

  test(
    'replaceAllForLocalMirror overwrites merchant confirmation snapshot',
    () async {
      await repository.importMerchantConfirmations(<model.MerchantConfirmation>[
        _item(merchantName: 'Old', categoryId: 'Bills'),
      ]);

      await repository.replaceAllForLocalMirror(<model.MerchantConfirmation>[
        _item(merchantName: 'New', categoryId: 'Bills'),
      ]);

      final List<model.MerchantConfirmation> loaded = await repository
          .getActiveMerchantConfirmations();
      expect(loaded, hasLength(1));
      expect(loaded.single.merchantName, 'New');
    },
  );
}
