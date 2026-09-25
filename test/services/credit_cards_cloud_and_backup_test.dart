import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart';
import 'package:zakatapp_flutter/data/local/daos/app_settings_dao.dart';
import 'package:zakatapp_flutter/data/local/local_store_providers.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/backup_preview.dart';
import 'package:zakatapp_flutter/models/credit_card.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/backup_integrity_summary.dart';
import 'package:zakatapp_flutter/services/backup_service.dart';
import 'package:zakatapp_flutter/services/legacy_backup_migration_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _AlwaysSqliteProvider implements UseSqliteLocalStoreProvider {
  @override
  Future<bool> prepareForRead({String? userId}) async => true;
}

const CreditCard _card = CreditCard(
  id: 'card-1',
  bankName: 'ANB',
  cardNickname: 'Primary',
  network: CreditCardNetwork.visa,
  last4Digits: '1234',
  creditLimit: 10000,
  currency: 'SAR',
  openingBalance: 1250,
);

void main() {
  test('exportBackup includes credit cards and preview parses their count', () {
    final String raw = BackupService.exportBackup(
      <String, dynamic>{
        'creditCards': <Map<String, dynamic>>[_card.toJson()],
        'transactions': <dynamic>[],
        'savings': <dynamic>[],
        'investments': <dynamic>[],
        'recurringTransactions': <dynamic>[],
        'financialPlans': <dynamic>[],
        'marketData': <String, dynamic>{},
      },
      userId: 'user-1',
      provider: 'google',
      email: 'user@example.com',
    );

    final Map<String, dynamic> decoded =
        jsonDecode(raw) as Map<String, dynamic>;
    expect((decoded['appState'] as Map)['creditCards'], hasLength(1));
    expect((decoded['counts'] as Map)['creditCards'], 1);
    final BackupPreview preview = BackupService.parseBackupPreview(raw);
    expect(preview.creditCardsCount, 1);
    expect(
      BackupService.hasData(<String, dynamic>{
        'creditCards': [_card.toJson()],
      }),
      isTrue,
    );
  });

  test('legacy migration repairs and normalizes credit cards', () {
    final String raw = jsonEncode(<String, dynamic>{
      'schema': 'zakatapp.backup',
      'version': 2,
      'data': <String, dynamic>{
        'creditCards': <Map<String, dynamic>>[
          <String, dynamic>{
            'bank': 'Legacy Bank',
            'cardNetwork': 'VISA',
            'last4': 'xx9876',
            'creditLimit': '-500',
            'currentBalanceOwed': '100',
            'currency': '',
          },
        ],
      },
    });

    final LegacyMigrationReport report = LegacyBackupMigrationService()
        .parseAndMigrateWithReport(raw);
    final Map<String, dynamic> card =
        (report.state['creditCards'] as List).single as Map<String, dynamic>;
    expect(card['id'], 'card_0');
    expect(card['bankName'], 'Legacy Bank');
    expect(card['network'], 'visa');
    expect(card['last4Digits'], '9876');
    expect(card['creditLimit'], 0);
    expect(card['currency'], 'EGP');
    expect(report.warnings, isNotEmpty);
  });

  test(
    'credit cards are mirrored to and hydrated from SQLite settings',
    () async {
      final AppDatabase database = AppDatabase(
        executor: NativeDatabase.memory(),
      );
      addTearDown(database.close);
      final AppStateModel withCard = AppStateDefaults.create().copyWith(
        creditCards: const <CreditCard>[_card],
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'zakatAppData': jsonEncode(withCard.toJson()),
      });
      final AppStateController first = AppStateController(
        repository: AppStateRepository(
          localStorage: const LocalStorageService(),
        ),
        database: database,
        useSqliteLocalStoreProvider: _AlwaysSqliteProvider(),
        enableBackgroundSync: false,
        enableMarketAutoRefresh: false,
      );
      await first.load();
      expect(
        await AppSettingsDao(database).getJson<List<dynamic>>('credit_cards'),
        hasLength(1),
      );

      final AppStateModel emptyCards = withCard.copyWith(
        creditCards: const <CreditCard>[],
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'zakatAppData': jsonEncode(emptyCards.toJson()),
      });
      final AppStateController second = AppStateController(
        repository: AppStateRepository(
          localStorage: const LocalStorageService(),
        ),
        database: database,
        useSqliteLocalStoreProvider: _AlwaysSqliteProvider(),
        enableBackgroundSync: false,
        enableMarketAutoRefresh: false,
      );
      await second.load();
      expect(second.state.creditCards.single.id, _card.id);
    },
  );

  test('integrity summary includes credit-card count in its signature', () {
    final BackupIntegritySummary summary = BackupIntegritySummary.fromState(
      AppStateDefaults.create().copyWith(
        creditCards: const <CreditCard>[_card],
      ),
    );
    expect(summary.collectionCounts['credit_cards'], 1);
    expect(summary.signature, contains('credit_cards'));
  });
}
