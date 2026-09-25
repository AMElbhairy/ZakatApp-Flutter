import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/data/local/app_database.dart' hide Saving;
import 'package:zakatapp_flutter/models/app_state.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/models/transaction.dart' as model;
import 'package:zakatapp_flutter/models/saving.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/backup_integrity_summary.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/services/collection_hydration_evidence.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/backup_key_manager.dart';
import 'package:zakatapp_flutter/services/cloud_backup_controller.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/market_data_api_service.dart';
import 'package:zakatapp_flutter/services/secure_storage_service.dart';
import 'package:zakatapp_flutter/services/startup_restore_discovery.dart';
import 'package:zakatapp_flutter/services/sync/cloud_sync_manager.dart';
import 'package:zakatapp_flutter/services/sync/cloud_sync_manifest.dart';
import 'package:zakatapp_flutter/services/sync/snapshot_manager.dart';
import 'package:zakatapp_flutter/services/sync/sync_encryption_service.dart';
import 'package:zakatapp_flutter/services/sync/user_cloud_storage_provider.dart';

import '../support/mock_cloud_storage_provider.dart';

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

class _MutableAuthService implements AuthService {
  _MutableAuthService({required this.user});

  UserProfile? user;

  @override
  Future<bool> ensureSession() async => true;

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
  Future<bool> isCurrentUserEmailVerified() async =>
      user?.emailVerified ?? false;

  @override
  Future<void> signOut() async {
    user = null;
  }

  @override
  Future<void> deleteAccount() async {}
}

class _FakeGoogleSignIn implements GoogleSignIn {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RestoringAppStateController extends AppStateController {
  _RestoringAppStateController({
    required super.repository,
    required super.database,
    required super.ownsDatabase,
    required super.secureStorageService,
    required super.useSqliteLocalStoreProvider,
    required super.marketDataApiService,
    required super.enableBackgroundSync,
    required super.enableMarketAutoRefresh,
  });

  @override
  bool get isRestoringDatabase => true;
}

class _FixedAppStateController extends AppStateController {
  _FixedAppStateController({
    required super.repository,
    required super.database,
    required super.ownsDatabase,
    required super.secureStorageService,
    required super.useSqliteLocalStoreProvider,
    required super.marketDataApiService,
    required super.enableBackgroundSync,
    required super.enableMarketAutoRefresh,
    required this.fixedState,
    required this.fixedHydrationReady,
    required this.fixedRestoring,
  });

  final AppStateModel fixedState;
  final bool fixedHydrationReady;
  final bool fixedRestoring;

  @override
  AppStateModel get state => fixedState;

  @override
  AppHydrationPhase get hydrationPhase => fixedHydrationReady
      ? AppHydrationPhase.ready
      : AppHydrationPhase.notStarted;

  @override
  bool get isHydrationReady => fixedHydrationReady;

  @override
  bool get isRestoringDatabase => fixedRestoring;
}

class _MutableIntegrityAppStateController extends AppStateController {
  _MutableIntegrityAppStateController({
    required super.repository,
    required super.database,
    required super.ownsDatabase,
    required super.secureStorageService,
    required super.useSqliteLocalStoreProvider,
    required super.marketDataApiService,
    required super.enableBackgroundSync,
    required super.enableMarketAutoRefresh,
    required this._state,
    required this._collectionSources,
    required this.hydrationReady,
    required this.restoring,
  });

  AppStateModel _state;
  Map<String, String> _collectionSources;
  bool hydrationReady;
  bool restoring;

  set stateValue(AppStateModel next) {
    _state = next;
  }

  set collectionSourcesValue(Map<String, String> next) {
    _collectionSources = Map<String, String>.from(next);
  }

  @override
  AppStateModel get state => _state;

  @override
  Map<String, String> get collectionSources =>
      Map<String, String>.unmodifiable(_collectionSources);

  @override
  AppHydrationPhase get hydrationPhase =>
      hydrationReady ? AppHydrationPhase.ready : AppHydrationPhase.hydrating;

  @override
  bool get isHydrationReady => hydrationReady;

  @override
  bool get isRestoringDatabase => restoring;
}

class _SlowMockCloudStorageProvider extends MockCloudStorageProvider {
  _SlowMockCloudStorageProvider() : super(connected: true);

  @override
  Future<void> writeManifest(
    Map<String, dynamic> manifestData, {
    String? expectedRevision,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return super.writeManifest(
      manifestData,
      expectedRevision: expectedRevision,
    );
  }
}

class _TrackingCloudBackupController extends CloudBackupController {
  _TrackingCloudBackupController({
    required super.appStateController,
    required super.authController,
    required super.snapshotManager,
    required super.debounceDuration,
    required super.nowProvider,
    super.backupKeyManager,
  });

  int refreshCalls = 0;
  bool? lastEvaluatePrompt;
  int connectCalls = 0;
  bool? lastInteractiveConnect;

  @override
  Future<void> refreshCloudState({bool evaluatePrompt = true}) async {
    refreshCalls += 1;
    lastEvaluatePrompt = evaluatePrompt;
  }

  @override
  Future<bool> connectGoogleDrive({required bool interactive}) async {
    connectCalls += 1;
    lastInteractiveConnect = interactive;
    await refreshCloudState(evaluatePrompt: false);
    return true;
  }
}

class _NoopMarketDataApiService implements MarketDataApiService {
  @override
  Future<Map<String, double>?> fetchFxRatesToEgp() async => <String, double>{};

  @override
  Future<double?> fetchGold24kPerGramEgp({required double usdToEgp}) async =>
      null;

  @override
  Future<double?> fetchSilverPerGramEgp({required double usdToEgp}) async =>
      null;
}

class _ThrowingBackupKeyManager extends BackupKeyManager {
  _ThrowingBackupKeyManager({required super.auth, required super.firestore})
    : super(
        secureStorageService: _MemorySecureStorageService(),
        nowProvider: DateTime.now,
      );

  @override
  Future<void> recoverKeyFromFirestore() async {
    throw const BackupKeyRecoveryException(
      BackupKeyRecoveryException.recoveryUnavailableMessage,
    );
  }

  @override
  Future<Uint8List?> getExistingKey() async => null;
}

class _Harness {
  _Harness({
    required this.appState,
    required this.auth,
    required this.cloud,
    required this.provider,
    required this.database,
    required this.tempDir,
  });

