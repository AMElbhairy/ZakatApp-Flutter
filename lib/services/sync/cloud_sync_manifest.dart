class EncryptionConfig {
  final String keyDerivation;
  final int iterations;
  final String saltBase64;

  const EncryptionConfig({
    required this.keyDerivation,
    required this.iterations,
    required this.saltBase64,
  });

  Map<String, dynamic> toJson() => {
        'keyDerivation': keyDerivation,
        'iterations': iterations,
        'salt': saltBase64,
      };

  factory EncryptionConfig.fromJson(Map<String, dynamic> json) => EncryptionConfig(
        keyDerivation: json['keyDerivation'] as String? ?? 'PBKDF2',
        iterations: json['iterations'] as int? ?? 100000,
        saltBase64: json['salt'] as String? ?? '',
      );
}

class DeviceMetadata {
  final String deviceId;
  final String deviceName;
  final String platform;
  final String appVersion;
  final DateTime registeredAt;
  final DateTime lastSeenAt;
  final DateTime? lastActive;
  final int latestProcessedSequence;

  const DeviceMetadata({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.registeredAt,
    required this.lastSeenAt,
    this.lastActive,
    required this.latestProcessedSequence,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'appVersion': appVersion,
        'registeredAt': registeredAt.toIso8601String(),
        'lastSeenAt': lastSeenAt.toIso8601String(),
        'lastActive': (lastActive ?? lastSeenAt).toIso8601String(),
        'latestProcessedSequence': latestProcessedSequence,
      };

  factory DeviceMetadata.fromJson(
    Map<String, dynamic> json, {
    String? deviceIdFallback,
  }) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final legacyLastActive = parseDate(json['lastActive']);
    final registeredAt = parseDate(json['registeredAt']) ??
        legacyLastActive ??
        DateTime.now().toUtc();
    final lastSeenAt = parseDate(json['lastSeenAt']) ??
        legacyLastActive ??
        registeredAt;

    return DeviceMetadata(
      deviceId: json['deviceId'] as String? ??
          deviceIdFallback ??
          'unknown-device',
      deviceName: json['deviceName'] as String? ?? 'Unknown',
      platform: json['platform'] as String? ?? 'Unknown',
      appVersion: json['appVersion'] as String? ?? '',
      registeredAt: registeredAt,
      lastSeenAt: lastSeenAt,
      lastActive: legacyLastActive,
      latestProcessedSequence: json['latestProcessedSequence'] as int? ?? 0,
    );
  }
}

class SnapshotEntry {
  final String id;
  final int sequence;
  final String checksum;
  final DateTime createdAt;
  final String path;
  final int globalSequence;
  final String deviceId;
  final String deviceName;
  final int databaseSchemaVersion;
  final String appVersion;

  const SnapshotEntry({
    required this.id,
    required this.sequence,
    required this.checksum,
    required this.createdAt,
    required this.path,
    required this.globalSequence,
    required this.deviceId,
    required this.deviceName,
    required this.databaseSchemaVersion,
    required this.appVersion,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sequence': sequence,
        'checksum': checksum,
        'createdAt': createdAt.toIso8601String(),
        'path': path,
        'globalSequence': globalSequence,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'databaseSchemaVersion': databaseSchemaVersion,
        'appVersion': appVersion,
      };

  factory SnapshotEntry.fromJson(Map<String, dynamic> json) => SnapshotEntry(
        id: json['id'] as String? ?? '',
        sequence: json['sequence'] as int,
        checksum: json['checksum'] as String? ?? '',
        createdAt: DateTime.parse(
          json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        ),
        path: json['path'] as String,
        globalSequence: json['globalSequence'] as int? ?? 0,
        deviceId: json['deviceId'] as String? ?? '',
        deviceName: json['deviceName'] as String? ?? '',
        databaseSchemaVersion: json['databaseSchemaVersion'] as int? ?? 0,
        appVersion: json['appVersion'] as String? ?? '',
      );
}

class CloudSyncManifest {
  final int schemaVersion;
  final int databaseSchemaVersion;
  final int currentSnapshotSequence;
  final List<SnapshotEntry> snapshots;
  final int latestGlobalSequence;
  final DateTime lastMergedAt;
  final EncryptionConfig encryption;
  final Map<String, DeviceMetadata> knownDevices;

  const CloudSyncManifest({
    required this.schemaVersion,
    required this.databaseSchemaVersion,
    required this.currentSnapshotSequence,
    required this.snapshots,
    required this.latestGlobalSequence,
    required this.lastMergedAt,
    required this.encryption,
    required this.knownDevices,
  });

  String? get latestSnapshotPath {
    if (snapshots.isEmpty) return null;
    for (final snapshot in snapshots) {
      if (snapshot.sequence == currentSnapshotSequence) {
        return snapshot.path;
      }
    }
    return snapshots.last.path;
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'databaseSchemaVersion': databaseSchemaVersion,
        'currentSnapshotSequence': currentSnapshotSequence,
        'snapshots': snapshots.map((s) => s.toJson()).toList(),
        'latestGlobalSequence': latestGlobalSequence,
        'lastMergedAt': lastMergedAt.toIso8601String(),
        'encryption': encryption.toJson(),
        'knownDevices': knownDevices.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory CloudSyncManifest.fromJson(Map<String, dynamic> json) {
    final rawDevices = json['knownDevices'] as Map<String, dynamic>? ?? {};
    final devices = <String, DeviceMetadata>{};
    for (final entry in rawDevices.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        final metadata = DeviceMetadata.fromJson(
          value,
          deviceIdFallback: entry.key,
        );
        devices[entry.key] = metadata;
      }
    }

    final rawSnapshots = json['snapshots'] as List<dynamic>? ?? [];
    final snapshotsList = rawSnapshots
        .map((s) => SnapshotEntry.fromJson(s as Map<String, dynamic>))
        .toList();

    return CloudSyncManifest(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      databaseSchemaVersion: json['databaseSchemaVersion'] as int? ?? 1,
      currentSnapshotSequence: json['currentSnapshotSequence'] as int? ??
          json['latestSnapshotSequence'] as int? ??
          0,
      snapshots: snapshotsList,
      latestGlobalSequence: json['latestGlobalSequence'] as int? ?? 0,
      lastMergedAt: DateTime.parse(
        json['lastMergedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      encryption: EncryptionConfig.fromJson(
        json['encryption'] as Map<String, dynamic>? ?? {},
      ),
      knownDevices: devices,
    );
  }
}
