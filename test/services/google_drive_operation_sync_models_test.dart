import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/services/sync/google_drive_operation_sync_models.dart';

void main() {
  test('Cloud operation and manifest models round-trip through JSON', () {
    final CloudOperation op = CloudOperation(
      opId: 'op-1',
      deviceId: 'device-a',
      localSequence: 7,
      createdAt: DateTime.parse('2026-06-23T10:00:00Z'),
      domain: 'transactions',
      recordId: 'tx-1',
      operation: 'upsert',
      schemaVersion: 1,
      checksum: 'checksum-1',
      keyVersion: 1,
      payload: <String, dynamic>{'id': 'tx-1', 'amount': 42},
      activityId: 'activity-1',
    );

    final CloudOperationBatch batch = CloudOperationBatch(
      batchId: 'batch-1',
      deviceId: 'device-a',
      sequence: 99,
      createdAt: DateTime.parse('2026-06-23T10:01:00Z'),
      schemaVersion: 1,
      checksum: 'checksum-batch',
      keyVersion: 1,
      fileType: 'operation_log',
      operations: <CloudOperation>[op],
      latestSnapshotSequence: 12,
    );

    final DeviceSyncCheckpoint checkpoint = DeviceSyncCheckpoint(
      deviceId: 'device-a',
      deviceName: 'Device A',
      appVersion: '1.0.0',
      lastUploadedSequence: 99,
      lastAppliedSequence: 99,
      lastUploadedAt: DateTime.parse('2026-06-23T10:01:00Z'),
      lastAppliedAt: DateTime.parse('2026-06-23T10:02:00Z'),
    );

    final OperationSyncManifestState manifest = OperationSyncManifestState(
      schemaVersion: 1,
      latestSnapshotSequence: 12,
      latestLogSequenceByDevice: <String, int>{'device-a': 99},
      knownDevices: <String, DeviceSyncCheckpoint>{'device-a': checkpoint},
      logRetentionCount: 25,
      updatedAt: DateTime.parse('2026-06-23T10:03:00Z'),
    );

    final CloudOperation decodedOp = CloudOperation.fromJson(op.toJson());
    final CloudOperationBatch decodedBatch =
        CloudOperationBatch.fromJson(batch.toJson());
    final OperationSyncManifestState decodedManifest =
        OperationSyncManifestState.fromJson(manifest.toJson());

    expect(decodedOp.opId, op.opId);
    expect(decodedOp.payload, op.payload);
    expect(decodedBatch.batchId, batch.batchId);
    expect(decodedBatch.operations.single.recordId, op.recordId);
    expect(decodedManifest.latestSnapshotSequence, 12);
    expect(decodedManifest.knownDevices['device-a']!.deviceName, 'Device A');
    expect(decodedManifest.latestLogSequenceByDevice['device-a'], 99);
  });
}
