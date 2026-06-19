import 'package:flutter/widgets.dart';

import '../models/backup_preview.dart';
import 'app_state_controller.dart';
import 'auth_controller.dart';

class CloudBackupController extends ChangeNotifier with WidgetsBindingObserver {
  CloudBackupController({
    required this.appStateController,
    required this.authController,
  }) {
    appStateController.addListener(_onSourceChanged);
    authController.addListener(_onSourceChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  final AppStateController appStateController;
  final AuthController authController;

  bool get isChecking => false;
  bool get isBackingUp => false;
  bool get isRestoring => false;
  bool get hasCloudBackup => false;
  bool get hasPendingAutoBackup => false;
  bool get shouldPromptRestore => false;
  BackupPreview? get latestBackup => null;
  bool get cloudBackupNewerThanLocal => false;
  bool get backupOwnershipMismatch => false;
  String get statusMessage =>
      authController.currentUser == null ? '' : 'Cloud Sync: Active';
  String get lastError => '';
  Duration get autoBackupDelay => const Duration(minutes: 3);

  Future<void> refreshCloudState({bool evaluatePrompt = true}) async {
    notifyListeners();
  }

  Future<bool> backupNow({
    bool forceIfCloudNewer = false,
    bool automatic = false,
  }) async {
    return false;
  }

  Future<BackupPreview?> previewLatestBackup() async {
    return null;
  }

  Future<bool> restoreLatestBackup({bool allowOverwrite = true}) async {
    return false;
  }

  void dismissRestorePrompt() {
    notifyListeners();
  }

  @override
  void dispose() {
    appStateController.removeListener(_onSourceChanged);
    authController.removeListener(_onSourceChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cloud sync is handled automatically by Firebase now.
  }

  void _onSourceChanged() {
    notifyListeners();
  }
}
