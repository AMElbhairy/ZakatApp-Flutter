import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SyncDiagnosticsLogEntry {
  const SyncDiagnosticsLogEntry({
    required this.timestamp,
    required this.level,
    required this.subsystem,
    required this.message,
    required this.metadata,
  });

  final String timestamp;
  final String level;
  final String subsystem;
  final String message;
  final Map<String, dynamic> metadata;

  factory SyncDiagnosticsLogEntry.fromJson(Map<String, dynamic> json) {
    return SyncDiagnosticsLogEntry(
      timestamp: (json['timestamp'] ?? '').toString(),
      level: (json['level'] ?? 'info').toString(),
      subsystem: (json['subsystem'] ?? 'sync').toString(),
      message: (json['message'] ?? '').toString(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'timestamp': timestamp,
      'level': level,
      'subsystem': subsystem,
      'message': message,
      'metadata': metadata,
    };
  }
}

class SyncDiagnosticsService {
  SyncDiagnosticsService._();

  static const int maxLogEntries = 240;
  static const String _logsKey = 'debug_sync_logs_v1';
  static const String _stateKey = 'debug_sync_state_v1';

  static Future<void> record({
    required String level,
    required String subsystem,
    required String message,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<SyncDiagnosticsLogEntry> logs = await readLogs(
        prefs: prefs,
        limit: maxLogEntries - 1,
      );
      logs.add(
        SyncDiagnosticsLogEntry(
          timestamp: DateTime.now().toUtc().toIso8601String(),
          level: level,
          subsystem: subsystem,
          message: message,
          metadata: _redactMap(metadata),
        ),
      );
      final List<Map<String, dynamic>> encoded = logs
          .skip(logs.length > maxLogEntries ? logs.length - maxLogEntries : 0)
          .map((SyncDiagnosticsLogEntry entry) => entry.toJson())
          .toList(growable: false);
      await prefs.setString(_logsKey, jsonEncode(encoded));
    } catch (_) {}
  }

  static Future<List<SyncDiagnosticsLogEntry>> readLogs({
    int limit = maxLogEntries,
    SharedPreferences? prefs,
  }) async {
    final SharedPreferences resolvedPrefs =
        prefs ?? await SharedPreferences.getInstance();
    final String raw = resolvedPrefs.getString(_logsKey) ?? '';
    if (raw.trim().isEmpty) return <SyncDiagnosticsLogEntry>[];
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<SyncDiagnosticsLogEntry> logs = decoded
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> item) => SyncDiagnosticsLogEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
      if (logs.length <= limit) return logs;
      return logs.sublist(logs.length - limit);
    } catch (_) {
      return <SyncDiagnosticsLogEntry>[];
    }
  }

  static Future<void> clear() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logsKey);
      await prefs.remove(_stateKey);
    } catch (_) {}
  }

  static Future<void> recordSavingsQueueInsert({
    required String entityId,
    required String assetType,
    required int queueId,
    String? payloadJson,
  }) async {
    await record(
      level: 'info',
      subsystem: 'queue',
      message: 'Savings queue insert',
      metadata: <String, dynamic>{
        'entityType': 'savings',
        'entityId': entityId,
        'assetType': assetType,
        'queueId': queueId,
        'payload': payloadJson,
      },
    );
  }

  static Future<void> recordSavingsFirestoreAttempt({
    required String documentPath,
    required String documentId,
    required String savingsId,
    required String assetType,
    required String payloadJson,
  }) async {
    try {
      await _writeState(
        <String, dynamic>{
          'lastSavingsPayload': payloadJson,
          'lastSavingsWritePath': documentPath,
          'lastSavingsWriteDocumentId': documentId,
        },
      );
      await record(
        level: 'info',
        subsystem: 'firebase',
        message: 'Savings write attempt',
        metadata: <String, dynamic>{
          'collection': 'savings',
          'documentPath': documentPath,
          'documentId': documentId,
          'savingsId': savingsId,
          'assetType': assetType,
          'payload': payloadJson,
        },
      );
    } catch (_) {}
  }

  static Future<void> recordSavingsFirestoreSuccess({
    required String documentPath,
    required String documentId,
    required String savingsId,
    required String assetType,
    required String payloadJson,
  }) async {
    try {
      await _writeState(
        <String, dynamic>{
          'lastSavingsResponse': 'success',
          'lastSavingsError': '',
          'lastSavingsPayload': payloadJson,
          'lastSavingsWritePath': documentPath,
          'lastSavingsWriteDocumentId': documentId,
        },
      );
      await record(
        level: 'info',
        subsystem: 'firebase',
        message: 'Savings write success',
        metadata: <String, dynamic>{
          'collection': 'savings',
          'documentPath': documentPath,
          'documentId': documentId,
          'savingsId': savingsId,
          'assetType': assetType,
        },
      );
    } catch (_) {}
  }

  static Future<void> recordSavingsFirestoreFailure({
    required String documentPath,
    required String documentId,
    required String savingsId,
    required String assetType,
    required String payloadJson,
    required Object error,
  }) async {
    try {
      await _writeState(
        <String, dynamic>{
          'lastSavingsResponse': '',
          'lastSavingsError': error.toString(),
          'lastSavingsPayload': payloadJson,
          'lastSavingsWritePath': documentPath,
          'lastSavingsWriteDocumentId': documentId,
        },
      );
      await record(
        level: 'error',
        subsystem: 'firebase',
        message: 'Savings write failure',
        metadata: <String, dynamic>{
          'collection': 'savings',
          'documentPath': documentPath,
          'documentId': documentId,
          'savingsId': savingsId,
          'assetType': assetType,
          'error': error.toString(),
          'payload': payloadJson,
        },
      );
    } catch (_) {}
  }

  static Future<void> recordFirebasePullResult({
    required String collection,
    required String path,
    required int upserts,
    required int deletes,
    required String cursor,
  }) async {
    try {
      await record(
        level: 'info',
        subsystem: 'firebase',
        message: 'Pull result',
        metadata: <String, dynamic>{
          'collection': collection,
          'path': path,
          'upserts': upserts,
          'deletes': deletes,
          'cursor': cursor,
        },
      );
    } catch (_) {}
  }

  static Future<void> recordSkippedRecord({
    required String subsystem,
    required String reason,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    try {
      await record(
        level: 'warning',
        subsystem: subsystem,
        message: 'Skipped record',
        metadata: <String, dynamic>{...metadata, 'reason': reason},
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> readState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(_stateKey) ?? '';
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _writeState(Map<String, dynamic> updates) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> state = await readState();
    state.addAll(_redactMap(updates));
    await prefs.setString(_stateKey, jsonEncode(state));
  }

  static Map<String, dynamic> _redactMap(Map<String, dynamic> input) {
    return input.map(
      (String key, dynamic value) => MapEntry<String, dynamic>(
        key,
        _redactValue(key, value),
      ),
    );
  }

  static dynamic _redactValue(String key, dynamic value) {
    final String lower = key.toLowerCase();
    if (lower.contains('token') ||
        lower.contains('secret') ||
        lower.contains('password') ||
        lower.contains('apikey') ||
        lower.contains('api_key')) {
      return '<redacted>';
    }
    if (value is Map) {
      return value.map(
        (dynamic nestedKey, dynamic nestedValue) => MapEntry<dynamic, dynamic>(
          nestedKey,
          _redactValue(nestedKey.toString(), nestedValue),
        ),
      );
    }
    if (value is Iterable) {
      return value
          .map((dynamic item) => _redactValue(key, item))
          .toList(growable: false);
    }
    return value;
  }
}
