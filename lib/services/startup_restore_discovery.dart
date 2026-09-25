import '../models/backup_preview.dart';

enum StartupRestoreSource {
  cloud,
  local,
}

enum StartupRestoreDiscoveryStatus {
  none,
  restorePrompt,
  drivePermissionRequired,
  keyRecoveryRequired,
  dismissed,
}

class StartupRestoreDiscoveryResult {
  const StartupRestoreDiscoveryResult({
    required this.status,
    required this.message,
    this.preview,
    this.error,
    this.source = StartupRestoreSource.cloud,
  });

  final StartupRestoreDiscoveryStatus status;
  final String message;
  final BackupPreview? preview;
  final String? error;
  final StartupRestoreSource source;

  StartupRestoreDiscoveryResult copyWith({
    StartupRestoreDiscoveryStatus? status,
    String? message,
    BackupPreview? preview,
    String? error,
    StartupRestoreSource? source,
  }) {
    return StartupRestoreDiscoveryResult(
      status: status ?? this.status,
      message: message ?? this.message,
      preview: preview ?? this.preview,
      error: error ?? this.error,
      source: source ?? this.source,
    );
  }

  bool get shouldShowGate =>
      status == StartupRestoreDiscoveryStatus.restorePrompt ||
      status == StartupRestoreDiscoveryStatus.drivePermissionRequired ||
      status == StartupRestoreDiscoveryStatus.keyRecoveryRequired;

  bool get needsDrivePermission =>
      status == StartupRestoreDiscoveryStatus.drivePermissionRequired;

  bool get needsKeyRecovery =>
      status == StartupRestoreDiscoveryStatus.keyRecoveryRequired;

  bool get hasRestorableBackup =>
      status == StartupRestoreDiscoveryStatus.restorePrompt && preview != null;

  bool get hasError => error != null && error!.isNotEmpty;

  bool get isLocalBackup => source == StartupRestoreSource.local;

  bool get isCloudBackup => source == StartupRestoreSource.cloud;
}
