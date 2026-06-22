import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/constants/storage_keys.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _StaleSessionAuthService implements AuthService {
  @override
  Future<bool> ensureSession() async => false;

  @override
  Future<UserProfile?> restoreSession() async => null;

  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) async => null;

  @override
  Future<UserProfile?> signInWithEmail({
    required String email,
    required String password,
  }) async => null;

  @override
  Future<UserProfile?> createAccountWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => null;

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<UserProfile?> reloadCurrentUser() async => null;

  @override
  Future<bool> isCurrentUserEmailVerified() async => false;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'stale persisted auth is cleared when the Firebase session is gone',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        StorageKeys.userProfileKey:
            '{"id":"user-a","email":"a@example.com","displayName":"User","provider":"google","emailVerified":true,"photoUrl":null,"accessToken":"token"}',
      });
      final AuthController controller = AuthController(
        authService: _StaleSessionAuthService(),
        localStorage: const LocalStorageService(),
      );

      await controller.load();

      expect(controller.currentUser, isNull);
      expect(
        await const LocalStorageService().loadString(
          StorageKeys.userProfileKey,
        ),
        isNull,
      );
    },
  );
}
