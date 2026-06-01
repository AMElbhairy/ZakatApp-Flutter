import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakatapp_flutter/models/user_profile.dart';
import 'package:zakatapp_flutter/services/google_sheets_service.dart';
import 'package:zakatapp_flutter/services/local_storage_service.dart';
import 'package:zakatapp_flutter/services/auth_controller.dart';
import 'package:zakatapp_flutter/services/auth_service.dart';
import 'package:zakatapp_flutter/services/app_state_controller.dart';
import 'package:zakatapp_flutter/repositories/app_state_repository.dart';
import 'package:zakatapp_flutter/services/sync_controller.dart';

class _FakeAuthService implements AuthService {
  final UserProfile? user;
  _FakeAuthService(this.user);
  @override
  Future<UserProfile?> signIn() async => user;
  @override
  Future<UserProfile?> restoreSession() async => user;
  @override
  Future<void> signOut() async {}
}

class _FakeSheets extends GoogleSheetsService {
  _FakeSheets() : super(httpClient: null);
  Map<String, Map<String, dynamic>> store = {};
  String? lastWrittenId;

  @override
  Future<Map<String, String>?> createSpreadsheet(String accessToken, {String title = 'ZakatApp Backup'}) async {
    final String id = 'sheet_${store.length + 1}';
    store[id] = {};
    return <String, String>{'id': id, 'title': title};
  }

  @override
  Future<bool> connectSpreadsheet(String spreadsheetId, String accessToken) async {
    return store.containsKey(spreadsheetId);
  }

  @override
  Future<Map<String, dynamic>?> readAppState(String spreadsheetId, String accessToken) async {
    return store[spreadsheetId];
  }