  final AppStateController appState;
  final AuthController auth;
  final CloudBackupController cloud;
  final MockCloudStorageProvider provider;
  final AppDatabase database;
  final Directory tempDir;
}

class _MemorySecureStorageService extends SecureStorageService {
  _MemorySecureStorageService();

  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> loadBackupKey({String? userId}) async {
    return _values['backupKey:${userId ?? 'default'}'];
  }

  @override
  Future<void> saveBackupKey(String keyValue, {String? userId}) async {
    _values['backupKey:${userId ?? 'default'}'] = keyValue;
  }

  @override
  Future<String?> loadBackupPassphrase({String? userId}) async {
    return _values['backupPassphrase:${userId ?? 'default'}'];
  }

  @override
  Future<void> saveBackupPassphrase(String passphrase, {String? userId}) async {
    _values['backupPassphrase:${userId ?? 'default'}'] = passphrase;
  }
}

model.Transaction _transaction(String id) {
  return model.Transaction(
    id: id,
    type: 'income',
    date: '2026-06-23',
    amount: 100,
    currency: 'USD',
    category: 'Salary',
    description: id,
    createdAt: '2026-06-23T08:00:00Z',
    rolledOver: false,
  );
}

Saving _saving(String id) {
  return Saving(
    id: id,
    assetType: 'cash',
    dateAcquired: '2026-06-23',
    amount: 50,
    remainingAmount: 50,
    unit: 'USD',
    description: id,
    purchaseCurrency: 'USD',
    purchaseAmount: 50,
    createdAt: '2026-06-23T08:00:00Z',
  );
}

AppStateModel _baselineState({
  required bool includeSavings,
  required String revision,
}) {
  return AppStateDefaults.create().copyWith(
    transactions: <model.Transaction>[_transaction('tx-1')],
    savings: includeSavings ? <Saving>[_saving('sav-1')] : <Saving>[],
    userId: 'test-user',
    loadedUserId: 'test-user',
    lastModifiedAt: revision,
  );
}

Future<_Harness> _buildHarness({
  required MockCloudStorageProvider provider,
  DateTime Function()? nowProvider,
  Duration debounceDuration = const Duration(milliseconds: 20),
  bool restoring = false,
  bool setupPassphrase = true,
  BackupKeyManager? backupKeyManager,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  const LocalStorageService localStorage = LocalStorageService();
  final _MemorySecureStorageService secureStorageService =
      _MemorySecureStorageService();
  final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
  final AppStateRepository repository = AppStateRepository(
    localStorage: localStorage,
  );
  final Directory tempDir = await Directory.systemTemp.createTemp(
    'cloud_backup_controller_test_',
  );
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      });
  final File dbFile = File(p.join(tempDir.path, 'app.sqlite'));
  final AppDatabase database = AppDatabase(
    userId: 'test-user',
    executor: NativeDatabase(dbFile),
  );
  final AppStateController appState = restoring
      ? _RestoringAppStateController(
          repository: repository,
          database: database,
          ownsDatabase: false,
          secureStorageService: secureStorageService,
          useSqliteLocalStoreProvider: null,
          marketDataApiService: _NoopMarketDataApiService(),
          enableBackgroundSync: false,
          enableMarketAutoRefresh: false,
        )
      : AppStateController(
          repository: repository,
          database: database,
          ownsDatabase: false,
          secureStorageService: secureStorageService,
          marketDataApiService: _NoopMarketDataApiService(),
          enableBackgroundSync: false,
          enableMarketAutoRefresh: false,
        );
  await appState.load();
  await appState.loadAuthenticated('test-user');

  final UserProfile user = const UserProfile(
    id: 'test-user',
    email: 'test@example.com',
    displayName: 'Test User',
    provider: 'google',
    accessToken: 'token',
  );
  final AuthController auth = AuthController(
    authService: _FakeAuthService(user: user),
    localStorage: localStorage,
  );
  await auth.signIn();

  final SnapshotManager snapshotManager = SnapshotManager(
    encryptionService: SyncEncryptionService(),
  );
  final BackupKeyManager resolvedBackupKeyManager =
      backupKeyManager ??
      BackupKeyManager(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'test-user', email: 'test@example.com'),
        ),
        firestore: firestore,
        secureStorageService: secureStorageService,
        nowProvider: nowProvider ?? DateTime.now,
      );
  final CloudSyncManager syncManager = CloudSyncManager(
    provider: provider,
    snapshotManager: snapshotManager,
    deviceId: 'device-1',
    deviceName: 'Test Device',
    platform: 'android',
    appVersion: '1.0.0',
  );

  final CloudBackupController cloud = CloudBackupController(
    appStateController: appState,
    authController: auth,
    backupKeyManager: resolvedBackupKeyManager,
    snapshotManager: snapshotManager,
    cloudSyncManagerBuilder: () async => syncManager,
    debounceDuration: debounceDuration,
    nowProvider: nowProvider ?? DateTime.now,
  );
  if (setupPassphrase) {
    cloud.setBackupPassphrase(
      base64UrlEncode(await resolvedBackupKeyManager.getOrCreateKey()),
    );
  }

  return _Harness(
    appState: appState,
    auth: auth,
    cloud: cloud,
    provider: provider,
    database: database,
    tempDir: tempDir,
  );
}

Future<void> _seedVisibleAppData(AppStateController appState) async {
  await appState.addTransaction(
    const model.Transaction(
      id: 'seed-transaction',
      type: 'income',
      date: '2026-06-23',
      amount: 100,
      currency: 'USD',
      category: 'Salary',
      description: 'Seed transaction',
      createdAt: '2026-06-23T08:00:00Z',
      rolledOver: false,
    ),
  );
  await appState.loadAuthenticated('test-user');
}

