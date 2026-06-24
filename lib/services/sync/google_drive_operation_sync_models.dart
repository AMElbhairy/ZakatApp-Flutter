import 'dart:convert';

enum GoogleDriveOperationSyncStatus {
  off,
  idle,
  syncing,
  conflict,
  error,
}

class CloudOperation {
  const CloudOperation({
    required this.opId,
    required this.deviceId,
    required this.localSequence,
    required this.createdAt,
    required this.domain,
    required this.recordId,
    required this.operation,
    required this.schemaVersion,
    required this.checksum,
    required this.keyVersion,
    this.payload,
    this.activityId,
  });

  final String opId;
  final String deviceId;
  final int localSequence;
  final DateTime createdAt;
  final String domain;
  final String recordId;
  final String operation;
  final int schemaVersion;
  final String checksum;
  final int keyVersion;
  final Map<String, dynamic>? payload;
  final String? activityId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'opId': opId,
        'deviceId': deviceId,
        'localSequence': localSequence,
        'createdAt': createdAt.toIso8601String(),
        'domain': domain,
        'recordId': recordId,
        'operation': operation,
        'schemaVersion': schemaVersion,
        'checksum': checksum,
        'fileType': 'operation_log',
        'keyVersion': keyVersion,
        if (payload != null) 'payload': payload,
        if (activityId != null) 'activityId': activityId,
      };

  factory CloudOperation.fromJson(Map<String, dynamic> json) {
    return CloudOperation(
      opId: (json['opId'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? '').toString(),
      localSequence: json['localSequence'] as int? ?? 0,
      createdAt: DateTime.parse(
        (json['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
      ),
      domain: (json['domain'] ?? '').toString(),
      recordId: (json['recordId'] ?? '').toString(),
      operation: (json['operation'] ?? '').toString(),
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      checksum: (json['checksum'] ?? '').toString(),
      keyVersion: json['keyVersion'] as int? ?? 1,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : null,
      activityId: json['activityId']?.toString(),
    );
  }
}

class CloudOperationBatch {
  const CloudOperationBatch({
    required this.batchId,
    required this.deviceId,
    required this.sequence,
    required this.createdAt,
    required this.schemaVersion,
    required this.checksum,
    required this.operations,
    required this.keyVersion,
    required this.fileType,
    this.latestSnapshotSequence = 0,
  });

  final String batchId;
  final String deviceId;
  final int sequence;
  final DateTime createdAt;
  final int schemaVersion;
  final String checksum;
  final List<CloudOperation> operations;
  final int keyVersion;
  final String fileType;
  final int latestSnapshotSequence;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'batchId': batchId,
        'deviceId': deviceId,
        'sequence': sequence,
        'createdAt': createdAt.toIso8601String(),
        'schemaVersion': schemaVersion,
        'checksum': checksum,
        'fileType': fileType,
        'keyVersion': keyVersion,
        'latestSnapshotSequence': latestSnapshotSequence,
        'operations': operations.map((CloudOperation op) => op.toJson()).toList(
              growable: false,
            ),
      };

  factory CloudOperationBatch.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawOps = json['operations'] as List<dynamic>? ?? <dynamic>[];
    return CloudOperationBatch(
      batchId: (json['batchId'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? '').toString(),
      sequence: json['sequence'] as int? ?? 0,
      createdAt: DateTime.parse(
        (json['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
      ),
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      checksum: (json['checksum'] ?? '').toString(),
      keyVersion: json['keyVersion'] as int? ?? 1,
      fileType: (json['fileType'] ?? '').toString(),
      latestSnapshotSequence: json['latestSnapshotSequence'] as int? ?? 0,
      operations: rawOps
          .whereType<Map>()
          .map((Map<dynamic, dynamic> item) =>
              CloudOperation.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }
}

class DeviceSyncCheckpoint {
  const DeviceSyncCheckpoint({
    required this.deviceId,
    required this.deviceName,
    required this.appVersion,
    required this.lastUploadedSequence,
    required this.lastAppliedSequence,
    required this.lastUploadedAt,
    required this.lastAppliedAt,
  });

  final String deviceId;
  final String deviceName;
  final String appVersion;
  final int lastUploadedSequence;
  final int lastAppliedSequence;
  final DateTime? lastUploadedAt;
  final DateTime? lastAppliedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'deviceId': deviceId,
        'deviceName': deviceName,
        'appVersion': appVersion,
        'lastUploadedSequence': lastUploadedSequence,
        'lastAppliedSequence': lastAppliedSequence,
        if (lastUploadedAt != null) 'lastUploadedAt': lastUploadedAt!.toIso8601String(),
        if (lastAppliedAt != null) 'lastAppliedAt': lastAppliedAt!.toIso8601String(),
      };

  factory DeviceSyncCheckpoint.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      final String raw = value?.toString() ?? '';
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return DeviceSyncCheckpoint(
      deviceId: (json['deviceId'] ?? '').toString(),
      deviceName: (json['deviceName'] ?? '').toString(),
      appVersion: (json['appVersion'] ?? '').toString(),
      lastUploadedSequence: json['lastUploadedSequence'] as int? ?? 0,
      lastAppliedSequence: json['lastAppliedSequence'] as int? ?? 0,
      lastUploadedAt: parseDate(json['lastUploadedAt']),
      lastAppliedAt: parseDate(json['lastAppliedAt']),
    );
  }
}

class OperationSyncManifestState {
  const OperationSyncManifestState({
    required this.schemaVersion,
    required this.latestSnapshotSequence,
    required this.latestLogSequenceByDevice,
    required this.knownDevices,
    required this.logRetentionCount,
    required this.updatedAt,
  });

  final int schemaVersion;
  final int latestSnapshotSequence;
  final Map<String, int> latestLogSequenceByDevice;
  final Map<String, DeviceSyncCheckpoint> knownDevices;
  final int logRetentionCount;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'latestSnapshotSequence': latestSnapshotSequence,
        'latestLogSequenceByDevice': latestLogSequenceByDevice,
        'knownDevices': knownDevices.map(
          (String key, DeviceSyncCheckpoint value) =>
              MapEntry<String, dynamic>(key, value.toJson()),
        ),
        'logRetentionCount': logRetentionCount,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory OperationSyncManifestState.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawDevices =
        json['knownDevices'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['knownDevices'] as Map)
            : <String, dynamic>{};
    final Map<String, DeviceSyncCheckpoint> devices =
        <String, DeviceSyncCheckpoint>{};
    for (final MapEntry<String, dynamic> entry in rawDevices.entries) {
      if (entry.value is Map<String, dynamic>) {
        devices[entry.key] = DeviceSyncCheckpoint.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }

    final Map<String, dynamic> rawSequences =
        json['latestLogSequenceByDevice'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['latestLogSequenceByDevice'] as Map)
            : <String, dynamic>{};
    final Map<String, int> sequences = <String, int>{
      for (final MapEntry<String, dynamic> entry in rawSequences.entries)
        entry.key:
            entry.value as int? ?? int.tryParse(entry.value.toString()) ?? 0,
    };

    return OperationSyncManifestState(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      latestSnapshotSequence: json['latestSnapshotSequence'] as int? ?? 0,
      latestLogSequenceByDevice: sequences,
      knownDevices: devices,
      logRetentionCount: json['logRetentionCount'] as int? ?? 50,
      updatedAt: DateTime.parse(
        (json['updatedAt'] ?? DateTime.now().toIso8601String()).toString(),
      ),
    );
  }

  OperationSyncManifestState copyWith({
    int? schemaVersion,
    int? latestSnapshotSequence,
    Map<String, int>? latestLogSequenceByDevice,
    Map<String, DeviceSyncCheckpoint>? knownDevices,
    int? logRetentionCount,
    DateTime? updatedAt,
  }) {
    return OperationSyncManifestState(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      latestSnapshotSequence:
          latestSnapshotSequence ?? this.latestSnapshotSequence,
      latestLogSequenceByDevice:
          latestLogSequenceByDevice ?? this.latestLogSequenceByDevice,
      knownDevices: knownDevices ?? this.knownDevices,
      logRetentionCount: logRetentionCount ?? this.logRetentionCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static OperationSyncManifestState initial({
    int latestSnapshotSequence = 0,
  }) {
    return OperationSyncManifestState(
      schemaVersion: 1,
      latestSnapshotSequence: latestSnapshotSequence,
      latestLogSequenceByDevice: <String, int>{},
      knownDevices: <String, DeviceSyncCheckpoint>{},
      logRetentionCount: 50,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}

class OperationSyncResult {
  const OperationSyncResult({
    required this.status,
    required this.message,
    this.uploadedCount = 0,
    this.appliedCount = 0,
    this.skippedCount = 0,
    this.manifest,
  });

  final GoogleDriveOperationSyncStatus status;
  final String message;
  final int uploadedCount;
  final int appliedCount;
  final int skippedCount;
  final OperationSyncManifestState? manifest;
}

String encodeCanonicalJson(Map<String, dynamic> json) {
  return jsonEncode(json);
}
