import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/cloud_backup_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.user});

  final UserProfile? user;

  @override
  Future<bool> ensureSession() async => true;

  @override
  Future<UserProfile?> restoreSession() async => user;

  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) async => user;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<
  ({
    AppStateController appState,
    AuthController auth,
    CloudBackupController cloud,
  })
>
_buildControllers({UserProfile? user}) async {
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
  );
  return (appState: appState, auth: auth, cloud: cloud);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cloud sync controller reports active status for signed-in users',
    () async {
      final UserProfile user = const UserProfile(
        id: 'u1',
        email: 'a@example.com',
        displayName: 'User',
        provider: 'google',
        accessToken: 'token',
      );
      final controllers = await _buildControllers(user: user);

      await controllers.auth.signIn();
      await controllers.cloud.refreshCloudState();

      expect(controllers.cloud.statusMessage, 'Cloud Sync: Active');
      expect(controllers.cloud.hasCloudBackup, isFalse);
      expect(controllers.cloud.shouldPromptRestore, isFalse);
    },
  );

  test('cloud sync controller no longer performs manual backups', () async {
    final UserProfile user = const UserProfile(
      id: 'u1',
      email: 'a@example.com',
      displayName: 'User',
      provider: 'google',
      accessToken: 'token',
    );
    final controllers = await _buildControllers(user: user);

    await controllers.auth.signIn();
    final bool ok = await controllers.cloud.backupNow();
    final backup = await controllers.cloud.previewLatestBackup();

    expect(ok, isFalse);
    expect(backup, isNull);
  });
}
