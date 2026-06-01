import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/services/backup_service.dart';
import 'package:zakatapp_flutter/models/backup_preview.dart';

void main() {
  group('BackupService', () {
    final Map<String, dynamic> mockAppState = <String, dynamic>{
      'transactions': <dynamic>[
        <String, dynamic>{'id': 'tx1', 'amount': 100}
      ],
      'savings': <dynamic>[],
      'investments': <dynamic>[
        <String, dynamic>{'id': 'inv1'}
      ],
      'recurringTransactions': <dynamic>[],
      'financialPlans': <dynamic>[],
      'marketData': <String, dynamic>{'USD_TO_EGP': 50.0},
    };

    test('exportBackup builds correctly shaped JSON', () {
      final String jsonStr = BackupService.exportBackup(mockAppState);
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);

      expect(decoded['appName'], 'ZakatApp');
      expect(decoded['schemaVersion'], 1);
      expect(decoded['exportedAt'], isNotNull);
      expect(decoded['appState'], isNotNull);

      final Map<String, dynamic> counts = decoded['counts'];
      expect(counts['transactions'], 1);
      expect(counts['savings'], 0);
      expect(counts['investments'], 1);
      expect(counts['financialPlans'], 0);
    });

    test('parseBackup parses current Flutter format correctly', () {
      final String jsonStr = BackupService.exportBackup(mockAppState);
      final BackupPreview preview = BackupService.parseBackup(jsonStr);

      expect(preview.isLegacy, isFalse);
      expect(preview.transactionsCount, 1);
      expect(preview.investmentsCount, 1);
      expect(preview.hasMarketData, isTrue);
      expect(preview.totalAssets, 1);
    });

    test('parseBackup successfully handles legacy V2 JSON format', () {
      final String legacyV2 = jsonEncode(<String, dynamic>{
        'schema': 'zakatapp.backup',
        'version': 2,
        'exportedAt': '2023-01-01T00:00:00Z',
        'source': 'zakatapp',
        'data': mockAppState,
      });

      final BackupPreview preview = BackupService.parseBackup(legacyV2);
      
      expect(preview.isLegacy, isTrue);
      expect(preview.version, 2);
      expect(preview.transactionsCount, 1);
      expect(preview.hasMarketData, isTrue);
    });

    test('parseBackup successfully handles legacy V1 JSON format (stringified data)', () {
      final String legacyV1 = jsonEncode(<String, dynamic>{
        'version': 1,
        'exportedAt': '2022-01-01T00:00:00Z',
        'data': jsonEncode(mockAppState),
      });

      final BackupPreview preview = BackupService.parseBackup(legacyV1);
      
      expect(preview.isLegacy, isTrue);
      expect(preview.version, 1);
      expect(preview.transactionsCount, 1);
      expect(preview.hasMarketData, isTrue);
    });

    test('hasData returns true only if items exist', () {
      expect(BackupService.hasData(mockAppState), isTrue);

      final Map<String, dynamic> emptyState = <String, dynamic>{
        'transactions': <dynamic>[],
        'savings': <dynamic>[],
      };

      expect(BackupService.hasData(emptyState), isFalse);
    });
  });
}