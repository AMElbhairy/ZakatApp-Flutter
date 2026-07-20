import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirstRunCleanupService {
  FirstRunCleanupService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    Future<void> Function()? clearSecureStorage,
    Future<void> Function()? clearAppStorage,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _clearSecureStorage =
            clearSecureStorage ?? (() async {}),
        _clearAppStorage = clearAppStorage ?? (() async {});

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final Future<void> Function() _clearSecureStorage;
  final Future<void> Function() _clearAppStorage;

  Future<void> runIfNeeded(SharedPreferences prefs) async {
    final bool hasRunBefore = prefs.getBool('has_run_before') ?? false;
    if (hasRunBefore) return;

    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      // Best-effort cleanup on fresh install.
    }

    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Best-effort cleanup on fresh install.
    }

    try {
      await _clearSecureStorage();
    } catch (_) {
      // Best-effort cleanup on fresh install.
    }

    try {
      await _clearAppStorage();
    } catch (_) {
      // Best-effort cleanup on fresh install.
    }

    await prefs.setBool('has_run_before', true);
  }
}
