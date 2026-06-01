import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/sync_status.dart';
import '../models/app_state.dart';
import 'google_sheets_service.dart';
import 'local_storage_service.dart';
import 'auth_controller.dart';
import 'app_state_controller.dart';

class SyncController extends ChangeNotifier {
  SyncController({
    required this.appStateController,
    required this.authController,
    required this.googleSheetsService,
    LocalStorageService? storage,
  }) : _storage = storage ?? const LocalStorageService() {
    _loadStatus();
  }

  final AppStateController appStateController;
  final AuthController authController;
  final GoogleSheetsService googleSheetsService;
  final LocalStorageService _storage;

  static const String _storageKey = 'sync_status_v1';

  SyncStatus _status = const SyncStatus(status: 'localOnly');
  SyncStatus get status => _status;

  Future<void> _loadStatus() async {
    final String? raw = await _storage.loadString(_storageKey);
    if (raw == null) return;
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      _status = SyncStatus.fromJson(json);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveStatus() async {
    await _storage.saveString(_storageKey, jsonEncode(_status.toJson()));
    notifyListeners();
  }

  Future<bool> createAndConnectSpreadsheet() async {
    final String? token = authController.currentUser?.accessToken;
    if (token == null) return false;
    _status = _status.copyWith(status: 'syncing');
    await _saveStatus();
    try {
      final Map<String, String>? created = await googleSheetsService.createSpreadsheet(token);
      if (created == null) {
        _status = _status.copyWith(status: 'failed', lastError: 'create_failed');
        await _saveStatus();
        return false;
      }
      _status = _status.copyWith(
        status: 'localOnly',
        spreadsheetId: created['id'],
        spreadsheetName: created['title'],
        cloudHydrated: false,
      );
      await _saveStatus();
      return true;
    } catch (error) {
      debugPrint('SyncController.createAndConnectSpreadsheet: $error');
      _status = _status.copyWith(status: 'failed', lastError: error.toString());
      await _saveStatus();
      return false;
    }
  }

  Future<bool> connectSpreadsheetById(String spreadsheetId) async {
    final String? token = authController.currentUser?.accessToken;
    if (token == null) return false;
    _status = _status.copyWith(status: 'syncing');
    await _saveStatus();
    try {
      final bool ok = await googleSheetsService.connectSpreadsheet(spreadsheetId, token);
      if (!ok) {
        _status = _status.copyWith(status: 'failed', lastError: 'access_denied');
        await _saveStatus();
        return false;
      }

      // Try to read cloud state
      final Map<String, dynamic>? cloud = await googleSheetsService.readAppState(spreadsheetId, token);
      final Map<String, dynamic> local = appStateController.state.toJson();

      if (cloud != null && cloud.isNotEmpty) {
        // Cloud has data
        if (_isAppStateEmpty(local)) {
          // Local empty -> hydrate
          final AppStateModel newState = AppStateModel.fromJson(cloud);
          await appStateController.updateState(newState);
          _status = _status.copyWith(status: 'synced', spreadsheetId: spreadsheetId, cloudHydrated: true, lastSyncAt: DateTime.now().toUtc().toIso8601String());
          await _saveStatus();
          return true;
        }
        // Both have data -> conflict
        if (!_deepEquals(local, cloud)) {
          _status = _status.copyWith(status: 'conflict', spreadsheetId: spreadsheetId, cloudHydrated: true);
          await _saveStatus();
          return true;
        }
        // identical
        _status = _status.copyWith(status: 'synced', spreadsheetId: spreadsheetId, cloudHydrated: true, lastSyncAt: DateTime.now().toUtc().toIso8601String());
        await _saveStatus();
        return true;
      }

      // Cloud empty
      _status = _status.copyWith(status: 'localOnly', spreadsheetId: spreadsheetId, cloudHydrated: false);
      await _saveStatus();
      return true;
    } catch (error) {
      debugPrint('SyncController.connectSpreadsheetById: $error');
      _status = _status.copyWith(status: 'failed', lastError: error.toString());
      await _saveStatus();
      return false;
    }
  }

  Future<bool> pullFromCloud() async {
    final String? token = authController.currentUser?.accessToken;
    final String? sid = _status.spreadsheetId;
    if (token == null || sid == null) return false;
    _status = _status.copyWith(status: 'syncing');
    await _saveStatus();
    try {
      final Map<String, dynamic>? cloud = await googleSheetsService.readAppState(sid, token);
      if (cloud == null) {
        _status = _status.copyWith(status: 'failed', lastError: 'pull_failed');
        await _saveStatus();
        return false;
      }
      final AppStateModel newState = AppStateModel.fromJson(cloud);
      await appStateController.updateState(newState);
      _status = _status.copyWith(status: 'synced', cloudHydrated: true, lastSyncAt: DateTime.now().toUtc().toIso8601String());
      await _saveStatus();
      return true;
    } catch (error) {
      debugPrint('SyncController.pullFromCloud: $error');
      _status = _status.copyWith(status: 'failed', lastError: error.toString());
      await _saveStatus();
      return false;
    }
  }

  Future<bool> pushToCloud() async {
    final String? token = authController.currentUser?.accessToken;
    final String? sid = _status.spreadsheetId;
    if (token == null || sid == null) return false;
    // Safety: do not push before first successful pull/cloud hydration
    if (!_status.cloudHydrated) {
      _status = _status.copyWith(status: 'needsPull', lastError: 'cloud_not_hydrated');
      await _saveStatus();
      return false;
    }
    _status = _status.copyWith(status: 'syncing');
    await _saveStatus();
    try {
      final Map<String, dynamic> payload = appStateController.state.toJson();
      final bool ok = await googleSheetsService.writeAppState(sid, payload, token);
      if (!ok) {
        _status = _status.copyWith(status: 'failed', lastError: 'push_failed');
        await _saveStatus();
        return false;
      }
      _status = _status.copyWith(status: 'synced', lastSyncAt: DateTime.now().toUtc().toIso8601String());
      await _saveStatus();
      return true;
    } catch (error) {
      debugPrint('SyncController.pushToCloud: $error');
      _status = _status.copyWith(status: 'failed', lastError: error.toString());
      await _saveStatus();
      return false;
    }
  }

  Future<bool> syncNow() async {
    // Attempt pull first
    final bool pulled = await pullFromCloud();
    if (!pulled) return false;
    // After successful pull, push local changes (if any) to cloud
    return await pushToCloud();
  }

  static bool _isAppStateEmpty(Map<String, dynamic> raw) {
    // Consider empty if transactions/savings/etc are empty lists and default fields are defaults
    final List<dynamic> tx = raw['transactions'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> sv = raw['savings'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> inv = raw['investments'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> plans = raw['financialPlans'] as List<dynamic>? ?? <dynamic>[];
    return tx.isEmpty && sv.isEmpty && inv.isEmpty && plans.isEmpty;
  }

  static bool _deepEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    return jsonEncode(a) == jsonEncode(b);
  }
}
