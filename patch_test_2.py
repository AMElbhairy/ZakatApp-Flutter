with open('lib/services/cloud_backup_controller.dart', 'r') as f:
    content = f.read()

content = content.replace(
    "if (_isRestoring || _isBackingUp) return false;",
    "if (_isRestoring || _isBackingUp) { print('stuck: isRestoring=$_isRestoring, isBackingUp=$_isBackingUp'); return false; }"
).replace(
    "if (latest == null || _accessToken == null || _accessToken!.isEmpty) {",
    "if (latest == null || _accessToken == null || _accessToken!.isEmpty) { print('latest=$latest, accessToken=$_accessToken');"
).replace(
    "if (!await authController.ensureSession()) {",
    "if (!await authController.ensureSession()) { print('ensureSession failed');"
)

with open('lib/services/cloud_backup_controller.dart', 'w') as f:
    f.write(content)
