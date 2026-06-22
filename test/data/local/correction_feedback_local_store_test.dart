import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart'
    as db
    hide CorrectionFeedback;
import 'package:zakatapp_flutter/data/local/daos/correction_feedback_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/repositories/local_correction_feedback_repository.dart';
import 'package:zakatapp_flutter/models/correction_feedback.dart' as model;

model.CorrectionFeedback _item({
  required String id,
  String fieldName = 'category',
}) {
  return model.CorrectionFeedback(
    id: id,
    fieldName: fieldName,
    originalValue: 'Food',
    correctedValue: 'Bills',
    createdAt: '2026-06-19T08:00:00.000Z',
  );
}

void main() {
  late db.AppDatabase database;
  late CorrectionFeedbackDao dao;
  late SyncQueueDao syncQueueDao;
  late LocalCorrectionFeedbackRepository repository;

  setUp(() {
    database = db.AppDatabase(executor: NativeDatabase.memory());
    dao = CorrectionFeedbackDao(database);
    syncQueueDao = SyncQueueDao(database);
    repository = LocalCorrectionFeedbackRepository(
      correctionFeedbackDao: dao,
      syncQueueDao: syncQueueDao,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'repository saves, loads, and soft deletes correction feedback',
    () async {
      final model.CorrectionFeedback active = _item(id: 'fb-1');
      final model.CorrectionFeedback inactive = _item(id: 'fb-2');

      await repository.importCorrectionFeedback(<model.CorrectionFeedback>[
        active,
        inactive,
      ]);
      final List<model.CorrectionFeedback> loaded = await repository
          .getActiveCorrectionFeedback();

      expect(loaded, hasLength(2));
      expect(loaded.first.id, 'fb-1');

      await repository.deleteCorrectionFeedback('fb-1');
      final List<model.CorrectionFeedback> afterDelete = await repository
          .getActiveCorrectionFeedback();
      expect(afterDelete, hasLength(1));
      expect(afterDelete.single.id, 'fb-2');
    },
  );

  test('save and delete enqueue correction feedback queue rows', () async {
    final model.CorrectionFeedback item = _item(id: 'fb-queue');

    await repository.saveCorrectionFeedback(item);
    await repository.deleteCorrectionFeedback('fb-queue');

    final List<db.SyncQueueData> queueRows = await syncQueueDao
        .loadReadyBatch();
    expect(queueRows, hasLength(1));
    expect(queueRows.single.collectionName, 'correction_feedback');
    expect(queueRows.single.operation, 'delete');
  });

  test(
    'replaceAllForLocalMirror overwrites correction feedback snapshot',
    () async {
      await repository.importCorrectionFeedback(<model.CorrectionFeedback>[
        _item(id: 'old'),
      ]);

      await repository.replaceAllForLocalMirror(<model.CorrectionFeedback>[
        _item(id: 'new'),
      ]);

      final List<model.CorrectionFeedback> loaded = await repository
          .getActiveCorrectionFeedback();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'new');
    },
  );
}
