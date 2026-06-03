import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/models/transaction.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/cloud_backup_controller.dart';
import 'package:zakatapp_flutter/services/google_drive_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _FakeAuthService implements AuthService {
  @override
  Future<bool> ensureSession() async => true;

  _FakeAuthService({this.user});

  final UserProfile? user;

  @override
  Future<UserProfile?> restoreSession() async => user;

  @override
  Future<UserProfile?> signIn() async => user;

  @override
  Future<void> signOut() async {}
}

class _FakeGoogleDriveService extends GoogleDriveService {
  _FakeGoogleDriveService({this.latest});

  DriveBackupFile? latest;
  String? uploadedJson;
  int uploadCalls = 0;

  @override
  Future<DriveBackupFile?> fetchLatestBackup(String accessToken) async =>
      latest;

  @override
  Future<DriveBackupFile?> uploadBackup({
    required String jsonString,
    required String accessToken,
  }) async {
    uploadCalls += 1;
    uploadedJson = jsonString;
    latest = DriveBackupFile(
      id: 'backup-1',
      name: GoogleDriveService.backupFileName,
      rawJson: jsonString,
      backupCreatedAt: DateTime.parse(
        (jsonDecode(jsonString)
                as Map<String, dynamic>)['cloudBackupMetadata']['createdAt']
            as String,
      ).toUtc(),
      backupUpdatedAt: DateTime.parse(
        (jsonDecode(jsonString)
                as Map<String, dynamic>)['cloudBackupMetadata']['updatedAt']
            as String,
      ).toUtc(),
    );
    return latest;
  }

  @override
  Future<String?> downloadBackupContent({
    required String accessToken,
    required String fileId,
  }) async {
    return latest?.rawJson;
  }
}

Transaction _tx(String id) {
  return Transaction(
    id: id,
    type: 'income',
    date: '2026-06-02',
    amount: 100,
    currency: 'EGP',
    category: 'Salary',
    description: '',
    createdAt: DateTime.now().toUtc().toIso8601String(),
    rolledOver: false,
  );
}

Future<
  ({
    AppStateController appState,
    AuthController auth,
    CloudBackupController cloud,
  })
