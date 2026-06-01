
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_profile.dart';

abstract class AuthService {
  Future<UserProfile?> signIn();
  Future<void> signOut();
  Future<UserProfile?> restoreSession();
}

class GoogleAuthService implements AuthService {
  static const String _iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  GoogleAuthService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              clientId: _iosClientId.trim().isEmpty ? null : _iosClientId,
              scopes: const <String>[
                'https://www.googleapis.com/auth/drive.appdata',
                'https://www.googleapis.com/auth/drive.file',
                'profile',
                'email',
              ],
            );

  final GoogleSignIn _googleSignIn;

  bool get _isConfiguredForCurrentPlatform {
    // Allow configuration via either `GOOGLE_IOS_CLIENT_ID` (dart-define)
    // or `GIDClientID` in Info.plist. The native plugin will read
    // Info.plist when `clientId` is not provided, so assume configured
    // and let the underlying plugin surface any errors if misconfigured.
    return true;
  }

  @override
  Future<UserProfile?> signIn() async {
    if (!_isConfiguredForCurrentPlatform) {
      throw StateError(
        'Google Sign-In is not configured on iOS. '
        'Set GOOGLE_IOS_CLIENT_ID (dart-define) or GIDClientID in Info.plist.',
      );
    }
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
    if (!_isConfiguredForCurrentPlatform) {
      return null;
    }
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
