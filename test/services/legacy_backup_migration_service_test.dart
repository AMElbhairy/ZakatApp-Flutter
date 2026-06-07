import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/core/services/zakat_engine.dart';
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/services/legacy_backup_migration_service.dart';

void main() {
  group('LegacyBackupMigrationService', () {
    final LegacyBackupMigrationService service = LegacyBackupMigrationService();

    test('legacy V1 stringified data unwrap', () {
      final String raw = jsonEncode(<String, dynamic>{
        'version': 1,
        'exportedAt': '2024-01-01T00:00:00Z',
        'data': jsonEncode(<String, dynamic>{
          'transactions': <dynamic>[],
          'savings': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
        }),
      });
      final Map<String, dynamic> migrated = service.parseAndMigrate(raw);
      expect(migrated['transactions'], isA<List<dynamic>>());
    });

    test('saving normalization and buggy cash filter', () {
      final String raw = jsonEncode(<String, dynamic>{
        'version': 1,
        'data': jsonEncode(<String, dynamic>{
          'mainCurrency': 'EGP',
          'transactions': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
          'savings': <dynamic>[
            <String, dynamic>{
              'assetType': 'Gold',
              'unit': '24K',
              'amount': 100,
              'dateAcquired': '2024-01-10',
            },
            <String, dynamic>{
              'assetType': 'cash',
              'unit': 'EGP',
              'description': 'Auto-transfer from monthly surplus',
              'amount': 50,
              'dateAcquired': '2024-01-11',
            },
          ],
        }),
      });

      final Map<String, dynamic> migrated = service.parseAndMigrate(raw);
      final List<dynamic> savings = migrated['savings'] as List<dynamic>;
      expect(savings.length, 1);
      expect(savings.first['assetType'], 'gold');
      expect(savings.first['unit'], '24');
      expect(savings.first['remainingAmount'], 100);
    });

    test('createdAt deterministic fallback', () {
      final String raw = jsonEncode(<String, dynamic>{
        'schema': 'zakatapp.backup',
        'version': 2,
        'data': <String, dynamic>{
          'transactions': <dynamic>[
            <String, dynamic>{'id': 'a', 'date': '2024-01-01'},
          ],
          'savings': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
        },
      });
      final Map<String, dynamic> migrated = service.parseAndMigrate(raw);
      final String createdAt =
          (migrated['transactions'] as List<dynamic>).first['createdAt']
              as String;
      expect(createdAt, isNotEmpty);
      expect(DateTime.tryParse(createdAt), isNotNull);
    });

    test('legacy income aliases normalize into cash income lots', () {
      final String raw = jsonEncode(<String, dynamic>{
        'schema': 'zakatapp.backup',
        'version': 2,
        'data': <String, dynamic>{
          'transactions': <dynamic>[
            <String, dynamic>{
              'id': 'legacy_income',
              'transactionType': 'cash_in',
              'value': '1500',
              'unit': 'egp',
              'transactionDate': '2025-03-01T12:00:00.000Z',
              'source': 'Legacy Salary',
            },
          ],
          'savings': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
          'marketData': <String, dynamic>{},
        },
      });

      final Map<String, dynamic> migrated = service.parseAndMigrate(raw);
      final AppStateModel state = AppStateModel.fromJson(migrated);
      final List<Map<String, dynamic>> lots =
          ZakatEngineService.getNetIncomeLots(
            transactions: state.transactions,
            marketData: MarketData.fromJson(state.marketData),
          );

      expect(state.transactions.single.type, 'income');
      expect(state.transactions.single.amount, 1500);
      expect(state.transactions.single.currency, 'EGP');
      expect(state.transactions.single.date, '2025-03-01');
      expect(lots, hasLength(1));
      expect(lots.single['remainingAmount'], 1500);
      expect(lots.single['currency'], 'EGP');
    });

    test('legacy cash savings and recurring transactions normalize', () {
      final String raw = jsonEncode(<String, dynamic>{
        'schema': 'zakatapp.backup',
        'version': 2,
        'data': <String, dynamic>{
          'mainCurrency': 'EGP',
          'transactions': <dynamic>[],
          'savings': <dynamic>[
            <String, dynamic>{
              'id': 'cash_usd',
              'assetType': 'Cash & Currencies',
              'date': '2026-02-25T12:00:00.000Z',
              'amount': 100,
              'remainingAmount': 40,
              'unit': 'usd',
              'sourceIncomeId': 'income_1',
            },
          ],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[
            <String, dynamic>{
              'id': 'rec_salary',
              'name': 'Salary',
              'type': 'cash_in',
              'amount': '37500',
              'unit': 'sar',
              'category': 'Salary',
              'dayOfMonth': 25,
              'enabled': true,
            },
          ],
          'financialPlans': <dynamic>[],
        },
      });

      final Map<String, dynamic> migrated = service.parseAndMigrate(raw);
      final Map<String, dynamic> saving =
          (migrated['savings'] as List<dynamic>).single as Map<String, dynamic>;
      final Map<String, dynamic> recurring =
          (migrated['recurringTransactions'] as List<dynamic>).single
              as Map<String, dynamic>;

      expect(saving['assetType'], 'cash');
      expect(saving['dateAcquired'], '2026-02-25');
      expect(saving['unit'], 'USD');
      expect(saving['purchaseCurrency'], 'USD');
      expect(saving['sourceIncomeId'], 'income_1');
      expect(recurring['type'], 'income');
      expect(recurring['currency'], 'SAR');
      expect(recurring['frequency'], 'monthly');
    });

    test('legacy investment installments preserve recurrence due dates', () {
      final String raw = jsonEncode(<String, dynamic>{
        'schema': 'zakatapp.backup',
        'version': 2,
        'data': <String, dynamic>{
          'transactions': <dynamic>[],
          'savings': <dynamic>[],
          'investments': <dynamic>[
            <String, dynamic>{
              'id': 'asset_1',
              'description': 'Hacienda',
              'investmentType': 'real_estate',
              'ownershipType': 'installment',
              'currency': 'EGP',
              'totalPayable': 1000,
              'paidAmount': 100,
              'installmentPlan': jsonEncode(<Map<String, dynamic>>[
                <String, dynamic>{
                  'amount': '250',
                  'currency': 'EGP',
                  'recurrenceDate': '2026-07-28',
                  'isPaid': 'false',
                },
              ]),
            },
          ],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
        },
      });

      final Map<String, dynamic> migrated = service.parseAndMigrate(raw);
      final Map<String, dynamic> investment =
          (migrated['investments'] as List<dynamic>).single
              as Map<String, dynamic>;
      final Map<String, dynamic> installment =
          (investment['installmentPlan'] as List<dynamic>).single
              as Map<String, dynamic>;

      expect(investment['remainingAmount'], 900);
      expect(investment['loanBalance'], 900);
      expect(installment['amount'], 250);
      expect(installment['recurrenceDate'], '2026-07-28');
      expect(installment['date'], '2026-07-28');
      expect(installment['isPaid'], isFalse);
    });

    test('financialPlan.context preserved and unsupported fields dropped', () {
      final LegacyMigrationReport report = service.parseAndMigrateWithReport(
        jsonEncode(<String, dynamic>{
          'appName': 'ZakatApp',
          'appState': <String, dynamic>{
            'transactions': <dynamic>[],
            'savings': <dynamic>[],
            'investments': <dynamic>[],
            'recurringTransactions': <dynamic>[],
            'financialPlans': <dynamic>[
              <String, dynamic>{
                'id': 'fp1',
                'startDate': '2024-01-01',
                'context': <String, dynamic>{'k': 'v'},
              },
            ],
            'syncHealth': <String, dynamic>{'x': 1},
            'aiSettings': <String, dynamic>{'x': 1},
            'lastRollover': 'x',
            'marketHistory': <dynamic>[],
          },
        }),
      );

      final Map<String, dynamic> migrated = report.state;
      final Map<String, dynamic> context =
          (migrated['financialPlans'] as List<dynamic>).first['context']
              as Map<String, dynamic>;
      expect(context['k'], 'v');
      expect(migrated.containsKey('syncHealth'), isFalse);
      expect(report.unsupportedFields, contains('syncHealth'));
    });
  });
}
