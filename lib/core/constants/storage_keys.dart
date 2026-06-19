class StorageKeys {
  StorageKeys._();

  // Matches the legacy anonymous local key in the JS app.
  static const String appStateAnonymousKey = 'zakatAppData';
  static const String userProfileKey = 'zakatUserProfile';
  static const String aiKeysAnonymousKey = 'zakatAiKeys';
  static const String savedCredentialEmailPrefix = 'savedCredentialEmail_';

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

  static String? savedCredentialEmailKey(String? email) {
    final String clean = (email ?? '').trim().toLowerCase();
    if (clean.isEmpty) return null;
    return '$savedCredentialEmailPrefix$clean';
  }
}
