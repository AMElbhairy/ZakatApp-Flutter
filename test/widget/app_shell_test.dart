import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/main.dart';
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
  _FakeAuthService({this.user});

  final UserProfile? user;
  static const UserProfile _defaultUser = UserProfile(
    id: 'test-user',
    email: 'test@example.com',
    displayName: 'Test User',
    provider: 'google',
    accessToken: 'token',
  );

  UserProfile get _effectiveUser => user ?? _defaultUser;

  @override
  Future<bool> ensureSession() async => true;

  @override
  Future<UserProfile?> restoreSession() async => _effectiveUser;

  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) async => _effectiveUser;

  @override
  Future<void> signOut() async {}
}

class _FakeGoogleDriveService extends GoogleDriveService {
  _FakeGoogleDriveService({this.latest});

  DriveBackupFile? latest;

  @override
  Future<DriveBackupFile?> fetchLatestBackup(String accessToken) async =>
      latest;

  @override
  Future<DriveBackupFile?> uploadBackup({
    required String jsonString,
    required String accessToken,
  }) async {
    latest = DriveBackupFile(
      id: 'backup-1',
      name: GoogleDriveService.backupFileName,
      rawJson: jsonString,
      backupCreatedAt: DateTime.now().toUtc(),
      backupUpdatedAt: DateTime.now().toUtc(),
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
    createdAt: '2026-06-02T00:00:00.000Z',
    rolledOver: false,
  );
}

void main() {
  testWidgets('app launches and shell tabs are visible', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository repository = AppStateRepository(
      localStorage: localStorage,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <ChangeNotifierProvider<dynamic>>[
          ChangeNotifierProvider<AppStateController>(
            create: (_) => AppStateController(repository: repository),
          ),
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(
              authService: _FakeAuthService(),
              localStorage: localStorage,
            ),
          ),
        ],
        child: const ZakatApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Assets'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    // Dashboard placeholder title is visible by default.
    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('app still starts with corrupted local state JSON', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zakatAppData': '{not-json',
    });
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository repository = AppStateRepository(
      localStorage: localStorage,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <ChangeNotifierProvider<dynamic>>[
          ChangeNotifierProvider<AppStateController>(
            create: (_) => AppStateController(repository: repository),
          ),
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(
              authService: _FakeAuthService(),
              localStorage: localStorage,
            ),
          ),
        ],
        child: const ZakatApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.byKey(const Key('dashboardEmptyCard')), findsOneWidget);
  });

  testWidgets('system back from a main tab returns to Dashboard', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const LocalStorageService localStorage = LocalStorageService();
    final AppStateRepository repository = AppStateRepository(
      localStorage: localStorage,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <ChangeNotifierProvider<dynamic>>[
          ChangeNotifierProvider<AppStateController>(
            create: (_) => AppStateController(repository: repository),
          ),
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(
              authService: _FakeAuthService(),
              localStorage: localStorage,
            ),
          ),
        ],
        child: const ZakatApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assets').last);
    await tester.pumpAndSettle();
    expect(find.text('TOTAL ASSETS'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardEmptyCard')), findsOneWidget);
  });

  testWidgets(
    'AuthGate does not overwrite local data when a cloud backup exists',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const LocalStorageService localStorage = LocalStorageService();
      final AppStateRepository repository = AppStateRepository(
        localStorage: localStorage,
      );
      final AppStateController appState = AppStateController(
        repository: repository,
      );
      await appState.load();
      await appState.addTransaction(_tx('local-tx'));

      final UserProfile user = const UserProfile(
        id: 'u1',
        email: 'a@example.com',
        displayName: 'User',
        provider: 'google',
        accessToken: 'token',
      );
      final AuthController auth = AuthController(
        authService: _FakeAuthService(user: user),
        localStorage: localStorage,
      );
      await auth.load();

      final Map<String, dynamic> emptyState = <String, dynamic>{
        ...appState.state.toJson(),
        'transactions': <Map<String, dynamic>>[],
        'lastModifiedAt': '2026-06-01T00:00:00.000Z',
      };
      final String rawJson = jsonEncode(<String, dynamic>{
        'appName': 'ZakatApp',
        'schemaVersion': 3,
        'exportedAt': '2026-06-02T00:00:00.000Z',
        'counts': <String, int>{'transactions': 0},
        'appState': emptyState,
        'cloudBackupMetadata': <String, dynamic>{
          'backupVersion': 3,
          'createdAt': '2026-06-01T00:00:00.000Z',
          'updatedAt': '2026-06-02T00:00:00.000Z',
        },
      });
      final CloudBackupController cloud = CloudBackupController(
        appStateController: appState,
        authController: auth,
        googleDriveService: _FakeGoogleDriveService(
          latest: DriveBackupFile(
            id: 'backup-1',
            name: GoogleDriveService.backupFileName,
            rawJson: rawJson,
            backupCreatedAt: DateTime.parse('2026-06-01T00:00:00.000Z'),
            backupUpdatedAt: DateTime.parse('2026-06-02T00:00:00.000Z'),
          ),
        ),
        autoBackupDelay: const Duration(days: 1),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: <ChangeNotifierProvider<dynamic>>[
            ChangeNotifierProvider<AppStateController>(create: (_) => appState),
            ChangeNotifierProvider<AuthController>(create: (_) => auth),
            ChangeNotifierProvider<CloudBackupController>(create: (_) => cloud),
          ],
          child: const ZakatApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(appState.state.transactions, hasLength(1));
      expect(appState.state.transactions.single.id, 'local-tx');
      expect(find.text('Dashboard'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
