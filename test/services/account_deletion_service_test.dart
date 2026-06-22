import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/features/auth/auth_service.dart' as auth;
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/account_deletion_auth_backend.dart';
import 'package:zakatapp_flutter/services/account_deletion_service.dart';
import 'package:zakatapp_flutter/services/account_reauthentication_service.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';

class _RecordingAuthService implements auth.AuthService {
  _RecordingAuthService({required this.user, required this.callOrder});

  final UserProfile user;
  final List<String> callOrder;

  @override
  Future<UserProfile?> restoreSession() async => user;

  @override
  Future<void> signOut() async {
    callOrder.add('authController.signOut');
  }

  @override
  Future<bool> ensureSession() async => true;

  @override
  Future<UserProfile?> signIn({
    auth.AuthProvider provider = auth.AuthProvider.google,
  }) async {
    fail('normal sign-in must not be used for reauthentication');
  }

  @override
  Future<UserProfile?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    fail('normal sign-in must not be used for reauthentication');
  }

  @override
  Future<UserProfile?> createAccountWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<UserProfile?> reloadCurrentUser() async => user;

  @override
  Future<bool> isCurrentUserEmailVerified() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingAuthBackend implements AccountDeletionAuthBackend {
  _RecordingAuthBackend({
    required this.uid,
    required this.email,
    required this.providerIds,
    required this.callOrder,
    this.throwRecentLoginOnFirstDeleteOnce = false,
    this.onReauth,
    this.onDelete,
  });

  @override
  final String? uid;
  @override
  final String? email;
  @override
  final List<String> providerIds;
  final List<String> callOrder;
  final bool throwRecentLoginOnFirstDeleteOnce;
  final Future<void> Function()? onReauth;
  final Future<void> Function()? onDelete;

  bool _threwRecentLoginOnce = false;
  int deleteAttempts = 0;
  String? lastCredentialProviderId;

  @override
  bool get hasCurrentUser => uid != null && uid!.isNotEmpty;

  @override
  Future<void> deleteAccount() async {
    callOrder.add('authDelete');
    deleteAttempts += 1;
    if (onDelete != null) {
      await onDelete!();
    }
    if (throwRecentLoginOnFirstDeleteOnce && !_threwRecentLoginOnce) {
      _threwRecentLoginOnce = true;
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'Recent login required.',
      );
    }
  }

  @override
  Future<void> reauthenticateWithCredential(AuthCredential credential) async {
    callOrder.add('reauth:${credential.providerId}');
    lastCredentialProviderId = credential.providerId;
    if (onReauth != null) {
      await onReauth!();
    }
  }

  @override
  Future<void> signOut() async {}
}

class _RecordingAppStateController extends AppStateController {
  _RecordingAppStateController({
    required super.repository,
    required this.callOrder,
    this.failCloudDelete = false,
    this.failLocalDelete = false,
  }) : super(
         enableBackgroundSync: false,
         enableMarketAutoRefresh: false,
         marketDataApiService: _NoopMarketDataApiService(),
       );

  final List<String> callOrder;
  final bool failCloudDelete;
  final bool failLocalDelete;

  @override
  Future<void> deleteCloudDataForUser({required String userId}) async {
    callOrder.add('cloudDelete');
    if (failCloudDelete) {
      throw StateError('cloud delete failed');
    }
  }

  @override
  Future<void> deleteLocalDataForUser({required String userId}) async {
    callOrder.add('localDelete');
    if (failLocalDelete) {
      throw StateError('local delete failed');
    }
  }
}

class _NoopMarketDataApiService implements MarketDataApiService {
  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async => null;

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async =>
      null;

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async =>
      null;
}

