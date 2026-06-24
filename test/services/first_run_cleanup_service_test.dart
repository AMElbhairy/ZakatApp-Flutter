import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zakatapp_flutter/services/first_run_cleanup_service.dart';

class _FakeGoogleSignIn extends Fake implements GoogleSignIn {
  int signOutCalls = 0;

  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOutCalls += 1;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first run cleanup clears stale Google Sign-In session', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final MockFirebaseAuth firebaseAuth = MockFirebaseAuth();
    final _FakeGoogleSignIn googleSignIn = _FakeGoogleSignIn();
    int secureStorageDeletes = 0;

    await FirstRunCleanupService(
      firebaseAuth: firebaseAuth,
      googleSignIn: googleSignIn,
      clearSecureStorage: () async {
        secureStorageDeletes += 1;
      },
    ).runIfNeeded(prefs);

    expect(googleSignIn.signOutCalls, equals(1));
    expect(prefs.getBool('has_run_before'), isTrue);
    expect(secureStorageDeletes, equals(1));
    expect(firebaseAuth.currentUser, isNull);
  });

  test('first run cleanup is skipped after the initial install', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'has_run_before': true,
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final MockFirebaseAuth firebaseAuth = MockFirebaseAuth();
    final _FakeGoogleSignIn googleSignIn = _FakeGoogleSignIn();
    int secureStorageDeletes = 0;

    await FirstRunCleanupService(
      firebaseAuth: firebaseAuth,
      googleSignIn: googleSignIn,
      clearSecureStorage: () async {
        secureStorageDeletes += 1;
      },
    ).runIfNeeded(prefs);

    expect(googleSignIn.signOutCalls, equals(0));
    expect(prefs.getBool('has_run_before'), isTrue);
    expect(secureStorageDeletes, equals(0));
    expect(firebaseAuth.currentUser, isNull);
  });
}
