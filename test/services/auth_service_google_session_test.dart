import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:zakatapp_flutter/features/auth/auth_service.dart';

class _TrackingGoogleSignIn extends Fake implements GoogleSignIn {
  int signOutCalls = 0;

  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOutCalls += 1;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('email sign-in clears cached Google session before login', () async {
    final _TrackingGoogleSignIn googleSignIn = _TrackingGoogleSignIn();
    final FirebaseAuthService authService = FirebaseAuthService(
      firebaseAuth: MockFirebaseAuth(
        signedIn: false,
        mockUser: MockUser(
          uid: 'email-user',
          email: 'user@example.com',
          isEmailVerified: true,
        ),
      ),
      googleSignIn: googleSignIn,
    );

    await authService.signInWithEmail(
      email: 'user@example.com',
      password: 'password123',
    );

    expect(googleSignIn.signOutCalls, equals(1));
  });
}
