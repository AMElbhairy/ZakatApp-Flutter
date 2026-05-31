import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_profile.dart';

abstract class AuthService {
  Future<UserProfile?> signIn();
  Future<void> signOut();
  Future<UserProfile?> restoreSession();
}

class GoogleAuthService implements AuthService {
  GoogleAuthService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const <String>[
                'https://www.googleapis.com/auth/drive.file',
                'profile',
                'email',
              ],
            );

  final GoogleSignIn _googleSignIn;

  @override
  Future<UserProfile?> signIn() async {
    final GoogleSignInAccount? account = await _googleSignIn.signIn();
    if (account == null) return null;
    return _toProfile(account);
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  @override
  Future<UserProfile?> restoreSession() async {
    final GoogleSignInAccount? account = await _googleSignIn.signInSilently();
    if (account == null) return null;
    return _toProfile(account);
  }

  Future<UserProfile> _toProfile(GoogleSignInAccount account) async {
    final GoogleSignInAuthentication auth = await account.authentication;
    return UserProfile(
      id: account.id,
      email: account.email,
      name: account.displayName ?? account.email,
      photoUrl: account.photoUrl,
      accessToken: auth.accessToken,
    );
  }
}