void main() {
  late List<String> callOrder;
  late AppStateRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    callOrder = <String>[];
    repository = AppStateRepository(localStorage: const LocalStorageService());
  });

  Future<AuthController> buildAuthController(UserProfile user) async {
    final AuthController controller = AuthController(
      authService: _RecordingAuthService(user: user, callOrder: callOrder),
      localStorage: const LocalStorageService(),
    );
    await controller.load();
    return controller;
  }

  AccountDeletionService buildService({
    required AuthController authController,
    required _RecordingAuthBackend authBackend,
    required Future<String?> Function(UserProfile user) promptPassword,
    required Future<AccountReauthMethod?> Function({
      required List<AccountReauthMethod> availableMethods,
    }) chooseMethod,
    GoogleReauthFlow? googleReauthFlow,
    bool failCloudDelete = false,
    bool failLocalDelete = false,
  }) {
    final _RecordingAppStateController appStateController =
        _RecordingAppStateController(
      repository: repository,
      callOrder: callOrder,
      failCloudDelete: failCloudDelete,
      failLocalDelete: failLocalDelete,
    );
    return AccountDeletionService(
      appStateController: appStateController,
      authController: authController,
      authBackend: authBackend,
      reauthenticationService: AccountReauthenticationService(
        authBackend: authBackend,
        promptPassword: promptPassword,
        chooseMethod: chooseMethod,
        googleReauthFlow: googleReauthFlow,
      ),
    );
  }

  test('Google-only account deletion uses Google reauthentication', () async {
    final AuthController authController = await buildAuthController(
      const UserProfile(
        id: 'user-1',
        email: 'user@example.com',
        displayName: 'User',
        provider: 'google',
        accessToken: 'token',
      ),
    );
    final _RecordingAuthBackend authBackend = _RecordingAuthBackend(
      uid: 'user-1',
      email: 'user@example.com',
      providerIds: <String>['google.com'],
      callOrder: callOrder,
      onReauth: () async {
        expect(authController.currentUser, isNotNull);
      },
      onDelete: () async {
        expect(authController.currentUser, isNotNull);
      },
    );
    final AccountDeletionService service = buildService(
      authController: authController,
      authBackend: authBackend,
      promptPassword: (_) async {
        fail('password prompt must not be shown for Google-only accounts');
      },
      chooseMethod: ({required List<AccountReauthMethod> availableMethods}) async {
        fail('chooser must not be shown for Google-only accounts');
      },
      googleReauthFlow: () async => GoogleAuthProvider.credential(
        accessToken: 'google-access',
        idToken: 'google-id',
      ),
    );

    await service.deleteAccount();

    expect(authBackend.lastCredentialProviderId, 'google.com');
    expect(
      callOrder,
      <String>[
        'reauth:google.com',
        'cloudDelete',
        'authDelete',
        'localDelete',
        'authController.signOut',
      ],
    );
    expect(authController.currentUser, isNull);
  });

  test('Password-only account deletion prompts for password', () async {
    final AuthController authController = await buildAuthController(
      const UserProfile(
        id: 'user-2',
        email: 'user@example.com',
        displayName: 'User',
        provider: 'email',
        accessToken: 'token',
      ),
    );
    final _RecordingAuthBackend authBackend = _RecordingAuthBackend(
      uid: 'user-2',
      email: 'user@example.com',
      providerIds: <String>['password'],
      callOrder: callOrder,
    );
    final List<String> prompts = <String>[];
    final AccountDeletionService service = buildService(
      authController: authController,
      authBackend: authBackend,
      promptPassword: (UserProfile user) async {
        prompts.add(user.email);
        return 'secret-password';
      },
      chooseMethod: ({required List<AccountReauthMethod> availableMethods}) async {
        fail('chooser must not be shown for password-only accounts');
      },
    );

    await service.deleteAccount();

    expect(prompts, <String>['user@example.com']);
    expect(authBackend.lastCredentialProviderId, 'password');
    expect(
      callOrder,
      <String>[
        'reauth:password',
        'cloudDelete',
        'authDelete',
        'localDelete',
        'authController.signOut',
      ],
    );
  });

  test('Multiple linked providers allow choosing Google or password', () async {
    final AuthController authController = await buildAuthController(
      const UserProfile(
        id: 'user-3',
        email: 'user@example.com',
        displayName: 'User',
        provider: 'google',
        accessToken: 'token',
      ),
    );
    final _RecordingAuthBackend authBackend = _RecordingAuthBackend(
      uid: 'user-3',
      email: 'user@example.com',
      providerIds: <String>['google.com', 'password'],
      callOrder: callOrder,
    );
    final List<List<AccountReauthMethod>> choices = <List<AccountReauthMethod>>[];
    final AccountDeletionService service = buildService(
      authController: authController,
      authBackend: authBackend,
      promptPassword: (UserProfile user) async => 'secret-password',
      chooseMethod: ({required List<AccountReauthMethod> availableMethods}) async {
        choices.add(List<AccountReauthMethod>.from(availableMethods));
        return AccountReauthMethod.password;
      },
    );

    await service.deleteAccount();

    expect(choices.single, <AccountReauthMethod>[
      AccountReauthMethod.google,
      AccountReauthMethod.password,
    ]);
    expect(authBackend.lastCredentialProviderId, 'password');
  });

  test('requires-recent-login is handled with reauthenticateWithCredential',
      () async {
    final AuthController authController = await buildAuthController(
      const UserProfile(
        id: 'user-4',
        email: 'user@example.com',
        displayName: 'User',
        provider: 'google',
        accessToken: 'token',
      ),
    );
    final _RecordingAuthBackend authBackend = _RecordingAuthBackend(
      uid: 'user-4',
      email: 'user@example.com',
      providerIds: <String>['google.com'],
      callOrder: callOrder,
      throwRecentLoginOnFirstDeleteOnce: true,
    );
    final AccountDeletionService service = buildService(
      authController: authController,
      authBackend: authBackend,
      promptPassword: (_) async {
        fail('password prompt must not be shown');
      },
      chooseMethod: ({required List<AccountReauthMethod> availableMethods}) async {
        fail('chooser must not be shown');
      },
      googleReauthFlow: () async => GoogleAuthProvider.credential(
        accessToken: 'google-access',
        idToken: 'google-id',
      ),
    );

    await service.deleteAccount();

    expect(
      callOrder,
      <String>[
        'reauth:google.com',
        'cloudDelete',
        'authDelete',
        'reauth:google.com',
        'authDelete',
        'localDelete',
        'authController.signOut',
      ],
    );
    expect(authBackend.deleteAttempts, 2);
    expect(authController.currentUser, isNull);
  });

  test('cloud cleanup runs before auth deletion and local cleanup runs after',
      () async {
    final AuthController authController = await buildAuthController(
      const UserProfile(
        id: 'user-5',
        email: 'user@example.com',
        displayName: 'User',
        provider: 'google',
        accessToken: 'token',
      ),
    );
    final _RecordingAuthBackend authBackend = _RecordingAuthBackend(
      uid: 'user-5',
      email: 'user@example.com',
      providerIds: <String>['google.com'],
      callOrder: callOrder,
      onDelete: () async {
        expect(
          authController.currentUser,
          isNotNull,
          reason: 'current user should remain valid until auth delete succeeds',
        );
      },
    );
    final AccountDeletionService service = buildService(
      authController: authController,
      authBackend: authBackend,
      promptPassword: (_) async => null,
      chooseMethod: ({required List<AccountReauthMethod> availableMethods}) async {
        return AccountReauthMethod.google;
      },
      googleReauthFlow: () async => GoogleAuthProvider.credential(
        accessToken: 'google-access',
        idToken: 'google-id',
      ),
    );

    await service.deleteAccount();

    expect(
      callOrder,
      <String>[
        'reauth:google.com',
        'cloudDelete',
        'authDelete',
        'localDelete',
        'authController.signOut',
      ],
    );
  });

  test('cancellation leaves everything unchanged', () async {
    final AuthController authController = await buildAuthController(
      const UserProfile(
        id: 'user-6',
        email: 'user@example.com',
        displayName: 'User',
        provider: 'google',
        accessToken: 'token',
      ),
    );
    final _RecordingAuthBackend authBackend = _RecordingAuthBackend(
      uid: 'user-6',
      email: 'user@example.com',
      providerIds: <String>['google.com', 'password'],
      callOrder: callOrder,
    );
    final AccountDeletionService service = buildService(
      authController: authController,
      authBackend: authBackend,
      promptPassword: (_) async => null,
      chooseMethod: ({required List<AccountReauthMethod> availableMethods}) async {
        return null;
      },
      googleReauthFlow: () async => null,
    );

    await expectLater(service.deleteAccount(), throwsStateError);

    expect(callOrder, isEmpty);
    expect(authController.currentUser, isNotNull);
  });

  test('local cleanup failure is retried after auth deletion', () async {
    final AuthController authController = await buildAuthController(
      const UserProfile(
        id: 'user-7',
        email: 'user@example.com',
        displayName: 'User',
        provider: 'google',
        accessToken: 'token',
      ),
    );
    final _RecordingAuthBackend authBackend = _RecordingAuthBackend(
      uid: 'user-7',
      email: 'user@example.com',
      providerIds: <String>['google.com'],
      callOrder: callOrder,
    );
    final AccountDeletionService service = buildService(
      authController: authController,
      authBackend: authBackend,
      promptPassword: (_) async => null,
      chooseMethod: ({required List<AccountReauthMethod> availableMethods}) async {
        return AccountReauthMethod.google;
      },
      googleReauthFlow: () async => GoogleAuthProvider.credential(
        accessToken: 'google-access',
        idToken: 'google-id',
      ),
      failLocalDelete: true,
    );

    await expectLater(service.deleteAccount(), throwsStateError);

    expect(
      callOrder,
      <String>[
        'reauth:google.com',
        'cloudDelete',
        'authDelete',
        'localDelete',
        'localDelete',
        'authController.signOut',
      ],
    );
    expect(authController.currentUser, isNull);
  });

  test('cloud cleanup failure aborts before auth deletion', () async {
    final AuthController authController = await buildAuthController(
      const UserProfile(
        id: 'user-8',
        email: 'user@example.com',
        displayName: 'User',
        provider: 'google',
        accessToken: 'token',
      ),
    );
    final _RecordingAuthBackend authBackend = _RecordingAuthBackend(
      uid: 'user-8',
      email: 'user@example.com',
      providerIds: <String>['google.com'],
      callOrder: callOrder,
    );
    final AccountDeletionService service = buildService(
      authController: authController,
      authBackend: authBackend,
      promptPassword: (_) async => null,
      chooseMethod: ({required List<AccountReauthMethod> availableMethods}) async {
        return AccountReauthMethod.google;
      },
      googleReauthFlow: () async => GoogleAuthProvider.credential(
        accessToken: 'google-access',
        idToken: 'google-id',
      ),
      failCloudDelete: true,
    );

    await expectLater(service.deleteAccount(), throwsStateError);

    expect(callOrder, <String>['reauth:google.com', 'cloudDelete']);
    expect(authController.currentUser, isNotNull);
  });
}
