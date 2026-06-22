import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart'
    as db
    hide MerchantRule;
import 'package:zakatapp_flutter/data/local/daos/merchant_rules_dao.dart';
import 'package:zakatapp_flutter/data/local/daos/sync_queue_dao.dart';
import 'package:zakatapp_flutter/data/local/mappers/merchant_rule_mapper.dart';
import 'package:zakatapp_flutter/data/repositories/local_merchant_rules_repository.dart';
import 'package:zakatapp_flutter/models/merchant_rule.dart' as model;

model.MerchantRule _rule({required String merchantName, String? builtinKey}) {
  return model.MerchantRule(
    merchantName: merchantName,
    categoryId: 'Food',
    defaultType: 'expense',
    autoApprove: true,
    usageCount: 5,
    confidence: 0.87,
    lastUsed: '2026-06-19T08:00:00.000Z',
    source: 'custom',
    aliases: <String>['Cafe', 'Coffee House'],
    enabled: true,
    isBuiltinOverride: builtinKey != null,
    builtinKey: builtinKey,
  );
}

void main() {
  late db.AppDatabase database;
  late MerchantRulesDao dao;
  late SyncQueueDao syncQueueDao;
  late LocalMerchantRulesRepository repository;
  late MerchantRuleMapper mapper;

  setUp(() {
    database = db.AppDatabase(executor: NativeDatabase.memory());
    mapper = const MerchantRuleMapper();
    dao = MerchantRulesDao(database, mapper: mapper);
    syncQueueDao = SyncQueueDao(database);
    repository = LocalMerchantRulesRepository(
      merchantRulesDao: dao,
      syncQueueDao: syncQueueDao,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('mapper round trips merchant rule rows', () async {
    final model.MerchantRule original = _rule(merchantName: 'Coffee Shop');
    await dao.upsertMerchantRuleRow(
      original,
      updatedAt: '2026-06-19T09:00:00.000Z',
    );
    final row = await (database.select(
      database.merchantRules,
    )..where((tbl) => tbl.id.equals('coffee shop'))).getSingle();
    final model.MerchantRule restored = mapper.fromRow(row);

    expect(restored.merchantName, original.merchantName);
    expect(restored.aliases, original.aliases);
    expect(restored.confidence, original.confidence);
  });

  test('repository saves, loads, and soft deletes merchant rules', () async {
    final model.MerchantRule active = _rule(merchantName: 'Coffee Shop');
    final model.MerchantRule inactive = _rule(
      merchantName: 'Bakery',
      builtinKey: 'bakery',
    );

    await repository.importMerchantRules(<model.MerchantRule>[
      active,
      inactive,
    ]);
    final Map<String, model.MerchantRule> loaded = await repository
        .getActiveMerchantRules();

    expect(loaded, hasLength(2));
    expect(loaded['coffee shop']?.merchantName, 'Coffee Shop');

    await repository.deleteMerchantRule('coffee shop');
    final Map<String, model.MerchantRule> afterDelete = await repository
        .getActiveMerchantRules();
    expect(afterDelete, hasLength(1));
    expect(afterDelete.containsKey('coffee shop'), isFalse);
    expect(afterDelete['bakery']?.merchantName, 'Bakery');
  });

  test('save and delete enqueue merchant rule queue rows', () async {
    final model.MerchantRule rule = _rule(merchantName: 'Coffee Shop');

    await repository.saveMerchantRule(rule);
    await repository.deleteMerchantRule('coffee shop');

    final List<db.SyncQueueData> queueRows = await syncQueueDao
        .loadReadyBatch();
    expect(queueRows, hasLength(1));
    expect(queueRows.single.collectionName, 'merchant_rules');
    expect(queueRows.single.operation, 'delete');
  });

  test('replaceAllForLocalMirror overwrites merchant snapshot', () async {
    await repository.importMerchantRules(<model.MerchantRule>[
      _rule(merchantName: 'Old Shop'),
    ]);

    await repository.replaceAllForLocalMirror(<model.MerchantRule>[
      _rule(merchantName: 'New Shop'),
    ]);

    final Map<String, model.MerchantRule> loaded = await repository
        .getActiveMerchantRules();
    expect(loaded, hasLength(1));
    expect(loaded['new shop']?.merchantName, 'New Shop');
  });
}
