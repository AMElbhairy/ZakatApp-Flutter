import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/backup_preview.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/services/backup_service.dart';
import 'package:zakatapp_flutter/services/local_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('local_backup_service_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  AppStateModel _buildState({required String transactionId}) {
    return AppStateModel.fromJson(<String, dynamic>{
      'transactions': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': transactionId,
          'type': 'income',
          'date': '2026-08-26',
          'amount': 100,
          'currency': 'EGP',
          'category': 'Salary',
          'description': 'Salary',
          'createdAt': '2026-08-26T00:00:00Z',
          'rolledOver': false,
        },
      ],
      'userId': 'user-1',
      'email': 'user@example.com',
      'displayName': 'User',
      'provider': 'google',
    });
  }

  test('captures per-user backups and keeps only the newest five', () async {
    final LocalBackupService service = LocalBackupService(
      enableInTesting: true,
      documentsDirectoryProvider: () async => tempDir,
    );

    for (int index = 0; index < 6; index++) {
      await service.captureSnapshot(
        state: _buildState(transactionId: 'tx-$index'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }

    final Directory userDir = Directory(
      p.join(tempDir.path, 'local_backups', 'user-1'),
    );
    final List<FileSystemEntity> files = await userDir
        .list(followLinks: false)
        .toList();
    final List<File> backups = files.whereType<File>().toList(growable: false);
    expect(backups, hasLength(5));

    final String? latestRaw = await service.readLatestBackup(userId: 'user-1');
    expect(latestRaw, isNotNull);
    final BackupPreview preview = BackupService.parseBackupPreview(latestRaw!);
    expect(preview.transactionsCount, equals(1));
    expect(preview.backupUserId, equals('user-1'));
  });
}
