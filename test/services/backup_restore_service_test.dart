import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/models/market_snapshot.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/backup_restore_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

void main() {
  late AppStateController controller;
  late BackupRestoreService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService storage = LocalStorageService();
    final AppStateRepository repo = AppStateRepository(localStorage: storage);
    controller = AppStateController(repository: repo);
    await controller.load();
    service = BackupRestoreService(controller: controller);
  });

  test('replace restore persists state', () async {
    final String raw = jsonEncode(<String, dynamic>{
      'appName': 'ZakatApp',
      'schemaVersion': 1,
      'exportedAt': '2026-01-01T00:00:00Z',
      'counts': <String, dynamic>{},
      'appState': <String, dynamic>{
        'transactions': <dynamic>[<String, dynamic>{'id': 'tx1', 'date': '2026-01-01'}],
        'savings': <dynamic>[],
        'investments': <dynamic>[],
        'recurringTransactions': <dynamic>[],
        'financialPlans': <dynamic>[],
      },
    });

    await service.restoreReplace(raw, allowWhenLocalDataExists: true);
    expect(controller.state.transactions.length, 1);
    expect(controller.state.transactions.first.id, 'tx1');
  });

  test('merge restore upserts by id', () async {
    await service.restoreReplace(
      jsonEncode(<String, dynamic>{
        'appName': 'ZakatApp',
        'appState': <String, dynamic>{
          'transactions': <dynamic>[<String, dynamic>{'id': 'tx1', 'description': 'old'}],
          'savings': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
        },
      }),
      allowWhenLocalDataExists: true,
    );

    await service.restoreMerge(
      jsonEncode(<String, dynamic>{
        'appName': 'ZakatApp',
        'appState': <String, dynamic>{
          'transactions': <dynamic>[
            <String, dynamic>{'id': 'tx1', 'description': 'new'},
            <String, dynamic>{'id': 'tx2', 'description': 'second'}
          ],
          'savings': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
        },
      }),
      allowWhenLocalDataExists: true,
    );

    expect(controller.state.transactions.length, 2);
    expect(
      controller.state.transactions.firstWhere((e) => e.id == 'tx1').description,
      'new',
    );
  });

  test('local conflict requires explicit action', () async {
    await service.restoreReplace(
      jsonEncode(<String, dynamic>{
        'appName': 'ZakatApp',
        'appState': <String, dynamic>{
          'transactions': <dynamic>[<String, dynamic>{'id': 'tx1'}],
          'savings': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
        },
      }),
      allowWhenLocalDataExists: true,
    );

    expect(
      () => service.restoreMerge(
        jsonEncode(<String, dynamic>{
          'appName': 'ZakatApp',
          'appState': <String, dynamic>{
            'transactions': <dynamic>[<String, dynamic>{'id': 'tx2'}],
            'savings': <dynamic>[],
            'investments': <dynamic>[],
            'recurringTransactions': <dynamic>[],
            'financialPlans': <dynamic>[],
          },
        }),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('merge restore keeps existing market data when incoming market data is empty', () async {
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
      jsonEncode(<String, dynamic>{
        'appName': 'ZakatApp',
        'appState': <String, dynamic>{
          'transactions': <dynamic>[],
          'savings': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
          'marketData': <String, dynamic>{},
        },
      }),
      allowWhenLocalDataExists: true,
    );

    expect(controller.currentMarketSnapshot.usdToEgp, 50);
    expect(controller.currentMarketSnapshot.lastUpdated, '2026-01-01T00:00:00Z');
  });
}
