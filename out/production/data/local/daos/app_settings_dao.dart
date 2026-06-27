import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';

class AppSettingsDao extends DatabaseAccessor<AppDatabase> {
  AppSettingsDao(super.db);

  Future<String?> getRaw(String key) async {
    final AppSetting? row = await (select(attachedDatabase.appSettings)
          ..where((tbl) => tbl.key.equals(key)))
        .getSingleOrNull();
    return row?.valueJson;
  }

  Future<void> setRaw(String key, String valueJson) {
    return into(attachedDatabase.appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: key,
        valueJson: valueJson,
        updatedAt: _timestampNow(),
      ),
    );
  }

  Future<T?> getJson<T>(String key) async {
    final String? raw = await getRaw(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      return _coerceValue<T>(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> setJson(String key, Object value) {
    return setRaw(key, jsonEncode(value));
  }

  Future<Map<String, dynamic>> getAllSettings() async {
    final List<AppSetting> rows = await select(attachedDatabase.appSettings).get();
    final Map<String, dynamic> values = <String, dynamic>{};
    for (final AppSetting row in rows) {
      values[row.key] = _decodeValue(row.valueJson);
    }
    return values;
  }

  Future<void> importSettings(Map<String, dynamic> values) async {
    if (values.isEmpty) return;
    await batch((Batch batch) {
      batch.insertAllOnConflictUpdate(
        attachedDatabase.appSettings,
        values.entries
            .map(
              (MapEntry<String, dynamic> entry) => AppSettingsCompanion.insert(
                key: entry.key,
                valueJson: jsonEncode(entry.value),
                updatedAt: _timestampNow(),
              ),
            )
            .toList(growable: false),
      );
    });
  }

  dynamic _decodeValue(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  T? _coerceValue<T>(dynamic decoded) {
    if (decoded == null) return null;
    if (decoded is T) return decoded;
    if (decoded is String && T == String) return decoded as T;
    if (decoded is List && T.toString().startsWith('List<')) {
      if (decoded.every((dynamic item) => item is String)) {
        return List<String>.from(decoded) as T;
      }
      if (decoded.every((dynamic item) => item is num)) {
        return List<num>.from(decoded) as T;
      }
      return decoded as T;
    }
    if (decoded is Map && T.toString().startsWith('Map<')) {
      return Map<String, dynamic>.from(decoded) as T;
    }
    return decoded as T;
  }

  String _timestampNow() => DateTime.now().toUtc().toIso8601String();
}
