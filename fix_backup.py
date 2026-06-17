import re

with open('lib/services/cloud_backup_controller.dart', 'r') as f:
    content = f.read()

# backupNow
old_backup = """  Future<bool> backupNow({bool forceIfCloudNewer = false, bool automatic = false}) async {
    final String? accessToken = _accessToken;
    if (accessToken == null || accessToken.isEmpty) {"""

new_backup = """  Future<bool> backupNow({bool forceIfCloudNewer = false, bool automatic = false}) async {
    if (_accessToken == null || _accessToken!.isEmpty) {"""
content = content.replace(old_backup, new_backup)

old_backup_try = """    try {
      final DateTime now = DateTime.now().toUtc();"""
new_backup_try = """    try {
      if (!await authController.ensureSession()) {
        _statusMessage = 'Session expired. Please sign in again.';
        return false;
      }
      final String? accessToken = _accessToken;
      if (accessToken == null) return false;

      final DateTime now = DateTime.now().toUtc();"""
content = content.replace(old_backup_try, new_backup_try)

# previewLatestBackup
old_preview = """  Future<BackupPreview?> previewLatestBackup() async {
    final DriveBackupFile? latest = _latestBackup;
    final String? accessToken = _accessToken;
    if (latest == null || accessToken == null || accessToken.isEmpty) {"""
new_preview = """  Future<BackupPreview?> previewLatestBackup() async {
    final DriveBackupFile? latest = _latestBackup;
    if (latest == null || _accessToken == null || _accessToken!.isEmpty) {"""
content = content.replace(old_preview, new_preview)

old_preview_try = """    final String? rawJson = latest.rawJson ??
        await _googleDriveService.downloadBackupContent(
          accessToken: accessToken,
          fileId: latest.id,
        );"""
new_preview_try = """    if (!await authController.ensureSession()) return null;
    final String? accessToken = _accessToken;
    if (accessToken == null) return null;

    final String? rawJson = latest.rawJson ??
        await _googleDriveService.downloadBackupContent(
          accessToken: accessToken,
          fileId: latest.id,
        );"""
content = content.replace(old_preview_try, new_preview_try)

# restoreLatestBackup
old_restore = """  Future<bool> restoreLatestBackup({bool allowOverwrite = true}) async {
    final DriveBackupFile? latest = _latestBackup;
    final String? accessToken = _accessToken;
    if (latest == null || accessToken == null || accessToken.isEmpty) {"""
new_restore = """  Future<bool> restoreLatestBackup({bool allowOverwrite = true}) async {
    final DriveBackupFile? latest = _latestBackup;
    if (latest == null || _accessToken == null || _accessToken!.isEmpty) {"""
content = content.replace(old_restore, new_restore)

old_restore_try = """    try {
      final String? rawJson = latest.rawJson ??
          await _googleDriveService.downloadBackupContent(
            accessToken: accessToken,
            fileId: latest.id,
          );"""
new_restore_try = """    try {
      if (!await authController.ensureSession()) {
        _statusMessage = 'Session expired. Please sign in again.';
        return false;
      }
      final String? accessToken = _accessToken;
      if (accessToken == null) return false;

      final String? rawJson = latest.rawJson ??
          await _googleDriveService.downloadBackupContent(
            accessToken: accessToken,
            fileId: latest.id,
          );"""
content = content.replace(old_restore_try, new_restore_try)

with open('lib/services/cloud_backup_controller.dart', 'w') as f:
    f.write(content)