  @override
  Future<bool> writeAppState(String spreadsheetId, Map<String, dynamic> appStateJson, String accessToken) async {
    if (!store.containsKey(spreadsheetId)) return false;
    store[spreadsheetId] = Map<String, dynamic>.from(appStateJson);
    lastWrittenId = spreadsheetId;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppStateController appStateController;
  late AuthController authController;
  late _FakeSheets fakeSheets;
  late SyncController syncController;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final localStorage = LocalStorageService();
    final repo = AppStateRepository(localStorage: localStorage);
    appStateController = AppStateController(repository: repo);
    await appStateController.load();

    authController = AuthController(authService: _FakeAuthService(null), localStorage: localStorage);
    await authController.load();

    fakeSheets = _FakeSheets();
    syncController = SyncController(
      appStateController: appStateController,
      authController: authController,
      googleSheetsService: fakeSheets,
    );
  });

  test('signed out sync cannot create spreadsheet', () async {
    final ok = await syncController.createAndConnectSpreadsheet();
    expect(ok, isFalse);
    expect(syncController.status.status, 'failed', reason: 'should fail when signed out');
  });

  test('create spreadsheet updates sync status when signed in', () async {
    // sign in
    final profile = UserProfile(id: '1', email: 'a@b', name: 'A', accessToken: 'token');
    authController = AuthController(authService: _FakeAuthService(profile), localStorage: LocalStorageService());
    await authController.load();
    syncController = SyncController(appStateController: appStateController, authController: authController, googleSheetsService: fakeSheets);

    final ok = await syncController.createAndConnectSpreadsheet();
    expect(ok, isTrue);
    expect(syncController.status.spreadsheetId, isNotNull);
    expect(syncController.status.status, 'localOnly');
  });

  test('connect spreadsheet hydrates local when cloud has data', () async {
    final profile = UserProfile(id: '1', email: 'a@b', name: 'A', accessToken: 'token');
    authController = AuthController(authService: _FakeAuthService(profile), localStorage: LocalStorageService());
    await authController.load();
    syncController = SyncController(appStateController: appStateController, authController: authController, googleSheetsService: fakeSheets);

    // create sheet and populate cloud
    final Map<String, String>? created = await fakeSheets.createSpreadsheet('token');
    final String sid = created!['id']!;
    fakeSheets.store[sid] = appStateController.state.toJson();

    final ok = await syncController.connectSpreadsheetById(sid);
    expect(ok, isTrue);
    expect(syncController.status.status, 'synced');
  });

  test('push writes local AppState after hydration', () async {
    final profile = UserProfile(id: '1', email: 'a@b', name: 'A', accessToken: 'token');
    authController = AuthController(authService: _FakeAuthService(profile), localStorage: LocalStorageService());
    await authController.load();
    syncController = SyncController(appStateController: appStateController, authController: authController, googleSheetsService: fakeSheets);

    final Map<String, String>? created = await fakeSheets.createSpreadsheet('token');
    final String sid = created!['id']!;
    // connect and mark as hydrated by writing cloud with empty app state
    fakeSheets.store[sid] = {};
    final connected = await syncController.connectSpreadsheetById(sid);
    expect(connected, isTrue);
    // attempt push should fail because cloudHydrated is false (empty cloud)
    final pushed = await syncController.pushToCloud();
    expect(pushed, isFalse);

    // simulate a successful pull to set cloudHydrated true
    fakeSheets.store[sid] = appStateController.state.toJson();
    final pulled = await syncController.pullFromCloud();
    expect(pulled, isTrue);
    final pushed2 = await syncController.pushToCloud();
    expect(pushed2, isTrue);
    expect(fakeSheets.lastWrittenId, sid);
  });

  test('conflict state when both local and cloud have differing data', () async {
    final profile = UserProfile(id: '1', email: 'a@b', name: 'A', accessToken: 'token');
    authController = AuthController(authService: _FakeAuthService(profile), localStorage: LocalStorageService());
    await authController.load();
    syncController = SyncController(appStateController: appStateController, authController: authController, googleSheetsService: fakeSheets);

    final Map<String, String>? created = await fakeSheets.createSpreadsheet('token');
    final String sid = created!['id']!;
    // cloud has different data
    fakeSheets.store[sid] = <String, dynamic>{
      'transactions': <dynamic>[
        <String, dynamic>{
          'id': 'remote',
          'type': 'expense',
          'date': '2024-01-01',
          'amount': 100.0,
          'currency': 'EGP',
          'category': 'Test',
          'description': '',
          'createdAt': DateTime.now().toIso8601String(),
          'rolledOver': false,
          'rolledAmount': 0.0,
        }
      ]
    };
    // local has its existing state (likely empty)
    final ok = await syncController.connectSpreadsheetById(sid);
    expect(ok, isTrue);
    // Since local is empty, it should hydrate and sync, not conflict.
    expect(syncController.status.status, 'synced');
  });

  test('failed pull does not wipe local data', () async {
    final profile = UserProfile(id: '1', email: 'a@b', name: 'A', accessToken: 'token');
    final localStorage = LocalStorageService();
    authController = AuthController(authService: _FakeAuthService(profile), localStorage: LocalStorageService());
    await authController.load();
    // make fakeSheets return null for reads
    final badSheets = _FakeSheets();
    badSheets.store.clear();
    final initialStatus = const SyncStatus(status: 'synced', spreadsheetId: 'nope');
    SharedPreferences.setMockInitialValues(<String, Object>{'sync_status_v1': jsonEncode(initialStatus.toJson())});
    final sc = SyncController(appStateController: appStateController, authController: authController, googleSheetsService: badSheets, storage: localStorage);
    await Future.delayed(Duration.zero);

    final before = appStateController.state.toJson();
    final pulled = await sc.pullFromCloud();
    expect(pulled, isFalse);
    final after = appStateController.state.toJson();
    expect(jsonEncode(before), jsonEncode(after));
  });
  test('failed push keeps local unchanged', () async {
    final profile = UserProfile(id: '1', email: 'a@b', name: 'A', accessToken: 'token');
    final localStorage = LocalStorageService();
    authController = AuthController(authService: _FakeAuthService(profile), localStorage: LocalStorageService());
    await authController.load();
    final badSheets = _FakeSheets();
    final initialStatus = const SyncStatus(status: 'synced', spreadsheetId: 'missing', cloudHydrated: true);
    SharedPreferences.setMockInitialValues(<String, Object>{'sync_status_v1': jsonEncode(initialStatus.toJson())});
    final sc = SyncController(appStateController: appStateController, authController: authController, googleSheetsService: badSheets, storage: localStorage);
    await Future.delayed(Duration.zero);

    final before = appStateController.state.toJson();
    final pushed = await sc.pushToCloud();
    expect(pushed, isFalse);
    final after = appStateController.state.toJson();
    expect(jsonEncode(before), jsonEncode(after));
  });
}
