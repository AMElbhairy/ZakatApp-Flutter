import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
}
