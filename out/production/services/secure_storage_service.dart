import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../main.dart';

import '../core/constants/storage_keys.dart';

class SecureStorageService {
  const SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<List<String>?> loadAiKeys({String? userId}) async {
    if (ZakatApp.isTesting) return null;
    final String key = StorageKeys.aiKeysKeyForUser(userId);
    try {
      final String? raw = await _storage.read(key: key);
      if (raw == null || raw.trim().isEmpty) return null;
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((dynamic item) => item.toString()).toList();
    } on MissingPluginException {
      return null;
    } catch (error, stackTrace) {
      if (_isBindingInitializationError(error)) return null;
      debugPrint('SecureStorageService.loadAiKeys failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> saveAiKeys(List<String> keys, {String? userId}) async {
    if (ZakatApp.isTesting) return;
    final String key = StorageKeys.aiKeysKeyForUser(userId);
    try {
      await _storage.write(key: key, value: jsonEncode(keys));
    } on MissingPluginException {
      // Widget tests and unsupported platforms may not register the plugin.
    } catch (error, stackTrace) {
      if (_isBindingInitializationError(error)) return;
      debugPrint('SecureStorageService.saveAiKeys failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> deleteAiKeys({String? userId}) async {
    if (ZakatApp.isTesting) return;
    final String key = StorageKeys.aiKeysKeyForUser(userId);
    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      // Widget tests and unsupported platforms may not register the plugin.
    } catch (error, stackTrace) {
      if (_isBindingInitializationError(error)) return;
      debugPrint('SecureStorageService.deleteAiKeys failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<String?> loadBackupKey({String? userId}) async {
    if (ZakatApp.isTesting) return null;
    final String key = StorageKeys.backupKeyKeyForUser(userId);
    try {
      return await _storage.read(key: key);
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBackupKey(String keyValue, {String? userId}) async {
    if (ZakatApp.isTesting) return;
    final String key = StorageKeys.backupKeyKeyForUser(userId);
    try {
      await _storage.write(key: key, value: keyValue);
    } on MissingPluginException {
      // Widget tests and unsupported platforms may not register the plugin.
    } catch (_) {}
  }

  Future<void> deleteBackupKey({String? userId}) async {
    if (ZakatApp.isTesting) return;
    final String key = StorageKeys.backupKeyKeyForUser(userId);
    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      // Widget tests and unsupported platforms may not register the plugin.
    } catch (_) {}
  }

  Future<String?> loadBackupPassphrase({String? userId}) async {
    if (ZakatApp.isTesting) return null;
    final String key = 'backup_passphrase_${userId ?? "default"}';
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBackupPassphrase(String passphrase, {String? userId}) async {
    if (ZakatApp.isTesting) return;
    final String key = 'backup_passphrase_${userId ?? "default"}';
    try {
      await _storage.write(key: key, value: passphrase);
    } catch (_) {}
  }

  Future<void> deleteBackupPassphrase({String? userId}) async {
    if (ZakatApp.isTesting) return;
    final String key = 'backup_passphrase_${userId ?? "default"}';
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  bool _isBindingInitializationError(Object error) {
    return error.toString().contains('Binding has not yet been initialized');
  }
}
