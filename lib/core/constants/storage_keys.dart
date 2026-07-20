class StorageKeys {
  StorageKeys._();

  // Matches the legacy anonymous local key in the JS app.
  static const String appStateAnonymousKey = 'zakatAppData';
  static const String userProfileKey = 'zakatUserProfile';
  static const String aiKeysAnonymousKey = 'zakatAiKeys';
  static const String backupKeyAnonymousKey = 'zakatBackupKey';
  static const String onboardingCompletedKey = 'zakatOnboardingCompleted_v1';
  static const String onboardingCompletedVersionKey =
      'zakatOnboardingCompletedVersion_v2';
  static const String onboardingStepKey = 'zakatOnboardingStep_v2';
  static const String savedCredentialEmailPrefix = 'savedCredentialEmail_';
  static const String biometricLockEnabledPrefix = 'biometricLockEnabled_';
  static const String biometricAutoLockDelayPrefix = 'biometricAutoLockDelay_';

  static String? appStateKeyForUser(String? userId) {
    final String clean = (userId ?? '').trim();
    if (clean.isEmpty) return null;
    return 'zakatAppData_$clean';
  }

  static String aiKeysKeyForUser(String? userId) {
    final String clean = (userId ?? '').trim();
    if (clean.isEmpty) return aiKeysAnonymousKey;
    return 'zakatAiKeys_$clean';
  }

  static String backupKeyKeyForUser(String? userId) {
    final String clean = (userId ?? '').trim();
    if (clean.isEmpty) return backupKeyAnonymousKey;
    return 'zakatBackupKey_$clean';
  }

  static String? savedCredentialEmailKey(String? email) {
    final String clean = (email ?? '').trim().toLowerCase();
    if (clean.isEmpty) return null;
    return '$savedCredentialEmailPrefix$clean';
  }

  static String biometricLockEnabledKeyForUser(String? userId) {
    final String clean = (userId ?? '').trim();
    return '$biometricLockEnabledPrefix${clean.isEmpty ? 'default' : clean}';
  }

  static String biometricAutoLockDelayKeyForUser(String? userId) {
    final String clean = (userId ?? '').trim();
    return '$biometricAutoLockDelayPrefix${clean.isEmpty ? 'default' : clean}';
  }
}
