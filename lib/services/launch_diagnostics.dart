import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'sync_diagnostics_service.dart';

class LaunchDiagnostics {
  LaunchDiagnostics._();

  static String launchId = const Uuid().v4();
  static String launchSource = 'app_icon';

  static void setLaunchSource(String source) {
    final String trimmed = source.trim();
    if (trimmed.isEmpty) return;
    launchSource = trimmed;
  }

  static String fingerprint(String? input) {
    final List<int> bytes = utf8.encode((input ?? '').trim());
    const int offset = 0xcbf29ce484222325;
    const int prime = 0x100000001b3;
    int hash = offset;
    for (final int byte in bytes) {
      hash ^= byte;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }

  static Future<void> record(
    String message, {
    String level = 'info',
    String subsystem = 'startup',
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return SyncDiagnosticsService.record(
      level: level,
      subsystem: subsystem,
      message: message,
      metadata: <String, dynamic>{
        'launchId': launchId,
        'launchSource': launchSource,
        ...metadata,
      },
    );
  }
}