Future<void> _disposeHarness(_Harness harness) async {
  harness.cloud.dispose();
  await harness.database.close();
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, null);
  if (await harness.tempDir.exists()) {
    await harness.tempDir.delete(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cloud backup is blocked before hydration is ready', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateController appState = AppStateController(
      repository: AppStateRepository(localStorage: localStorage),
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
    );
    final UserProfile user = const UserProfile(
      id: 'test-user',
      email: 'test@example.com',
      displayName: 'Test User',
      provider: 'google',
      accessToken: 'token',
    );
    final AuthController auth = AuthController(
      authService: _FakeAuthService(user: user),
      localStorage: localStorage,
    );
    await auth.signIn();
    final CloudBackupController cloud = CloudBackupController(
      appStateController: appState,
      authController: auth,
      backupKeyManager: BackupKeyManager(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'test-user', email: 'test@example.com'),
        ),
        firestore: FakeFirebaseFirestore(),
      ),
      googleSignIn: _FakeGoogleSignIn(),
      cloudSyncManagerBuilder: () async => null,
    );

    expect(await cloud.backupNow(), isFalse);
    expect(cloud.lastBackupError, 'hydration_not_ready');

    cloud.dispose();
  });

  test(
    'cloud backup prefers active auth user over stale loaded user',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const LocalStorageService localStorage = LocalStorageService();
      final AppDatabase database = AppDatabase(
        userId: 'stale-user',
        executor: NativeDatabase.memory(),
      );
      final AppStateController appState = AppStateController(
        repository: AppStateRepository(localStorage: localStorage),
        database: database,
        ownsDatabase: false,
        secureStorageService: _MemorySecureStorageService(),
        marketDataApiService: _NoopMarketDataApiService(),
        enableBackgroundSync: false,
        enableMarketAutoRefresh: false,
      );
      await appState.load();
      await appState.loadAuthenticated('stale-user');
      await appState.addTransaction(_transaction('tx-auth-user'));

      final UserProfile authUser = const UserProfile(
        id: 'auth-user',
        email: 'auth@example.com',
        displayName: 'Auth User',
        provider: 'email',
        accessToken: 'token',
      );
      final _MutableAuthService authService = _MutableAuthService(
        user: authUser,
      );
      final AuthController auth = AuthController(
        authService: authService,
        localStorage: localStorage,
      );
      await auth.signInWithEmail(email: authUser.email, password: 'secret');
      final CloudBackupController cloud = CloudBackupController(
        appStateController: appState,
        authController: auth,
        backupKeyManager: BackupKeyManager(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: authUser.id, email: authUser.email),
          ),
          firestore: FakeFirebaseFirestore(),
          secureStorageService: _MemorySecureStorageService(),
        ),
      );

      expect(cloud.debugSessionUserId, 'auth-user');
      expect(cloud.debugSessionUserId, isNot('stale-user'));

      cloud.dispose();
      await database.close();
    },
  );

  test(
    'cloud backup keeps the last drive session user after app sign out',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppDatabase database = AppDatabase(
        userId: 'app-user',
        executor: NativeDatabase.memory(),
      );
      final _FixedAppStateController appState = _FixedAppStateController(
        repository: AppStateRepository(
          localStorage: const LocalStorageService(),
        ),
        database: database,
        ownsDatabase: false,
        secureStorageService: _MemorySecureStorageService(),
        useSqliteLocalStoreProvider: null,
        marketDataApiService: _NoopMarketDataApiService(),
        enableBackgroundSync: false,
        enableMarketAutoRefresh: false,
        fixedState: AppStateDefaults.create().copyWith(
          userId: '',
          loadedUserId: '',
          lastModifiedAt: 'rev-1',
        ),
        fixedHydrationReady: true,
        fixedRestoring: false,
      );
      final _MutableAuthService authService = _MutableAuthService(
        user: const UserProfile(
          id: 'google-user',
          email: 'google@example.com',
          displayName: 'Google User',
          provider: 'google',
          accessToken: 'token-a',
        ),
      );
      final AuthController auth = AuthController(
        authService: authService,
        localStorage: const LocalStorageService(),
      );
      await auth.signIn();

      final MockCloudStorageProvider provider = MockCloudStorageProvider(
        connected: true,
      );
      final CloudBackupController cloud = CloudBackupController(
        appStateController: appState,
        authController: auth,
        backupKeyManager: BackupKeyManager(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'google-user', email: 'google@example.com'),
          ),
          firestore: FakeFirebaseFirestore(),
          secureStorageService: _MemorySecureStorageService(),
        ),
        cloudSyncManagerBuilder: () async => CloudSyncManager(
          provider: provider,
          snapshotManager: SnapshotManager(
            encryptionService: SyncEncryptionService(),
          ),
          deviceId: 'device-1',
          deviceName: 'Test Device',
          platform: 'ios',
        ),
      );

      await cloud.refreshCloudState(evaluatePrompt: false);
      expect(cloud.debugSessionUserId, 'google-user');

      await auth.signOut();
      await cloud.refreshCloudState(evaluatePrompt: false);

      expect(cloud.debugSessionUserId, 'google-user');
      expect(cloud.debugSessionUserId, isNot('default'));

      cloud.dispose();
      await database.close();
    },
  );

  test(
    'cloud backup refreshes when auth changes even if app state stamp is unchanged',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppDatabase database = AppDatabase(
        userId: 'app-user',
        executor: NativeDatabase.memory(),
      );
      final AppStateRepository repository = AppStateRepository(
        localStorage: const LocalStorageService(),
      );
      final _FixedAppStateController appState = _FixedAppStateController(
        repository: repository,
        database: database,
        ownsDatabase: false,
        secureStorageService: const SecureStorageService(),
        useSqliteLocalStoreProvider: null,
        marketDataApiService: _NoopMarketDataApiService(),
        enableBackgroundSync: false,
        enableMarketAutoRefresh: false,
        fixedState: AppStateDefaults.create().copyWith(
          userId: 'app-user',
          loadedUserId: 'app-user',
          lastModifiedAt: 'rev-1',
        ),
        fixedHydrationReady: true,
        fixedRestoring: false,
      );
      final _MutableAuthService authService = _MutableAuthService(
        user: const UserProfile(
          id: 'google-user',
          email: 'google@example.com',
          displayName: 'Google User',
          provider: 'google',
          accessToken: 'token-a',
        ),
      );
      final AuthController auth = AuthController(
        authService: authService,
        localStorage: const LocalStorageService(),
      );
      await auth.signIn();

      final _TrackingCloudBackupController cloud =
          _TrackingCloudBackupController(
            appStateController: appState,
            authController: auth,
            backupKeyManager: BackupKeyManager(
              auth: MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(uid: 'app-user', email: 'app@example.com'),
              ),
              firestore: FakeFirebaseFirestore(),
              secureStorageService: _MemorySecureStorageService(),
            ),
            snapshotManager: SnapshotManager(
              encryptionService: SyncEncryptionService(),
            ),
            debounceDuration: Duration.zero,
            nowProvider: DateTime.now,
          );

      await Future<void>.delayed(Duration.zero);
      await cloud.setAutomaticBackupEnabled(false);
      cloud.refreshCalls = 0;

      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(cloud.refreshCalls, 0);

      authService.user = const UserProfile(
        id: 'email-user',
        email: 'email@example.com',
        displayName: 'Email User',
        provider: 'email',
        accessToken: null,
      );
      await auth.signInWithEmail(
        email: 'email@example.com',
        password: 'secret',
      );
      await Future<void>.delayed(Duration.zero);

      expect(cloud.refreshCalls, greaterThan(0));

      cloud.dispose();
      await database.close();
    },
  );

  test(
    'cloud backup auto-connects when switching to Google Drive provider',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppDatabase database = AppDatabase(
        userId: 'app-user',
        executor: NativeDatabase.memory(),
      );
      final AppStateRepository repository = AppStateRepository(
        localStorage: const LocalStorageService(),
      );
      final _FixedAppStateController appState = _FixedAppStateController(
        repository: repository,
        database: database,
        ownsDatabase: false,
        secureStorageService: _MemorySecureStorageService(),
        useSqliteLocalStoreProvider: null,
        marketDataApiService: _NoopMarketDataApiService(),
        enableBackgroundSync: false,
        enableMarketAutoRefresh: false,
        fixedState: AppStateDefaults.create().copyWith(
          userId: 'app-user',
          loadedUserId: 'app-user',
          lastModifiedAt: 'rev-1',
        ),
        fixedHydrationReady: true,
        fixedRestoring: false,
      );
      final _MutableAuthService authService = _MutableAuthService(
        user: const UserProfile(
          id: 'google-user',
          email: 'google@example.com',
          displayName: 'Google User',
          provider: 'google',
          accessToken: 'token-a',
        ),
      );
      final AuthController auth = AuthController(
        authService: authService,
        localStorage: const LocalStorageService(),
      );
      await auth.signIn();

      final _TrackingCloudBackupController cloud =
          _TrackingCloudBackupController(
            appStateController: appState,
            authController: auth,
            backupKeyManager: BackupKeyManager(
              auth: MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(
                  uid: 'google-user',
                  email: 'google@example.com',
                ),
              ),
              firestore: FakeFirebaseFirestore(),
              secureStorageService: _MemorySecureStorageService(),
            ),
            snapshotManager: SnapshotManager(
              encryptionService: SyncEncryptionService(),
            ),
            debounceDuration: Duration.zero,
            nowProvider: DateTime.now,
          );

      await cloud.selectBackupProvider('google_drive');

      expect(cloud.connectCalls, 1);
      expect(cloud.lastInteractiveConnect, isTrue);
      expect(cloud.refreshCalls, 1);

      cloud.dispose();
      await database.close();
    },
  );

  test(
    'cloud backup auto-connects when switching to iCloud provider',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppDatabase database = AppDatabase(
        userId: 'app-user',
        executor: NativeDatabase.memory(),
      );
      final AppStateRepository repository = AppStateRepository(
        localStorage: const LocalStorageService(),
      );
      final _FixedAppStateController appState = _FixedAppStateController(
        repository: repository,
        database: database,
        ownsDatabase: false,
        secureStorageService: _MemorySecureStorageService(),
        useSqliteLocalStoreProvider: null,
        marketDataApiService: _NoopMarketDataApiService(),
        enableBackgroundSync: false,
        enableMarketAutoRefresh: false,
        fixedState: AppStateDefaults.create().copyWith(
          userId: 'app-user',
          loadedUserId: 'app-user',
          lastModifiedAt: 'rev-1',
        ),
        fixedHydrationReady: true,
        fixedRestoring: false,
      );
      final _MutableAuthService authService = _MutableAuthService(
        user: const UserProfile(
          id: 'apple-user',
          email: 'apple@example.com',
          displayName: 'Apple User',
          provider: 'apple',
          accessToken: 'token-b',
        ),
      );
      final AuthController auth = AuthController(
        authService: authService,
        localStorage: const LocalStorageService(),
      );

      final _TrackingCloudBackupController cloud =
          _TrackingCloudBackupController(
            appStateController: appState,
            authController: auth,
            backupKeyManager: BackupKeyManager(
              auth: MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(
                  uid: 'apple-user',
                  email: 'apple@example.com',
                ),
              ),
              firestore: FakeFirebaseFirestore(),
              secureStorageService: _MemorySecureStorageService(),
            ),
            snapshotManager: SnapshotManager(
              encryptionService: SyncEncryptionService(),
            ),
            debounceDuration: Duration.zero,
            nowProvider: DateTime.now,
          );

      await cloud.selectBackupProvider('icloud');

      expect(cloud.connectCalls, 1);
      expect(cloud.lastInteractiveConnect, isFalse);
      expect(cloud.refreshCalls, 1);

      cloud.dispose();
      await database.close();
    },
  );

  test('automatic empty backup is blocked when cloud history exists', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cloud_backup_last_backup_ms_test-user': 1,
    });
    const LocalStorageService localStorage = LocalStorageService();
    final AppDatabase database = AppDatabase(
      userId: 'test-user',
      executor: NativeDatabase(
        File(
          p.join(Directory.systemTemp.path, 'cloud_backup_restore_test.sqlite'),
        ),
      ),
    );
    final _FixedAppStateController appState = _FixedAppStateController(
      repository: AppStateRepository(localStorage: localStorage),
      database: database,
      ownsDatabase: false,
      secureStorageService: _MemorySecureStorageService(),
      useSqliteLocalStoreProvider: null,
      marketDataApiService: _NoopMarketDataApiService(),
      enableBackgroundSync: false,
      enableMarketAutoRefresh: false,
      fixedState: AppStateDefaults.create().copyWith(
        userId: 'test-user',
        loadedUserId: 'test-user',
      ),
      fixedHydrationReady: true,
      fixedRestoring: false,
    );
    final _SlowMockCloudStorageProvider provider =
        _SlowMockCloudStorageProvider();

    final UserProfile user = const UserProfile(
      id: 'test-user',
      email: 'test@example.com',
      displayName: 'Test User',
      provider: 'google',
      accessToken: 'token',
    );
    final AuthController auth = AuthController(
      authService: _FakeAuthService(user: user),
      localStorage: localStorage,
    );
    await auth.signIn();

    final CloudBackupController cloud = CloudBackupController(
      appStateController: appState,
      authController: auth,
      backupKeyManager: BackupKeyManager(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'test-user', email: 'test@example.com'),
        ),
        firestore: FakeFirebaseFirestore(),
      ),
      googleSignIn: _FakeGoogleSignIn(),
      cloudSyncManagerBuilder: () async => CloudSyncManager(
        provider: provider,
        snapshotManager: SnapshotManager(
          encryptionService: SyncEncryptionService(),
        ),
        deviceId: 'device-a',
        deviceName: 'device-a',
        platform: 'ios',
      ),
    );

    expect(appState.isHydrationReady, isTrue);
    expect(appState.isRestoringDatabase, isFalse);
    cloud.setBackupPassphrase('secret-passphrase');
    expect(await cloud.backupNow(automatic: true), isFalse);
    expect(cloud.lastBackupError, 'empty_candidate_has_history');

    cloud.dispose();
    await database.close();
  });

  test(
    'automatic backup blocks a partial non-empty startup candidate',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const LocalStorageService localStorage = LocalStorageService();
      final AppStateRepository repository = AppStateRepository(
        localStorage: localStorage,
      );
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'cloud_backup_integrity_test_',
      );
      final File dbFile = File(p.join(tempDir.path, 'app.sqlite'));
      final AppDatabase database = AppDatabase(
        userId: 'test-user',
        executor: NativeDatabase(dbFile),
      );

      final _MutableIntegrityAppStateController appState =
          _MutableIntegrityAppStateController(
            repository: repository,
            database: database,
            ownsDatabase: false,
            secureStorageService: _MemorySecureStorageService(),
            useSqliteLocalStoreProvider: null,
            marketDataApiService: _NoopMarketDataApiService(),
            enableBackgroundSync: false,
            enableMarketAutoRefresh: false,
            state: _baselineState(
              includeSavings: true,
              revision: '2026-06-23T08:00:00Z',
            ),
            collectionSources: <String, String>{
              'transactions': 'SQLite',
              'savings': 'SQLite',
              'pending_transactions': 'SQLite',
              'financial_plans': 'SQLite',
              'investments': 'SQLite',
              'recurring_transactions': 'SQLite',
              'merchant_rules': 'SQLite',
              'merchant_confirmations': 'SQLite',
              'correction_feedback': 'SQLite',
              'app_settings': 'SQLite',
            },
            hydrationReady: true,
            restoring: false,
          );
      final UserProfile user = const UserProfile(
        id: 'test-user',
        email: 'test@example.com',
        displayName: 'Test User',
        provider: 'google',
        accessToken: 'token',
      );
      final AuthController auth = AuthController(
        authService: _FakeAuthService(user: user),
        localStorage: localStorage,
      );
      await auth.signIn();

      final _SlowMockCloudStorageProvider provider =
          _SlowMockCloudStorageProvider();
      final CloudBackupController cloud = CloudBackupController(
        appStateController: appState,
        authController: auth,
        backupKeyManager: BackupKeyManager(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'test-user', email: 'test@example.com'),
          ),
          firestore: FakeFirebaseFirestore(),
        ),
        googleSignIn: _FakeGoogleSignIn(),
        cloudSyncManagerBuilder: () async => CloudSyncManager(
          provider: provider,
          snapshotManager: SnapshotManager(
            encryptionService: SyncEncryptionService(),
          ),
          deviceId: 'device-a',
          deviceName: 'device-a',
          platform: 'ios',
        ),
      );
      cloud.setBackupPassphrase('secret-passphrase');

      expect(await cloud.backupNow(automatic: true), isTrue);
      expect(
        cloud.lastKnownGoodIntegritySummary,
        isA<BackupIntegritySummary>(),
      );
      expect(
        cloud.lastKnownGoodIntegritySummary!.collectionCounts['savings'],
        1,
      );
      final manifestBefore = await provider.readManifest();
      expect(manifestBefore, isNotNull);

      appState.stateValue = _baselineState(
        includeSavings: false,
        revision: '2026-06-23T08:05:00Z',
      );
      appState.collectionSourcesValue = <String, String>{
        'transactions': 'SQLite',
        'savings': 'empty default',
        'pending_transactions': 'SQLite',
        'financial_plans': 'SQLite',
        'investments': 'SQLite',
        'recurring_transactions': 'SQLite',
        'merchant_rules': 'SQLite',
        'merchant_confirmations': 'SQLite',
        'correction_feedback': 'SQLite',
        'app_settings': 'SQLite',
      };

      expect(await cloud.backupNow(automatic: true), isFalse);
      expect(cloud.lastBackupError, 'partial_candidate_missing_savings');

      final manifestAfter = await provider.readManifest();
      final manifest = CloudSyncManifest.fromJson(manifestAfter!.content);
      expect(manifest.snapshots, hasLength(1));

      cloud.dispose();
      await database.close();
      await tempDir.delete(recursive: true);
    },
  );

  test(
    'automatic backup allows a legitimate emptying of a collection',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const LocalStorageService localStorage = LocalStorageService();
      final AppStateRepository repository = AppStateRepository(
        localStorage: localStorage,
      );
      final AppDatabase database = AppDatabase(
        executor: NativeDatabase.memory(),
      );
      final _MutableIntegrityAppStateController appState =
          _MutableIntegrityAppStateController(
            repository: repository,
            database: database,
            ownsDatabase: false,
            secureStorageService: _MemorySecureStorageService(),
            useSqliteLocalStoreProvider: null,
            marketDataApiService: _NoopMarketDataApiService(),
            enableBackgroundSync: false,
            enableMarketAutoRefresh: false,
            state: _baselineState(
              includeSavings: true,
              revision: '2026-06-23T08:00:00Z',
            ),
            collectionSources: <String, String>{
              'transactions': 'SQLite',
              'savings': 'SQLite',
              'pending_transactions': 'SQLite',
              'financial_plans': 'SQLite',
              'investments': 'SQLite',
              'recurring_transactions': 'SQLite',
              'merchant_rules': 'SQLite',
              'merchant_confirmations': 'SQLite',
              'correction_feedback': 'SQLite',
              'app_settings': 'SQLite',
            },
            hydrationReady: true,
            restoring: false,
          );
      final UserProfile user = const UserProfile(
        id: 'test-user',
        email: 'test@example.com',
        displayName: 'Test User',
        provider: 'google',
        accessToken: 'token',
      );
      final AuthController auth = AuthController(
        authService: _FakeAuthService(user: user),
        localStorage: localStorage,
      );
      await auth.signIn();

      final _SlowMockCloudStorageProvider provider =
          _SlowMockCloudStorageProvider();
      final CloudBackupController cloud = CloudBackupController(
        appStateController: appState,
        authController: auth,
        backupKeyManager: BackupKeyManager(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'test-user', email: 'test@example.com'),
          ),
          firestore: FakeFirebaseFirestore(),
        ),
        googleSignIn: _FakeGoogleSignIn(),
        cloudSyncManagerBuilder: () async => CloudSyncManager(
          provider: provider,
          snapshotManager: SnapshotManager(
            encryptionService: SyncEncryptionService(),
          ),
          deviceId: 'device-b',
          deviceName: 'device-b',
          platform: 'ios',
        ),
      );
      cloud.setBackupPassphrase('secret-passphrase');

      expect(await cloud.backupNow(automatic: true), isTrue);

      appState.stateValue =
          _baselineState(
            includeSavings: false,
            revision: '2026-06-23T08:05:00Z',
          ).copyWith(
            transactions: <model.Transaction>[_transaction('tx-1')],
            savings: <Saving>[],
          );
      appState.collectionSourcesValue = <String, String>{
        'transactions': 'SQLite',
        'savings': 'SQLite',
        'pending_transactions': 'SQLite',
        'financial_plans': 'SQLite',
        'investments': 'SQLite',
        'recurring_transactions': 'SQLite',
        'merchant_rules': 'SQLite',
        'merchant_confirmations': 'SQLite',
        'correction_feedback': 'SQLite',
        'app_settings': 'SQLite',
      };

      expect(await cloud.backupNow(automatic: true), isTrue);

      cloud.dispose();
      await database.close();
    },
  );

  test('auto backup does not run when disabled', () async {
    final harness = await _buildHarness(
      provider: _SlowMockCloudStorageProvider(),
    );

    await harness.cloud.setAutomaticBackupEnabled(false);
    harness.cloud.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final manifest = await harness.provider.readManifest();
    expect(manifest, isNull);
    expect(harness.cloud.automaticBackupEnabled, isFalse);
    expect(harness.cloud.hasPendingAutoBackup, isFalse);

    await _disposeHarness(harness);
  });

  test('auto backup defaults to on with a 30-minute interval', () async {
    final harness = await _buildHarness(
      provider: _SlowMockCloudStorageProvider(),
    );

    expect(harness.cloud.automaticBackupEnabled, isTrue);
    expect(harness.cloud.minimumInterval, const Duration(minutes: 30));

    await _disposeHarness(harness);
  });

  test(
    'changing the backup interval recalculates the next eligible time',
    () async {
      var currentTime = DateTime.utc(2026, 6, 23, 9);
      final harness = await _buildHarness(
        provider: _SlowMockCloudStorageProvider(),
        nowProvider: () => currentTime,
      );

      await harness.cloud.backupNow();
      final DateTime? lastBackupAt = harness.cloud.lastBackupAt;
      expect(lastBackupAt, isNotNull);

      await harness.cloud.setMinimumIntervalMinutes(30);
      expect(
        harness.cloud.nextEligibleBackupAt,
        lastBackupAt!.add(const Duration(minutes: 30)),
      );

      await _disposeHarness(harness);
    },
  );

  test('connected backup creates the first backup immediately', () async {
    final harness = await _buildHarness(
      provider: _SlowMockCloudStorageProvider(),
    );

    await _seedVisibleAppData(harness.appState);
    await harness.cloud.refreshCloudState(evaluatePrompt: true);
    CloudManifest? manifestMeta;
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      manifestMeta = await harness.provider.readManifest();
      if (manifestMeta != null) {
        break;
      }
    }
    expect(manifestMeta, isNotNull);
    final manifest = CloudSyncManifest.fromJson(manifestMeta!.content);
    expect(manifest.snapshots.length, 1);
    expect(harness.cloud.lastBackupStatus, 'Backup completed');

    await _disposeHarness(harness);
  });

  test('auto backup runs when enabled and overdue', () async {
    var currentTime = DateTime.utc(2026, 6, 23, 8);
    final provider = _SlowMockCloudStorageProvider();
    final harness = await _buildHarness(
      provider: provider,
      nowProvider: () => currentTime,
    );

    await harness.cloud.setAutomaticBackupEnabled(true);
    harness.cloud.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final manifestMeta = await provider.readManifest();
    expect(manifestMeta, isNotNull);
    final manifest = CloudSyncManifest.fromJson(manifestMeta!.content);
    expect(manifest.snapshots.length, 1);
    expect(harness.cloud.lastBackupStatus, 'Backup completed');
    expect(harness.cloud.lastBackupAt, isNotNull);
    expect(harness.cloud.nextEligibleBackupAt, isNotNull);
    expect(harness.cloud.lastBackupError, isEmpty);

    currentTime = currentTime.add(const Duration(hours: 7));
    harness.cloud.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final updatedManifestMeta = await provider.readManifest();
    final updatedManifest = CloudSyncManifest.fromJson(
      updatedManifestMeta!.content,
    );
    expect(updatedManifest.snapshots.length, 1);

    await _disposeHarness(harness);
  });

  test('auto backup skips when checksum unchanged', () async {
    final harness = await _buildHarness(
      provider: _SlowMockCloudStorageProvider(),
    );

    await harness.cloud.backupNow();
    final firstManifestMeta = await harness.provider.readManifest();
    final firstManifest = CloudSyncManifest.fromJson(
      firstManifestMeta!.content,
    );

    final bool skipped = await harness.cloud.backupNow();
    final secondManifestMeta = await harness.provider.readManifest();
    final secondManifest = CloudSyncManifest.fromJson(
      secondManifestMeta!.content,
    );

    expect(skipped, isTrue);
    expect(firstManifest.snapshots.length, 1);
    expect(secondManifest.snapshots.length, 1);
    expect(harness.cloud.lastBackupStatus, 'Already backed up');
    expect(harness.cloud.lastBackupError, isEmpty);

    await _disposeHarness(harness);
  });

  test('auto backup does not run during active restore', () async {
    final harness = await _buildHarness(
      provider: _SlowMockCloudStorageProvider(),
      restoring: true,
    );

    await harness.cloud.setAutomaticBackupEnabled(true);
    harness.cloud.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final manifest = await harness.provider.readManifest();
    expect(manifest, isNull);
    expect(harness.cloud.isRestoring, isTrue);

    await _disposeHarness(harness);
  });

  test('overlapping auto backups are prevented', () async {
    final harness = await _buildHarness(
      provider: _SlowMockCloudStorageProvider(),
    );

    await harness.cloud.setAutomaticBackupEnabled(true);
    final Future<bool> first = harness.cloud.backupNow(automatic: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final bool second = await harness.cloud.backupNow(automatic: true);
    final bool firstResult = await first;

    final manifestMeta = await harness.provider.readManifest();
    final manifest = CloudSyncManifest.fromJson(manifestMeta!.content);

    expect(firstResult, isTrue);
    expect(second, isFalse);
    expect(manifest.snapshots.length, 1);

    await _disposeHarness(harness);
  });

  test('backup metadata and status update correctly', () async {
    final harness = await _buildHarness(
      provider: _SlowMockCloudStorageProvider(),
    );

    await harness.cloud.refreshCloudState(evaluatePrompt: false);
    expect(harness.cloud.statusMessage, 'Cloud Sync: Active');

    final bool ok = await harness.cloud.backupNow();
    expect(ok, isTrue);
    expect(harness.cloud.lastBackupAt, isNotNull);
    expect(harness.cloud.nextEligibleBackupAt, isNotNull);
    expect(harness.cloud.lastBackupStatus, 'Backup completed');
    expect(harness.cloud.lastBackupError, isEmpty);
    expect(harness.cloud.currentStatus, 'Cloud Sync: Active');

    await _disposeHarness(harness);
  });

  test(
    'fresh local installs prompt restore when a cloud backup exists',
    () async {
      final harness = await _buildHarness(
        provider: _SlowMockCloudStorageProvider(),
      );

      await harness.cloud.backupNow();
      final StartupRestoreDiscoveryResult discovery = await harness.cloud
          .discoverStartupRestore(localHasData: false);

      expect(discovery.status, StartupRestoreDiscoveryStatus.restorePrompt);
      expect(discovery.preview, isNotNull);

      await _disposeHarness(harness);
    },
  );

  test(
    'startup discovery skips prompt when local data already exists',
    () async {
      final harness = await _buildHarness(
        provider: _SlowMockCloudStorageProvider(),
      );

      final StartupRestoreDiscoveryResult discovery = await harness.cloud
          .discoverStartupRestore(localHasData: true);

      expect(discovery.status, StartupRestoreDiscoveryStatus.none);
      expect(discovery.shouldShowGate, isFalse);

      await _disposeHarness(harness);
    },
  );

  test(
    'startup discovery reports key recovery required when the backup key is missing',
    () async {
      final provider = _SlowMockCloudStorageProvider();
      final harness = await _buildHarness(provider: provider);

      expect(await harness.cloud.backupNow(), isTrue);
      await _disposeHarness(harness);

      final harnessWithoutKey = await _buildHarness(
        provider: provider,
        setupPassphrase: false,
      );

      final StartupRestoreDiscoveryResult discovery = await harnessWithoutKey
          .cloud
          .discoverStartupRestore(localHasData: false);

      expect(
        discovery.status,
        StartupRestoreDiscoveryStatus.keyRecoveryRequired,
      );
      expect(discovery.shouldShowGate, isTrue);
      expect(discovery.error, isNotNull);

      await _disposeHarness(harnessWithoutKey);
    },
  );

  test(
    'startup discovery ignores a missing key when no cloud backup exists',
    () async {
      final harness = await _buildHarness(
        provider: _SlowMockCloudStorageProvider(),
        setupPassphrase: false,
      );

      final StartupRestoreDiscoveryResult discovery = await harness.cloud
          .discoverStartupRestore(localHasData: false);

      expect(discovery.status, StartupRestoreDiscoveryStatus.none);
      expect(discovery.shouldShowGate, isFalse);

      await _disposeHarness(harness);
    },
  );

  test(
    'startup discovery falls back to the newest available snapshot when the latest file is missing',
    () async {
      final provider = _SlowMockCloudStorageProvider();
      final harness = await _buildHarness(provider: provider);

      await harness.database.customStatement(
        "CREATE TABLE startup_restore_guard (id INTEGER PRIMARY KEY, value TEXT);",
      );
      await harness.database.customStatement(
        "INSERT INTO startup_restore_guard (id, value) VALUES (1, 'before')",
      );
      expect(await harness.cloud.backupNow(), isTrue);

      await harness.database.customStatement(
        "UPDATE startup_restore_guard SET value = 'after' WHERE id = 1",
      );
      expect(await harness.cloud.backupNow(), isTrue);

      final manifestMeta = await provider.readManifest();
      final manifest = CloudSyncManifest.fromJson(manifestMeta!.content);
      await provider.deleteFile(manifest.snapshots.last.path);

      final StartupRestoreDiscoveryResult discovery = await harness.cloud
          .discoverStartupRestore(localHasData: false);

      expect(discovery.status, StartupRestoreDiscoveryStatus.restorePrompt);
      expect(discovery.preview, isNotNull);

      await _disposeHarness(harness);
    },
  );

  test(
    'startup auto backup is suppressed until restore discovery resolves',
    () async {
      final harness = await _buildHarness(
        provider: _SlowMockCloudStorageProvider(),
      );

      await harness.cloud.setAutomaticBackupEnabled(true);
      harness.cloud.beginStartupRestoreDiscovery();
      harness.cloud.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final manifest = await harness.provider.readManifest();
      expect(manifest, isNull);

      harness.cloud.completeStartupRestoreDiscovery();

      await _disposeHarness(harness);
    },
  );

  test('backup key recovery failures are non-blocking', () async {
    final harness = await _buildHarness(
      provider: _SlowMockCloudStorageProvider(),
      setupPassphrase: false,
      backupKeyManager: _ThrowingBackupKeyManager(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'test-user', email: 'test@example.com'),
        ),
        firestore: FakeFirebaseFirestore(),
      ),
    );

    await harness.cloud.loadBackupPassphrase();
    expect(harness.cloud.lastBackupError, isEmpty);
    expect(harness.cloud.statusMessage, isNotEmpty);

    await _disposeHarness(harness);
  });

  test(
    'loadBackupPassphrase repairs stale cached passphrase from Firestore',
    () async {
      final harness = await _buildHarness(
        provider: _SlowMockCloudStorageProvider(),
      );

      await harness.appState.secureStorageService.saveBackupPassphrase(
        'stale-passphrase',
        userId: 'test-user',
      );

      await harness.cloud.loadBackupPassphrase();

      final String? restoredPassphrase = await harness
          .appState
          .secureStorageService
          .loadBackupPassphrase(userId: 'test-user');
      final Uint8List? keyBytes = await harness.cloud.backupKeyManager
          .getExistingKey();

      expect(restoredPassphrase, isNotNull);
      expect(restoredPassphrase, equals(base64UrlEncode(keyBytes!)));

      await _disposeHarness(harness);
    },
  );

  test('corrupted backup or checksum mismatch fails restore', () async {
    final provider = _SlowMockCloudStorageProvider();
    final harness = await _buildHarness(provider: provider);

    // Create a valid backup first
    final bool ok = await harness.cloud.backupNow();
    expect(ok, isTrue);

    // Retrieve the manifest and corrupt the latest snapshot's checksum
    final manifestMeta = await provider.readManifest();
    final manifestContent = Map<String, dynamic>.from(manifestMeta!.content);
    final snapshots = List<dynamic>.from(manifestContent['snapshots']);
    final latestSnapshot = Map<String, dynamic>.from(snapshots.last);
    latestSnapshot['checksum'] = 'corrupted_checksum_value';
    snapshots[snapshots.length - 1] = latestSnapshot;
    manifestContent['snapshots'] = snapshots;

    await provider.writeManifest(manifestContent);

    // Trigger restore which should fail due to checksum mismatch
    final bool restoreOk = await harness.cloud.restoreLatestBackup();
    expect(restoreOk, isFalse);
    expect(harness.cloud.lastBackupStatus, contains('checksum does not match'));

    await _disposeHarness(harness);
  });

  test(
    'missing latest snapshot file falls back to the previous valid backup',
    () async {
      final provider = _SlowMockCloudStorageProvider();
      final harness = await _buildHarness(provider: provider);

      await harness.database.customStatement(
        "CREATE TABLE restore_guard (id INTEGER PRIMARY KEY, value TEXT);",
      );
      await harness.database.customStatement(
        "INSERT INTO restore_guard (id, value) VALUES (1, 'before')",
      );
      final bool firstBackup = await harness.cloud.backupNow();
      expect(firstBackup, isTrue);

      await harness.database.customStatement(
        "UPDATE restore_guard SET value = 'after' WHERE id = 1",
      );
      final beforeRestoreRows = await harness.appState.database!
          .customSelect("SELECT value FROM restore_guard WHERE id = 1")
          .get();
      expect(beforeRestoreRows.single.read<String>('value'), equals('after'));

      final bool secondBackup = await harness.cloud.backupNow();
      expect(secondBackup, isTrue);

      final manifestMeta = await provider.readManifest();
      final manifest = CloudSyncManifest.fromJson(manifestMeta!.content);
      final latestPath = manifest.snapshots.last.path;
      await provider.deleteFile(latestPath);

      final bool restoreOk = await harness.cloud.restoreLatestBackup();
      expect(restoreOk, isTrue);

      final restoredRows = await harness.appState.database!
          .customSelect("SELECT value FROM restore_guard WHERE id = 1")
          .get();
      expect(restoredRows.single.read<String>('value'), equals('before'));

      await _disposeHarness(harness);
    },
  );

  test('missing key recovery fails restore gracefully', () async {
    final provider = _SlowMockCloudStorageProvider();
    final harness = await _buildHarness(provider: provider);

    // Create a valid backup
    final bool ok = await harness.cloud.backupNow();
    expect(ok, isTrue);

    // Create a new controller instance without passphrase/key in secure storage
    final harness2 = await _buildHarness(
      provider: provider,
      setupPassphrase: false,
    );

    // Also simulate Firestore missing the recovery key
    // We can simulate missing Firestore metadata by not uploading/deleting it

    final bool restoreOk = await harness2.cloud.restoreLatestBackup();
    expect(restoreOk, isFalse);
    expect(harness2.cloud.lastBackupStatus, contains('passphrase is required'));

    await _disposeHarness(harness);
    await _disposeHarness(harness2);
  });

  test('revoked Drive permission sets isConnected to false', () async {
    final provider = _SlowMockCloudStorageProvider();
    final harness = await _buildHarness(provider: provider);

    // Force drive provider connection probe to return failure due to revoked scope/permission
    provider.connected = false;

    // Refresh state should detect the disconnection
    await harness.cloud.refreshCloudState(evaluatePrompt: false);
    expect(
      harness.cloud.statusMessage,
      contains('Google Drive permission is required for cloud backup'),
    );

    await _disposeHarness(harness);
  });

  test(
    'cross-device restore successfully retrieves database from Device A to Device B',
    () async {
      final provider = _SlowMockCloudStorageProvider();
      final harnessA = await _buildHarness(provider: provider);

      // Device A writes a value to local DB and pushes backup
      await harnessA.database.customStatement(
        "CREATE TABLE device_a_test (id INTEGER PRIMARY KEY);",
      );
      final bool backupOk = await harnessA.cloud.backupNow();
      expect(backupOk, isTrue);

      final keyBytes = await harnessA.cloud.backupKeyManager.getExistingKey();
      expect(keyBytes, isNotNull);

      // Device B has same credentials but starts with a fresh empty database
      final harnessB = await _buildHarness(
        provider: provider,
        setupPassphrase: false,
      );

      // Device B recovers Device A's passphrase key (mocked locally using the same harness config)
      harnessB.cloud.setBackupPassphrase(base64UrlEncode(keyBytes!));

      final bool restoreOk = await harnessB.cloud.restoreLatestBackup();
      expect(restoreOk, isTrue);

      // Verify Device B now has Device A's table
      final tablesList = await harnessB.appState.database!
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='device_a_test';",
          )
          .get();
      expect(tablesList.length, 1);

      await _disposeHarness(harnessA);
      await _disposeHarness(harnessB);
    },
  );

  test(
    'backup retention keeps only the newest 5 snapshots in provider storage',
    () async {
      final provider = _SlowMockCloudStorageProvider();
      final harness = await _buildHarness(provider: provider);

      // Create 6 unique backups
      for (int i = 1; i <= 6; i++) {
        // Force change local database checksum so it doesn't skip
        await harness.database.customStatement(
          "CREATE TABLE test_retention_$i (id INTEGER PRIMARY KEY);",
        );
        final bool ok = await harness.cloud.backupNow();
        expect(ok, isTrue);
      }

      final manifestMeta = await provider.readManifest();
      final manifest = CloudSyncManifest.fromJson(manifestMeta!.content);
      expect(manifest.snapshots.length, 5); // Manifest keeps 5

      // Also check provider has deleted the oldest physical files
      final remoteFiles = await provider.listFiles('snapshots/');
      expect(remoteFiles.length, 5); // Google Drive contains exactly 5 files

      await _disposeHarness(harness);
    },
  );

  test('deleteCloudBackupData removes all remote cloud backups', () async {
    final provider = _SlowMockCloudStorageProvider();
    final harness = await _buildHarness(provider: provider);

    await harness.cloud.backupNow();
    expect(await provider.readManifest(), isNotNull);

    await harness.cloud.deleteCloudBackupData();

    expect(await provider.readManifest(), isNull);
    expect(await provider.listFiles(''), isEmpty);

    await _disposeHarness(harness);
  });
}
