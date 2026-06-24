import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/market_snapshot.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/backup_restore_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

void main() {
  late AppStateController controller;
  late BackupRestoreService service;
  late AppStateRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService storage = LocalStorageService();
    repository = AppStateRepository(localStorage: storage);
    controller = AppStateController(repository: repository);
    await controller.load();
    service = BackupRestoreService(controller: controller);
  });

  test('replace restore persists state', () async {
    final String raw = '''
{"appName":"ZakatApp","schemaVersion":1,"exportedAt":"2026-01-01T00:00:00Z","counts":{},"appState":{"transactions":[{"id":"tx1","date":"2026-01-01"}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[]}}
''';

    await service.restoreReplace(raw, allowWhenLocalDataExists: true);
    expect(controller.state.transactions.length, 1);
    expect(controller.state.transactions.first.id, 'tx1');
  });

  test('merge restore upserts by id', () async {
    await service.restoreReplace(
      '{"appName":"ZakatApp","appState":{"transactions":[{"id":"tx1","description":"old"}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[]}}',
      allowWhenLocalDataExists: true,
    );

    await service.restoreMerge(
      '{"appName":"ZakatApp","appState":{"transactions":[{"id":"tx1","description":"new"},{"id":"tx2","description":"second"}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[]}}',
      allowWhenLocalDataExists: true,
    );

    expect(controller.state.transactions.length, 2);
    expect(
      controller.state.transactions
          .firstWhere((e) => e.id == 'tx1')
          .description,
      'new',
    );
  });

  test('local conflict requires explicit action', () async {
    await service.restoreReplace(
      '{"appName":"ZakatApp","appState":{"transactions":[{"id":"tx1"}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[]}}',
      allowWhenLocalDataExists: true,
    );

    expect(
      () => service.restoreReplace(
        '{"appName":"ZakatApp","appState":{"transactions":[{"id":"tx2"}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[]}}',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'merge restore keeps existing market data when incoming market data is empty',
    () async {
      await controller.updateMarketSnapshot(
        const MarketSnapshot(
          gold24kPricePerGramEgp: 5400,
          silverPricePerGramEgp: 64,
          usdToEgp: 50,
          sarToEgp: 13.3,
          aedToEgp: 13.6,
          kwdToEgp: 160,
          qarToEgp: 13.7,
          eurToEgp: 54,
          gbpToEgp: 63,
          bhdToEgp: 133,
          omrToEgp: 130,
          jodToEgp: 71,
          tryToEgp: 1.5,
          myrToEgp: 10.8,
          pkrToEgp: 0.18,
          idrToEgp: 0.0031,
          lastUpdated: '2026-01-01T00:00:00Z',
        ),
      );

      await service.restoreMerge(
        '{"appName":"ZakatApp","appState":{"transactions":[],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[],"marketData":{}}}',
        allowWhenLocalDataExists: true,
      );

      expect(controller.currentMarketSnapshot.usdToEgp, 50);
      expect(
        controller.currentMarketSnapshot.lastUpdated,
        '2026-01-01T00:00:00Z',
      );
    },
  );

  test('merge restore keeps zakat paid state across reloads', () async {
    final AppStateModel initialState = AppStateDefaults.create().copyWith(
      userId: 'user-1',
      zakatPaidMonths: <String>['2026-06'],
      processedExpenseIds: <String>['tx-paid'],
      zakatExpenseIds: <String, dynamic>{'2026-06': 'tx-paid'},
    );
    await repository.saveAppState(initialState, userId: 'user-1');
    controller = AppStateController(repository: repository);
    await controller.loadAuthenticated('user-1');
    service = BackupRestoreService(controller: controller);

    await service.restoreMerge(
      '{"appName":"ZakatApp","appState":{"transactions":[{"id":"tx-incoming","type":"income","date":"2026-06-20","amount":100,"currency":"USD","category":"Salary","description":"incoming","createdAt":"2026-06-20T08:00:00.000Z","rolledOver":false}],"savings":[],"investments":[],"recurringTransactions":[],"financialPlans":[],"zakatPaidMonths":["2026-06"],"processedExpenseIds":["tx-paid"],"zakatExpenseIds":{"2026-06":"tx-paid"}}}',
      allowWhenLocalDataExists: true,
    );

    final AppStateController reloaded = AppStateController(
      repository: AppStateRepository(localStorage: const LocalStorageService()),
    );
    await reloaded.loadAuthenticated('user-1');

    expect(reloaded.state.zakatPaidMonths, <String>['2026-06']);
    expect(reloaded.state.processedExpenseIds, <String>['tx-paid']);
    expect(reloaded.state.zakatExpenseIds, <String, dynamic>{
      '2026-06': 'tx-paid',
    });
  });
}
