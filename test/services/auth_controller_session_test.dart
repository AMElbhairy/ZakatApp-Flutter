import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/core/constants/storage_keys.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';

class _CachedSessionAuthService implements AuthService {
  _CachedSessionAuthService(this.user);

  final UserProfile user;
  int signOutCalls = 0;

  @override
  Future<bool> ensureSession() async => false;

  @override
  Future<UserProfile?> restoreSession() async => user;

  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) async => user;

  @override
  Future<UserProfile?> signInWithEmail({
    required String email,
    required String password,
  }) async => user;

  @override
  Future<UserProfile?> createAccountWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => user;

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<UserProfile?> reloadCurrentUser() async => user;

  @override
  Future<bool> isCurrentUserEmailVerified() async => user.emailVerified;

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }

  @override
  Future<void> deleteAccount() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cached Firebase session is restored for offline startup', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      StorageKeys.userProfileKey:
          '{"id":"user-a","email":"a@example.com","displayName":"User","provider":"google","emailVerified":true,"photoUrl":null,"accessToken":"token"}',
    });
    const UserProfile cachedUser = UserProfile(
      id: 'user-a',
      email: 'a@example.com',
      displayName: 'User',
      provider: 'google',
      emailVerified: true,
      accessToken: 'token',
    );
    final AuthController controller = AuthController(
      authService: _CachedSessionAuthService(cachedUser),
      localStorage: const LocalStorageService(),
    );

    await controller.load();

    expect(controller.currentUser, isNotNull);
    expect(controller.currentUser!.id, cachedUser.id);
    expect(controller.currentUser!.email, cachedUser.email);
    expect(
      await const LocalStorageService().loadString(StorageKeys.userProfileKey),
      isNotNull,
    );
  });

  test(
    'session validation keeps cached user when network check is unavailable',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const UserProfile cachedUser = UserProfile(
        id: 'user-a',
        email: 'a@example.com',
        displayName: 'User',
        provider: 'google',
        emailVerified: true,
        accessToken: 'token',
      );
      final _CachedSessionAuthService service = _CachedSessionAuthService(
        cachedUser,
      );
      final AuthController controller = AuthController(
        authService: service,
        localStorage: const LocalStorageService(),
      );

      await controller.load();
      final bool ok = await controller.ensureSession();

      expect(ok, isTrue);
      expect(controller.currentUser, isNotNull);
      expect(controller.currentUser!.id, cachedUser.id);
      expect(service.signOutCalls, 0);
    },
  );
}
