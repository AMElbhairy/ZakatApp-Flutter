import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/services/backup_service.dart';

void main() {
  group('BackupService', () {
    final Map<String, dynamic> mockAppState = <String, dynamic>{
      'transactions': <dynamic>[<String, dynamic>{'id': 'tx1', 'amount': 100}],
      'savings': <dynamic>[],
      'investments': <dynamic>[<String, dynamic>{'id': 'inv1'}],
      'recurringTransactions': <dynamic>[],
      'financialPlans': <dynamic>[],
      'marketData': <String, dynamic>{'USD_TO_EGP': 50.0},
    };

    test('export Flutter backup JSON', () {
      final String jsonStr = BackupService.exportBackup(mockAppState);
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      expect(decoded['appName'], 'ZakatApp');
      expect(decoded['schemaVersion'], 1);
      expect(decoded['appState'], isA<Map<String, dynamic>>());
      expect(decoded['counts']['transactions'], 1);
    });

    test('preview Flutter backup', () {
      final String raw = BackupService.exportBackup(mockAppState);
      final preview = BackupService.parseBackupPreview(raw);
      expect(preview.sourceType, 'flutter');
      expect(preview.isLegacy, isFalse);
      expect(preview.transactionsCount, 1);
      expect(preview.canRestore, isTrue);
    });

    test('preview legacy V1 backup', () {
      final String legacyV1 = jsonEncode(<String, dynamic>{
        'version': 1,
        'exportedAt': '2022-01-01T00:00:00Z',
        'data': jsonEncode(mockAppState),
      });

      final preview = BackupService.parseBackupPreview(legacyV1);
      expect(preview.sourceType, 'legacyV1');
      expect(preview.isLegacy, isTrue);
      expect(preview.transactionsCount, 1);
      expect(preview.canRestore, isTrue);
    });

    test('preview legacy V2 backup', () {
      final String legacyV2 = jsonEncode(<String, dynamic>{
        'schema': 'zakatapp.backup',
        'version': 2,
        'exportedAt': '2023-01-01T00:00:00Z',
        'data': mockAppState,
      });

      final preview = BackupService.parseBackupPreview(legacyV2);
      expect(preview.sourceType, 'legacyV2');
      expect(preview.isLegacy, isTrue);
      expect(preview.transactionsCount, 1);
      expect(preview.canRestore, isTrue);
    });

    test('invalid JSON rejected', () {
      final preview = BackupService.parseBackupPreview('{bad');
      expect(preview.canRestore, isFalse);
      expect(preview.warnings, isNotEmpty);
    });
  });
}
