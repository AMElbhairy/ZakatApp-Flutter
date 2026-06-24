import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:uuid/uuid.dart';

import '../../data/local/app_database.dart';
import '../../data/local/daos/sync_metadata_dao.dart';
import '../../data/local/daos/sync_queue_dao.dart';
import '../../data/repositories/local_app_settings_repository.dart';
import '../../data/repositories/local_correction_feedback_repository.dart';
import '../../data/repositories/local_financial_plans_repository.dart';
import '../../data/repositories/local_investments_repository.dart';
import '../../data/repositories/local_merchant_confirmations_repository.dart';
import '../../data/repositories/local_merchant_rules_repository.dart';
import '../../data/repositories/local_recurring_transactions_repository.dart';
import '../../models/correction_feedback.dart' as model;
import '../../models/financial_plan.dart' as model;
import '../../models/investment_asset.dart' as model;
import '../../models/merchant_confirmation.dart' as model;
import '../../models/merchant_rule.dart' as model;
import '../../models/recurring_transaction.dart' as model;
import '../../models/saving.dart' as model;
import '../../models/transaction.dart' as model;
import '../../services/app_state_controller.dart';
import 'cloud_sync_manifest.dart';
import 'google_drive_operation_sync_models.dart';
import 'sync_encryption_service.dart';
import 'user_cloud_storage_provider.dart';

export 'google_drive_operation_sync_models.dart';

class GoogleDriveOperationSyncManager {
  GoogleDriveOperationSyncManager({
    required this.provider,
    required this.encryptionService,
    required this.syncQueueDao,
    required this.syncMetadataDao,
    required this.controller,
    required this.deviceId,
    required this.deviceName,
    required this.appVersion,
  });

  final UserCloudStorageProvider provider;
  final SyncEncryptionService encryptionService;
  final SyncQueueDao syncQueueDao;
  final SyncMetadataDao syncMetadataDao;
  final AppStateController controller;
  final String deviceId;
  final String deviceName;
  final String appVersion;

  static const String _manifestPath = 'operation_sync_manifest.json';
  static const String _checkpointKey = 'google_drive_operation_sync_checkpoint';
  static const String _lastUploadedKey =
      'google_drive_operation_sync_last_uploaded_sequence';
  static String _lastAppliedKeyFor(String deviceId) =>
      'google_drive_operation_sync_last_applied_$deviceId';
  static const int _batchLimit = 50;

  Future<OperationSyncResult> syncNow({
    required String passphrase,
    bool pushOnly = false,
  }) async {
    final OperationSyncManifestState manifest = await _loadManifest();
    final int snapshotSequence = await _readSnapshotSequence();
    final OperationSyncManifestState manifestWithSnapshot = manifest.copyWith(
      latestSnapshotSequence: snapshotSequence,
      knownDevices: _mergedKnownDevices(manifest, snapshotSequence),
      updatedAt: DateTime.now().toUtc(),
    );
    final List<int> salt = await _readEncryptionSalt(passphrase);

    int uploaded = 0;
    try {
      uploaded = await _pushQueuedOperations(
        passphrase: passphrase,
        salt: salt,
        manifest: manifestWithSnapshot,
      );
    } catch (error) {
      return OperationSyncResult(
        status: GoogleDriveOperationSyncStatus.error,
        message: error.toString(),
      );
    }

    if (pushOnly) {
      return OperationSyncResult(
        status: GoogleDriveOperationSyncStatus.idle,
        message: uploaded > 0
            ? 'Uploaded $uploaded operation batch(es).'
            : 'No pending operations.',
        uploadedCount: uploaded,
        skippedCount: 0,
        manifest: manifestWithSnapshot,
      );
    }

    try {
      final OperationSyncApplyOutcome outcome = await _pullRemoteOperations(
        passphrase: passphrase,
        salt: salt,
        manifest: manifestWithSnapshot,
      );
      final OperationSyncManifestState refreshed = await _loadManifest();
      return OperationSyncResult(
        status: GoogleDriveOperationSyncStatus.idle,
        message: _formatSyncMessage(
          uploaded: uploaded,
          applied: outcome.appliedCount,
          skipped: outcome.skippedCount,
        ),
        uploadedCount: uploaded,
        appliedCount: outcome.appliedCount,
        skippedCount: outcome.skippedCount,
        manifest: refreshed,
      );
    } catch (error) {
      return OperationSyncResult(
        status: GoogleDriveOperationSyncStatus.error,
        message: error.toString(),
        uploadedCount: uploaded,
        skippedCount: 0,
        manifest: manifestWithSnapshot,
      );
    }
  }

