class StorageKeys {
  StorageKeys._();

  // Matches the legacy anonymous local key in the JS app.
  static const String appStateAnonymousKey = 'zakatAppData';
  static const String userProfileKey = 'zakatUserProfile';

  static String? appStateKeyForUser(String? userId) {
    final String clean = (userId ?? '').trim();
    if (clean.isEmpty) return null;
    return 'zakatAppData_$clean';
  }
}
