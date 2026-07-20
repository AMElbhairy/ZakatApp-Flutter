import 'startup_restore_discovery.dart';

abstract interface class BootstrapCloudService {
  Future<StartupRestoreDiscoveryResult> discoverStartupRestore({
    required bool localHasData,
  });

  Future<void> activateAfterBootstrap();

  Future<void> onLifecycleResume();

  Future<bool> restoreLatestBackup({bool allowOverwrite = true});

  void completeStartupRestoreDiscovery();

  String get statusMessage;
}