  Future<int> pendingOperationCount() {
    return syncQueueDao.countQueued();
  }

  Future<DeviceSyncCheckpoint?> loadLocalCheckpoint() async {
    final String? raw = await syncMetadataDao.getValue(_checkpointKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      return DeviceSyncCheckpoint.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLocalCheckpoint() {
    return syncMetadataDao.setValue(_checkpointKey, '');
  }

  Future<OperationSyncManifestState> _loadManifest() async {
    final CloudFileInfo? file = await _findFile(_manifestPath);
    if (file == null) {
      return OperationSyncManifestState.initial(
        latestSnapshotSequence: await _readSnapshotSequence(),
      );
    }
    final Uint8List? bytes = await provider.readFile(_manifestPath);
    if (bytes == null || bytes.isEmpty) {
      return OperationSyncManifestState.initial(
        latestSnapshotSequence: await _readSnapshotSequence(),
      );
    }
    return OperationSyncManifestState.fromJson(
      Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map),
    );
  }

  Future<int> _pushQueuedOperations({
    required String passphrase,
    required List<int> salt,
    required OperationSyncManifestState manifest,
  }) async {
    int uploaded = 0;
    while (true) {
      final List<SyncQueueData> queued = await syncQueueDao.loadReadyBatch(
        limit: _batchLimit,
      );
      if (queued.isEmpty) {
        break;
      }

      final List<CloudOperation> operations = <CloudOperation>[];
      for (final SyncQueueData row in queued) {
        operations.add(await _queueRowToOperation(row));
      }
      final int sequence = queued.last.id;
      final CloudOperationBatch batch = CloudOperationBatch(
        batchId: const Uuid().v4(),
        deviceId: deviceId,
        sequence: sequence,
        createdAt: DateTime.now().toUtc(),
        schemaVersion: 1,
        checksum: '',
        keyVersion: 1,
        fileType: 'operation_log',
        latestSnapshotSequence: manifest.latestSnapshotSequence,
        operations: operations,
      );
      final CloudOperationBatch signedBatch = await _withChecksumBatch(batch);
      final String logPath = 'logs/log_${deviceId}_$sequence.json.enc';
      final Uint8List clearBytes = Uint8List.fromList(
        utf8.encode(encodeCanonicalJson(signedBatch.toJson())),
      );
      final crypto.SecretKey key = await encryptionService.deriveKey(
        passphrase: passphrase,
        salt: salt,
      );
      final Uint8List encrypted = await encryptionService.encrypt(
        clearText: clearBytes,
        secretKey: key,
      );
      await provider.writeFile(logPath, encrypted);

      final OperationSyncManifestState nextManifest = _mergeManifestStates(
        manifest,
        OperationSyncManifestState(
          schemaVersion: manifest.schemaVersion,
          latestSnapshotSequence: manifest.latestSnapshotSequence,
          latestLogSequenceByDevice: <String, int>{
            ...manifest.latestLogSequenceByDevice,
            deviceId: sequence,
          },
          knownDevices: <String, DeviceSyncCheckpoint>{
            ...manifest.knownDevices,
            deviceId: DeviceSyncCheckpoint(
              deviceId: deviceId,
              deviceName: deviceName,
              appVersion: appVersion,
              lastUploadedSequence: sequence,
              lastAppliedSequence: sequence,
              lastUploadedAt: DateTime.now().toUtc(),
              lastAppliedAt: DateTime.now().toUtc(),
            ),
          },
          logRetentionCount: manifest.logRetentionCount,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await _writeManifest(nextManifest);
      await syncQueueDao.deleteQueueRows(queued.map((row) => row.id).toList());
      await _writeLocalCheckpoint(
        DeviceSyncCheckpoint(
          deviceId: deviceId,
          deviceName: deviceName,
          appVersion: appVersion,
          lastUploadedSequence: sequence,
          lastAppliedSequence: sequence,
          lastUploadedAt: DateTime.now().toUtc(),
          lastAppliedAt: DateTime.now().toUtc(),
        ),
      );
      await syncMetadataDao.setValue(_lastUploadedKey, sequence.toString());
      manifest = nextManifest;
      uploaded++;
    }
    return uploaded;
  }

  Future<OperationSyncApplyOutcome> _pullRemoteOperations({
    required String passphrase,
    required List<int> salt,
    required OperationSyncManifestState manifest,
  }) async {
    final DeviceSyncCheckpoint? localCheckpoint = await loadLocalCheckpoint();
    final Map<String, int> appliedByDevice = <String, int>{
      if (localCheckpoint != null)
        deviceId: localCheckpoint.lastAppliedSequence,
    };
    final List<CloudFileInfo> files = await provider.listFiles('logs/');
    files.sort((CloudFileInfo left, CloudFileInfo right) {
      final ParsedLogFileInfo leftInfo = _parseLogFile(left.path);
      final ParsedLogFileInfo rightInfo = _parseLogFile(right.path);
      final int deviceCompare = leftInfo.deviceId.compareTo(rightInfo.deviceId);
      if (deviceCompare != 0) return deviceCompare;
      return leftInfo.sequence.compareTo(rightInfo.sequence);
    });

    int applied = 0;
    int skipped = 0;
    for (final CloudFileInfo file in files) {
      final ParsedLogFileInfo parsed = _parseLogFile(file.path);
      if (parsed.deviceId.isEmpty || parsed.deviceId == deviceId) {
        continue;
      }
      final int lastApplied =
          appliedByDevice[parsed.deviceId] ??
          await _readAppliedSequence(parsed.deviceId);
      if (parsed.sequence <= lastApplied) {
        continue;
      }

      try {
        final Uint8List? encrypted = await provider.readFile(file.path);
        if (encrypted == null || encrypted.isEmpty) {
          skipped++;
          continue;
        }
        final crypto.SecretKey key = await encryptionService.deriveKey(
          passphrase: passphrase,
          salt: salt,
        );
        final Uint8List decrypted = await encryptionService.decrypt(
          encryptedData: encrypted,
          secretKey: key,
        );
        final dynamic decoded = jsonDecode(utf8.decode(decrypted));
        if (decoded is! Map) {
          skipped++;
          continue;
        }
        final CloudOperationBatch batch = CloudOperationBatch.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        if (!_isValidBatch(batch)) {
          skipped++;
          continue;
        }
        await _verifyBatchChecksum(batch);
        await _applyBatch(batch);
        appliedByDevice[parsed.deviceId] = batch.sequence;
        await _writeLocalCheckpoint(
          DeviceSyncCheckpoint(
            deviceId: deviceId,
            deviceName: deviceName,
            appVersion: appVersion,
            lastUploadedSequence: localCheckpoint?.lastUploadedSequence ?? 0,
            lastAppliedSequence: batch.sequence,
            lastUploadedAt: localCheckpoint?.lastUploadedAt,
            lastAppliedAt: DateTime.now().toUtc(),
          ),
        );
        await _writeCheckpointFile(
          DeviceSyncCheckpoint(
            deviceId: deviceId,
            deviceName: deviceName,
            appVersion: appVersion,
            lastUploadedSequence: localCheckpoint?.lastUploadedSequence ?? 0,
            lastAppliedSequence: batch.sequence,
            lastUploadedAt: localCheckpoint?.lastUploadedAt,
            lastAppliedAt: DateTime.now().toUtc(),
          ),
        );
        await syncMetadataDao.setValue(
          _lastAppliedKeyFor(parsed.deviceId),
          batch.sequence.toString(),
        );
        applied++;
      } on crypto.SecretBoxAuthenticationError {
        skipped++;
      } catch (_) {
        skipped++;
      }
    }

    final OperationSyncManifestState merged = manifest.copyWith(
      knownDevices: <String, DeviceSyncCheckpoint>{
        ...manifest.knownDevices,
        deviceId: DeviceSyncCheckpoint(
          deviceId: deviceId,
          deviceName: deviceName,
          appVersion: appVersion,
          lastUploadedSequence: localCheckpoint?.lastUploadedSequence ?? 0,
          lastAppliedSequence: localCheckpoint?.lastAppliedSequence ?? 0,
          lastUploadedAt: localCheckpoint?.lastUploadedAt,
          lastAppliedAt: localCheckpoint?.lastAppliedAt,
        ),
      },
      latestLogSequenceByDevice: <String, int>{
        ...manifest.latestLogSequenceByDevice,
        for (final MapEntry<String, int> entry in appliedByDevice.entries)
          entry.key: entry.value,
      },
      updatedAt: DateTime.now().toUtc(),
    );
    await _writeManifest(merged);
    await controller.refreshFromLocalRepositories(
      reason: 'google_drive_operation_sync',
    );
    return OperationSyncApplyOutcome(
      appliedCount: applied,
      skippedCount: skipped,
    );
  }

  Future<int> _readAppliedSequence(String deviceId) async {
    final String? raw = await syncMetadataDao.getValue(
      _lastAppliedKeyFor(deviceId),
    );
    if (raw == null || raw.trim().isEmpty) {
      return 0;
    }
    return int.tryParse(raw.trim()) ?? 0;
  }

  Future<void> _applyBatch(CloudOperationBatch batch) async {
    final AppDatabase? db = controller.database;
    if (db == null) {
      throw StateError('Active database is unavailable.');
    }
    await db.transaction(() async {
      for (final CloudOperation op in batch.operations) {
        await _applyOperation(op);
      }
    });
  }

  Future<void> _applyOperation(CloudOperation op) async {
    final String domain = op.domain.trim();
    final String operation = op.operation.trim().toLowerCase();
    switch (domain) {
      case 'transactions':
        await _applyTransaction(op, operation);
        return;
      case 'savings':
        await _applySaving(op, operation);
        return;
      case 'investments':
        await _applyInvestment(op, operation);
        return;
      case 'recurring_transactions':
        await _applyRecurringTransaction(op, operation);
        return;
      case 'financial_plans':
        await _applyFinancialPlan(op, operation);
        return;
      case 'merchant_rules':
        await _applyMerchantRule(op, operation);
        return;
      case 'merchant_confirmations':
        await _applyMerchantConfirmation(op, operation);
        return;
      case 'correction_feedback':
        await _applyCorrectionFeedback(op, operation);
        return;
      case 'app_settings':
        await _applyAppSettings(op, operation);
        return;
      default:
        return;
    }
  }

  Future<void> _applyTransaction(CloudOperation op, String operation) async {
    final dynamic repo = controller.localTransactionsRepository;
    if (repo == null) return;
    if (operation == 'delete') {
      await repo.applyRemoteDeleteTransaction(
        op.recordId,
        deletedAt: op.createdAt.toIso8601String(),
      );
      return;
    }
    final Map<String, dynamic>? payload = op.payload;
    if (payload == null) return;
    await repo.applyRemoteUpsertTransaction(
      model.Transaction.fromJson(payload),
      updatedAt: op.createdAt.toIso8601String(),
    );
  }

  Future<void> _applySaving(CloudOperation op, String operation) async {
    final dynamic repo = controller.localSavingsRepository;
    if (repo == null) return;
    if (operation == 'delete') {
      await repo.applyRemoteDeleteSaving(
        op.recordId,
        deletedAt: op.createdAt.toIso8601String(),
      );
      return;
    }
    final Map<String, dynamic>? payload = op.payload;
    if (payload == null) return;
    await repo.applyRemoteUpsertSaving(
      model.Saving.fromJson(payload),
      updatedAt: op.createdAt.toIso8601String(),
    );
  }

  Future<void> _applyInvestment(CloudOperation op, String operation) async {
    final LocalInvestmentsRepository? repo =
        controller.localInvestmentsRepository;
    if (repo == null) return;
    if (operation == 'delete') {
      await repo.applyRemoteDeleteInvestment(
        op.recordId,
        deletedAt: op.createdAt.toIso8601String(),
      );
      return;
    }
    final Map<String, dynamic>? payload = op.payload;
    if (payload == null) return;
    await repo.applyRemoteUpsertInvestment(
      model.InvestmentAsset.fromJson(payload),
      updatedAt: op.createdAt.toIso8601String(),
    );
  }

  Future<void> _applyRecurringTransaction(
    CloudOperation op,
    String operation,
  ) async {
    final LocalRecurringTransactionsRepository? repo =
        controller.localRecurringTransactionsRepository;
    if (repo == null) return;
    if (operation == 'delete') {
      await repo.applyRemoteDeleteRecurringTransaction(
        op.recordId,
        deletedAt: op.createdAt.toIso8601String(),
      );
      return;
    }
    final Map<String, dynamic>? payload = op.payload;
    if (payload == null) return;
    await repo.applyRemoteUpsertRecurringTransaction(
      model.RecurringTransaction.fromJson(payload),
      updatedAt: op.createdAt.toIso8601String(),
    );
  }

  Future<void> _applyFinancialPlan(CloudOperation op, String operation) async {
    final LocalFinancialPlansRepository? repo =
        controller.localFinancialPlansRepository;
    if (repo == null) return;
    if (operation == 'delete') {
      await repo.applyRemoteDeleteFinancialPlan(
        op.recordId,
        deletedAt: op.createdAt.toIso8601String(),
      );
      return;
    }
    final Map<String, dynamic>? payload = op.payload;
    if (payload == null) return;
    await repo.applyRemoteUpsertFinancialPlan(
      model.FinancialPlan.fromJson(payload),
      updatedAt: op.createdAt.toIso8601String(),
    );
  }

  Future<void> _applyMerchantRule(CloudOperation op, String operation) async {
    final LocalMerchantRulesRepository? repo =
        controller.localMerchantRulesRepository;
    if (repo == null) return;
    if (operation == 'delete') {
      await repo.applyRemoteDeleteMerchantRule(
        op.recordId,
        deletedAt: op.createdAt.toIso8601String(),
      );
      return;
    }
    final Map<String, dynamic>? payload = op.payload;
    if (payload == null) return;
    await repo.applyRemoteUpsertMerchantRule(
      model.MerchantRule.fromJson(payload),
      updatedAt: op.createdAt.toIso8601String(),
    );
  }

  Future<void> _applyMerchantConfirmation(
    CloudOperation op,
    String operation,
  ) async {
    final LocalMerchantConfirmationsRepository? repo =
        controller.localMerchantConfirmationsRepository;
    if (repo == null) return;
    if (operation == 'delete') {
      await repo.applyRemoteDeleteMerchantConfirmation(
        op.recordId,
        deletedAt: op.createdAt.toIso8601String(),
      );
      return;
    }
    final Map<String, dynamic>? payload = op.payload;
    if (payload == null) return;
    await repo.applyRemoteUpsertMerchantConfirmation(
      model.MerchantConfirmation.fromJson(payload),
      updatedAt: op.createdAt.toIso8601String(),
    );
  }

  Future<void> _applyCorrectionFeedback(
    CloudOperation op,
    String operation,
  ) async {
    final LocalCorrectionFeedbackRepository? repo =
        controller.localCorrectionFeedbackRepository;
    if (repo == null) return;
    if (operation == 'delete') {
      await repo.applyRemoteDeleteCorrectionFeedback(
        op.recordId,
        deletedAt: op.createdAt.toIso8601String(),
      );
      return;
    }
    final Map<String, dynamic>? payload = op.payload;
    if (payload == null) return;
    await repo.applyRemoteUpsertCorrectionFeedback(
      model.CorrectionFeedback.fromJson(payload),
      updatedAt: op.createdAt.toIso8601String(),
    );
  }

  Future<void> _applyAppSettings(CloudOperation op, String operation) async {
    final LocalAppSettingsRepository? repo =
        controller.localAppSettingsRepository;
    if (repo == null || operation == 'delete') return;
    final Map<String, dynamic>? payload = op.payload;
    if (payload == null) return;
    if (payload['values'] is Map<String, dynamic>) {
      await repo.importSettings(
        Map<String, dynamic>.from(payload['values'] as Map),
      );
      return;
    }
    await repo.importSettings(payload);
  }

  Future<void> _writeManifest(OperationSyncManifestState manifest) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      final CloudFileInfo? existing = await _findFile(_manifestPath);
      final OperationSyncManifestState current = existing == null
          ? OperationSyncManifestState.initial(
              latestSnapshotSequence: manifest.latestSnapshotSequence,
            )
          : await _loadManifest();
      final OperationSyncManifestState merged = _mergeManifestStates(
        current,
        manifest,
      );
      final Map<String, dynamic> payload = merged.toJson();
      final Uint8List bytes = Uint8List.fromList(
        utf8.encode(encodeCanonicalJson(payload)),
      );
      try {
        await provider.writeFile(
          _manifestPath,
          bytes,
          expectedRevision: existing?.revision,
        );
        return;
      } on StateError catch (error) {
        final String message = error.toString().toLowerCase();
        if (!message.contains('revision mismatch') &&
            !message.contains('etag')) {
          rethrow;
        }
        if (attempt == 2) {
          rethrow;
        }
      }
    }
  }

  Future<void> _writeLocalCheckpoint(DeviceSyncCheckpoint checkpoint) async {
    await syncMetadataDao.setValue(
      _checkpointKey,
      jsonEncode(checkpoint.toJson()),
    );
  }

  Future<void> _writeCheckpointFile(DeviceSyncCheckpoint checkpoint) async {
    final Uint8List bytes = Uint8List.fromList(
      utf8.encode(jsonEncode(checkpoint.toJson())),
    );
    await provider.writeFile('checkpoints/checkpoint_$deviceId.json', bytes);
  }

  Future<CloudFileInfo?> _findFile(String path) async {
    final List<CloudFileInfo> files = await provider.listFiles(path);
    for (final CloudFileInfo file in files) {
      if (file.path == path) {
        return file;
      }
    }
    return null;
  }

  Future<int> _readSnapshotSequence() async {
    final CloudManifest? manifest = await provider.readManifest();
    if (manifest == null) return 0;
    try {
      final CloudSyncManifest snapshotManifest = CloudSyncManifest.fromJson(
        manifest.content,
      );
      return snapshotManifest.currentSnapshotSequence;
    } catch (_) {
      return 0;
    }
  }

  Map<String, DeviceSyncCheckpoint> _mergedKnownDevices(
    OperationSyncManifestState manifest,
    int snapshotSequence,
  ) {
    return <String, DeviceSyncCheckpoint>{
      ...manifest.knownDevices,
      deviceId: DeviceSyncCheckpoint(
        deviceId: deviceId,
        deviceName: deviceName,
        appVersion: appVersion,
        lastUploadedSequence:
            manifest.knownDevices[deviceId]?.lastUploadedSequence ?? 0,
        lastAppliedSequence:
            manifest.knownDevices[deviceId]?.lastAppliedSequence ?? 0,
        lastUploadedAt: manifest.knownDevices[deviceId]?.lastUploadedAt,
        lastAppliedAt: manifest.knownDevices[deviceId]?.lastAppliedAt,
      ),
    };
  }

  Future<CloudOperation> _queueRowToOperation(SyncQueueData row) async {
    final Map<String, dynamic>? payload = _decodePayload(row.payloadJson);
    final String activityId = _activityIdForRow(row, payload);
    final CloudOperation operation = CloudOperation(
      opId: 'op_${row.id}',
      deviceId: row.deviceId?.trim().isNotEmpty == true
          ? row.deviceId!
          : deviceId,
      localSequence: row.id,
      createdAt: DateTime.tryParse(row.createdAt) ?? DateTime.now().toUtc(),
      domain: row.collectionName,
      recordId: row.recordId,
      operation: row.operation,
      schemaVersion: 1,
      checksum: '',
      keyVersion: 1,
      payload: payload,
      activityId: activityId.isEmpty ? null : activityId,
    );
    return _withChecksumOperation(operation);
  }

  Future<CloudOperation> _withChecksumOperation(
    CloudOperation operation,
  ) async {
    final Map<String, dynamic> json = Map<String, dynamic>.from(
      operation.toJson(),
    )..remove('checksum');
    final digest = await crypto.Sha256().hash(
      Uint8List.fromList(utf8.encode(encodeCanonicalJson(json))),
    );
    final String checksum = base64Encode(digest.bytes);
    return CloudOperation(
      opId: operation.opId,
      deviceId: operation.deviceId,
      localSequence: operation.localSequence,
      createdAt: operation.createdAt,
      domain: operation.domain,
      recordId: operation.recordId,
      operation: operation.operation,
      schemaVersion: operation.schemaVersion,
      checksum: checksum,
      keyVersion: operation.keyVersion,
      payload: operation.payload,
      activityId: operation.activityId,
    );
  }

  Future<CloudOperationBatch> _withChecksumBatch(
    CloudOperationBatch batch,
  ) async {
    final Map<String, dynamic> json = Map<String, dynamic>.from(batch.toJson())
      ..remove('checksum');
    final digest = await crypto.Sha256().hash(
      Uint8List.fromList(utf8.encode(encodeCanonicalJson(json))),
    );
    final String checksum = base64Encode(digest.bytes);
    return CloudOperationBatch(
      batchId: batch.batchId,
      deviceId: batch.deviceId,
      sequence: batch.sequence,
      createdAt: batch.createdAt,
      schemaVersion: batch.schemaVersion,
      checksum: checksum,
      keyVersion: batch.keyVersion,
      fileType: batch.fileType,
      operations: batch.operations,
      latestSnapshotSequence: batch.latestSnapshotSequence,
    );
  }

  bool _isValidBatch(CloudOperationBatch batch) {
    if (batch.fileType.trim() != 'operation_log') {
      return false;
    }
    if (batch.keyVersion <= 0) {
      return false;
    }
    if (batch.deviceId.trim().isEmpty || batch.batchId.trim().isEmpty) {
      return false;
    }
    if (batch.operations.isEmpty) {
      return false;
    }
    return true;
  }

  String _formatSyncMessage({
    required int uploaded,
    required int applied,
    required int skipped,
  }) {
    final List<String> parts = <String>[];
    if (uploaded > 0) {
      parts.add('Uploaded $uploaded operation batch(es).');
    }
    if (applied > 0) {
      parts.add('Applied $applied remote operation batch(es).');
    }
    if (skipped > 0) {
      parts.add('Skipped $skipped unreadable or incompatible operation batch(es).');
    }
    if (parts.isEmpty) {
      return 'No pending operations.';
    }
    return parts.join(' ');
  }

  Future<void> _verifyBatchChecksum(CloudOperationBatch batch) async {
    final Map<String, dynamic> json = Map<String, dynamic>.from(batch.toJson())
      ..remove('checksum');
    final digest = await crypto.Sha256().hash(
      Uint8List.fromList(utf8.encode(encodeCanonicalJson(json))),
    );
    final String checksum = base64Encode(digest.bytes);
    if (checksum != batch.checksum) {
      throw StateError('Remote operation batch checksum mismatch.');
    }
  }

  String _activityIdForRow(SyncQueueData row, Map<String, dynamic>? payload) {
    if (payload == null) {
      return row.recordId;
    }
    final List<String> keys = <String>[
      'activityId',
      'exchangePairId',
      'transferActivityId',
      'groupId',
    ];
    for (final String key in keys) {
      final String value = (payload[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return row.recordId;
  }

  Map<String, dynamic>? _decodePayload(String? payloadJson) {
    if (payloadJson == null || payloadJson.trim().isEmpty) return null;
    try {
      final Object decoded = jsonDecode(payloadJson);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  OperationSyncManifestState _mergeManifestStates(
    OperationSyncManifestState current,
    OperationSyncManifestState desired,
  ) {
    return OperationSyncManifestState(
      schemaVersion: desired.schemaVersion,
      latestSnapshotSequence:
          desired.latestSnapshotSequence > current.latestSnapshotSequence
          ? desired.latestSnapshotSequence
          : current.latestSnapshotSequence,
      latestLogSequenceByDevice: <String, int>{
        ...current.latestLogSequenceByDevice,
        ...desired.latestLogSequenceByDevice,
      },
      knownDevices: <String, DeviceSyncCheckpoint>{
        ...current.knownDevices,
        ...desired.knownDevices,
      },
      logRetentionCount: desired.logRetentionCount,
      updatedAt: desired.updatedAt.isAfter(current.updatedAt)
          ? desired.updatedAt
          : current.updatedAt,
    );
  }

  Future<List<int>> _readEncryptionSalt(String passphrase) async {
    final CloudManifest? manifest = await provider.readManifest();
    if (manifest == null) {
      return _deriveDeterministicSalt(passphrase);
    }
    try {
      final CloudSyncManifest snapshotManifest = CloudSyncManifest.fromJson(
        manifest.content,
      );
      return base64Decode(snapshotManifest.encryption.saltBase64);
    } catch (_) {
      return _deriveDeterministicSalt(passphrase);
    }
  }

  Future<List<int>> _deriveDeterministicSalt(String passphrase) async {
    final digest = await crypto.Sha256().hash(
      Uint8List.fromList(
        utf8.encode('google_drive_operation_sync::$passphrase'),
      ),
    );
    return digest.bytes.sublist(0, 16);
  }
}

class ParsedLogFileInfo {
  const ParsedLogFileInfo({required this.deviceId, required this.sequence});

  final String deviceId;
  final int sequence;
}

ParsedLogFileInfo _parseLogFile(String path) {
  final RegExpMatch? match = RegExp(
    r'^logs/log_(.+)_(\d+)\.json\.enc$',
  ).firstMatch(path);
  if (match == null) {
    return const ParsedLogFileInfo(deviceId: '', sequence: 0);
  }
  return ParsedLogFileInfo(
    deviceId: match.group(1) ?? '',
    sequence: int.tryParse(match.group(2) ?? '') ?? 0,
  );
}

class OperationSyncApplyOutcome {
  const OperationSyncApplyOutcome({
    required this.appliedCount,
    required this.skippedCount,
  });

  final int appliedCount;
  final int skippedCount;
}
