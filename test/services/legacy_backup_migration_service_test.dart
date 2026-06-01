import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
            <String, dynamic>{'id': 'a', 'date': '2024-01-01'}
          ],
          'savings': <dynamic>[],
          'investments': <dynamic>[],
          'recurringTransactions': <dynamic>[],
          'financialPlans': <dynamic>[],
        },
      });
      final Map<String, dynamic> migrated = service.parseAndMigrate(raw);
      final String createdAt = (migrated['transactions'] as List<dynamic>).first['createdAt'] as String;
      expect(createdAt, isNotEmpty);
      expect(DateTime.tryParse(createdAt), isNotNull);
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
                'context': <String, dynamic>{'k': 'v'}
              }
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
          (migrated['financialPlans'] as List<dynamic>).first['context'] as Map<String, dynamic>;
      expect(context['k'], 'v');
      expect(migrated.containsKey('syncHealth'), isFalse);
      expect(report.unsupportedFields, contains('syncHealth'));
    });
  });
}
