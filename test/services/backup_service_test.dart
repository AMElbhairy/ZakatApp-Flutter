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

    test('parseBackupPreview parses current Flutter format correctly', () {
      final String jsonStr = BackupService.exportBackup(mockAppState);
      final BackupPreview preview = BackupService.parseBackupPreview(jsonStr);

      expect(preview.isLegacy, isFalse);
      expect(preview.sourceType, 'flutter');
      expect(preview.transactionsCount, 1);
      expect(preview.investmentsCount, 1);
      expect(preview.hasMarketData, isTrue);
      expect(preview.savingsCount + preview.investmentsCount, 1);
    });

    test('parseBackupPreview successfully handles legacy V2 JSON format', () {
      final String legacyV2 = jsonEncode(<String, dynamic>{
        'schema': 'zakatapp.backup',
        'version': 2,
        'exportedAt': '2023-01-01T00:00:00Z',
        'source': 'zakatapp',
        'data': mockAppState,
      });

      final BackupPreview preview = BackupService.parseBackupPreview(legacyV2);
      
      expect(preview.isLegacy, isTrue);
      expect(preview.sourceType, 'legacyV2');
      expect(preview.schemaOrVersion, contains('version=2'));
      expect(preview.transactionsCount, 1);
      expect(preview.hasMarketData, isTrue);
    });

    test('parseBackupPreview successfully handles legacy V1 JSON format (stringified data)', () {
      final String legacyV1 = jsonEncode(<String, dynamic>{
        'version': 1,
        'exportedAt': '2022-01-01T00:00:00Z',
        'data': jsonEncode(mockAppState),
      });

      final BackupPreview preview = BackupService.parseBackupPreview(legacyV1);
      
      expect(preview.isLegacy, isTrue);
      expect(preview.sourceType, 'legacyV1');
      expect(preview.schemaOrVersion, 'version=1');
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

    test('export and parse roundtrip preserves identical data (No Silent Overwrite/Loss)', () {
      // 1. Export the mock state
      final String exportedJson = BackupService.exportBackup(mockAppState);
      
      // 2. Parse it back via the preview parser
      final BackupPreview preview = BackupService.parseBackupPreview(exportedJson);
      expect(preview.transactionsCount, 1);
      expect(preview.investmentsCount, 1);
      
      // 3. Extract the exact AppState
      final Map<String, dynamic> restoredState = BackupService.extractRawState(preview.rawJson);
      
      // 4. Verify nested structure is perfectly preserved
      expect(restoredState['transactions'][0]['id'], 'tx1');
      expect(restoredState['transactions'][0]['amount'], 100);
      expect(restoredState['investments'][0]['id'], 'inv1');
      expect(restoredState['marketData']['USD_TO_EGP'], 50.0);
      
      // Ensure arrays that were empty remained empty, not null
      expect(restoredState['savings'], isEmpty);
    });
  });
}