>
_buildControllers({
  required _FakeGoogleDriveService driveService,
  UserProfile? user,
  Duration? autoBackupDelay,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  const LocalStorageService localStorage = LocalStorageService();
  final AppStateController appState = AppStateController(
    repository: AppStateRepository(localStorage: localStorage),
  );
  await appState.load();
  final AuthController auth = AuthController(
    authService: _FakeAuthService(user: user),
    localStorage: localStorage,
  );
  final CloudBackupController cloud = CloudBackupController(
    appStateController: appState,
    authController: auth,
    googleDriveService: driveService,
    autoBackupDelay: autoBackupDelay,
  );
  return (appState: appState, auth: auth, cloud: cloud);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default auto-backup debounce is 3 minutes', () async {
    final _FakeGoogleDriveService driveService = _FakeGoogleDriveService();
    final controllers = await _buildControllers(driveService: driveService);

    expect(controllers.cloud.autoBackupDelay, const Duration(minutes: 3));
  });

  test('backup JSON generation includes cloud metadata', () async {
    final _FakeGoogleDriveService driveService = _FakeGoogleDriveService();
    final UserProfile user = const UserProfile(
      id: 'u1',
      email: 'a@example.com',
      name: 'User',
      accessToken: 'token',
    );
    final controllers = await _buildControllers(
      driveService: driveService,
      user: user,
    );

    await controllers.auth.signIn();
    await controllers.appState.addTransaction(_tx('tx1'));
    final bool ok = await controllers.cloud.backupNow();

    debugPrint(
      'ok: $ok, err: ${controllers.cloud.lastError}, status: ${controllers.cloud.statusMessage}',
    );
    expect(ok, isTrue);
    final Map<String, dynamic> payload =
        jsonDecode(driveService.uploadedJson!) as Map<String, dynamic>;
    expect(payload['appState']['transactions'], isNotEmpty);
    expect(payload['cloudBackupMetadata']['backupVersion'], 1);
    expect(payload['cloudBackupMetadata']['devicePlatform'], isNotEmpty);
    expect(payload['cloudBackupMetadata']['appVersion'], isNotEmpty);
  });

  test('restore into app state applies latest cloud backup', () async {
    final String rawJson = jsonEncode(<String, dynamic>{
      'appName': 'ZakatApp',
      'schemaVersion': 1,
      'exportedAt': '2026-06-02T00:00:00.000Z',
      'counts': <String, int>{'transactions': 1},
      'appState': <String, dynamic>{
        ...AppStateDefaults.create().toJson(),
        'transactions': <Map<String, dynamic>>[_tx('restored').toJson()],
        'lastModifiedAt': '2026-06-02T00:00:00.000Z',
      },
      'cloudBackupMetadata': <String, dynamic>{
        'backupVersion': 1,
        'createdAt': '2026-06-01T00:00:00.000Z',
        'updatedAt': '2026-06-02T00:00:00.000Z',
      },
    });
    final _FakeGoogleDriveService driveService = _FakeGoogleDriveService(
      latest: DriveBackupFile(
        id: 'backup-1',
        name: GoogleDriveService.backupFileName,
        rawJson: rawJson,
        backupUpdatedAt: DateTime.parse('2026-06-02T00:00:00.000Z'),
      ),
    );
    final UserProfile user = const UserProfile(
      id: 'u1',
      email: 'a@example.com',
      name: 'User',
      accessToken: 'token',
    );
    final controllers = await _buildControllers(
      driveService: driveService,
      user: user,
    );

    await controllers.auth.signIn();
    await controllers.cloud.refreshCloudState();
    final bool ok = await controllers.cloud.restoreLatestBackup();

    debugPrint(
      'ok: $ok, err: ${controllers.cloud.lastError}, status: ${controllers.cloud.statusMessage}',
    );
    expect(ok, isTrue);
    expect(controllers.appState.state.transactions, hasLength(1));
    expect(controllers.appState.state.transactions.first.id, 'restored');
  });

  test('empty local state triggers restore prompt after sign-in', () async {
    final _FakeGoogleDriveService driveService = _FakeGoogleDriveService(
      latest: DriveBackupFile(
        id: 'backup-1',
        name: GoogleDriveService.backupFileName,
        rawJson: '{}',
        backupUpdatedAt: DateTime.parse('2026-06-02T00:00:00.000Z'),
      ),
    );
    final UserProfile user = const UserProfile(
      id: 'u1',
      email: 'a@example.com',
      name: 'User',
      accessToken: 'token',
    );
    final controllers = await _buildControllers(
      driveService: driveService,
      user: user,
    );

    await controllers.auth.signIn();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controllers.cloud.shouldPromptRestore, isTrue);
  });

  test('non-empty local state does not auto-overwrite on sign-in', () async {
    final _FakeGoogleDriveService driveService = _FakeGoogleDriveService(
      latest: DriveBackupFile(
        id: 'backup-1',
        name: GoogleDriveService.backupFileName,
        rawJson: '{}',
        backupUpdatedAt: DateTime.parse('2026-06-02T00:00:00.000Z'),
      ),
    );
    final UserProfile user = const UserProfile(
      id: 'u1',
      email: 'a@example.com',
      name: 'User',
      accessToken: 'token',
    );
    final controllers = await _buildControllers(
      driveService: driveService,
      user: user,
    );
    await controllers.appState.addTransaction(_tx('local'));

    await controllers.auth.signIn();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controllers.cloud.shouldPromptRestore, isFalse);
    expect(controllers.appState.state.transactions.first.id, 'local');
  });

  test('auto-backup debounce batches rapid local changes', () async {
    final _FakeGoogleDriveService driveService = _FakeGoogleDriveService();
    final UserProfile user = const UserProfile(
      id: 'u1',
      email: 'a@example.com',
      name: 'User',
      accessToken: 'token',
    );
    final controllers = await _buildControllers(
      driveService: driveService,
      user: user,
      autoBackupDelay: const Duration(milliseconds: 20),
    );

    await controllers.auth.signIn();
    await controllers.appState.addTransaction(_tx('tx1'));
    await controllers.appState.addTransaction(_tx('tx2'));
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(driveService.uploadCalls, 1);
  });

  test(
    'background pause uploads immediately when pending changes exist',
    () async {
      final _FakeGoogleDriveService driveService = _FakeGoogleDriveService();
      final UserProfile user = const UserProfile(
        id: 'u1',
        email: 'a@example.com',
        name: 'User',
        accessToken: 'token',
      );
      final controllers = await _buildControllers(
        driveService: driveService,
        user: user,
        autoBackupDelay: const Duration(minutes: 3),
      );

      await controllers.auth.signIn();
      await controllers.appState.addTransaction(_tx('tx1'));

      expect(controllers.cloud.hasPendingAutoBackup, isTrue);
      expect(driveService.uploadCalls, 0);

      controllers.cloud.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(driveService.uploadCalls, 1);
      expect(controllers.cloud.hasPendingAutoBackup, isFalse);
    },
  );
}
