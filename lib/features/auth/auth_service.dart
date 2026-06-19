import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../models/user_profile.dart';

enum AuthProvider { google, apple, email }

extension AuthProviderX on AuthProvider {
  String get value => switch (this) {
    AuthProvider.google => 'google',
    AuthProvider.apple => 'apple',
    AuthProvider.email => 'email',
  };

  static AuthProvider parse(String? raw) {
    return switch ((raw ?? '').toLowerCase().trim()) {
      'apple' => AuthProvider.apple,
      'email' => AuthProvider.email,
      _ => AuthProvider.google,
    };
  }
}

enum AuthGateStatus { checking, signedOut, signedIn, tokenExpired, error }

class AuthGateState {
  const AuthGateState({required this.status, this.user, this.message});

  final AuthGateStatus status;
  final UserProfile? user;
  final String? message;
}

abstract class AuthService {
  Future<UserProfile?> signIn({AuthProvider provider = AuthProvider.google});
  Future<UserProfile?> signInWithEmail({
    required String email,
    required String password,
  });
  Future<UserProfile?> createAccountWithEmail({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> sendPasswordResetEmail({required String email});
  Future<void> sendEmailVerification();
  Future<UserProfile?> reloadCurrentUser();
  Future<bool> isCurrentUserEmailVerified();
  Future<void> signOut();
  Future<void> deleteAccount();
  Future<UserProfile?> restoreSession();
  Future<bool> ensureSession();
}

abstract class AuthGateStateSource {
  Stream<AuthGateState> get authGateStateChanges;
}

class FirebaseAuthService implements AuthService, AuthGateStateSource {
  static const String _iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  FirebaseAuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            clientId: _iosClientId.trim().isEmpty ? null : _iosClientId,
            scopes: const <String>['profile', 'email'],
          ) {
    _authGateStateController.add(
      const AuthGateState(status: AuthGateStatus.checking),
    );
    _firebaseAuth.authStateChanges().listen(
      (User? user) {
        unawaited(_emitGateStateFromUser(user));
      },
      onError: (Object error) {
        _authGateStateController.add(
          AuthGateState(
            status: AuthGateStatus.error,
            message: error.toString(),
          ),
        );
      },
    );
  }

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  final StreamController<AuthGateState> _authGateStateController =
      StreamController<AuthGateState>.broadcast();

  @override
  Stream<AuthGateState> get authGateStateChanges =>
      _authGateStateController.stream;

  Future<void> _emitGateStateFromUser(User? user) async {
    if (user == null) {
      _authGateStateController.add(
        const AuthGateState(status: AuthGateStatus.signedOut),
      );
      return;
    }
    try {
      final UserProfile profile = await _toProfile(
        user,
        provider: _inferProvider(user),
      );
      _authGateStateController.add(
        AuthGateState(status: AuthGateStatus.signedIn, user: profile),
      );
    } catch (error) {
      _authGateStateController.add(
        AuthGateState(status: AuthGateStatus.error, message: error.toString()),
      );
    }
  }

  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) async {
    try {
      switch (provider) {
        case AuthProvider.google:
          return _signInGoogle();
        case AuthProvider.apple:
          return _signInApple();
        case AuthProvider.email:
          throw StateError('Use email/password sign-in for email accounts.');
      }
    } on FirebaseAuthException catch (error) {
      if (_isTokenExpired(error)) {
        _authGateStateController.add(
          const AuthGateState(status: AuthGateStatus.tokenExpired),
        );
      } else {
        _authGateStateController.add(
          AuthGateState(
            status: AuthGateStatus.error,
            message: _readableAuthError(error),
          ),
        );
      }
      throw StateError(_readableAuthError(error));
    } on SignInWithAppleAuthorizationException catch (error) {
      _authGateStateController.add(
        AuthGateState(
          status: AuthGateStatus.error,
          message: 'Apple sign-in failed: ${error.message}',
        ),
      );
      throw StateError('Apple sign-in failed: ${error.message}');
    }
  }

  @override
  Future<UserProfile?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);
      final User? user = userCredential.user;
      if (user == null) return null;
      return _toProfile(user, provider: AuthProvider.email);
    } on FirebaseAuthException catch (error) {
      _authGateStateController.add(
        AuthGateState(
          status: AuthGateStatus.error,
          message: _readableAuthError(error),
        ),
      );
      throw StateError(_readableAuthError(error));
    }
  }

  @override
  Future<UserProfile?> createAccountWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);
      final User? user = userCredential.user;
      if (user == null) return null;
      if (displayName.trim().isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
      }
      await user.sendEmailVerification();
      await user.reload();
      final User? refreshed = _firebaseAuth.currentUser;
      if (refreshed == null) return null;
      return _toProfile(refreshed, provider: AuthProvider.email);
    } on FirebaseAuthException catch (error) {
      _authGateStateController.add(
        AuthGateState(
          status: AuthGateStatus.error,
          message: _readableAuthError(error),
        ),
      );
      throw StateError(_readableAuthError(error));
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      throw StateError(_readableAuthError(error));
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) return;
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw StateError(_readableAuthError(error));
    }
  }

  @override
  Future<UserProfile?> reloadCurrentUser() async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) return null;
    await user.reload();
    final User? refreshed = _firebaseAuth.currentUser;
    if (refreshed == null) return null;
    return _toProfile(refreshed, provider: _inferProvider(refreshed));
  }

  @override
  Future<bool> isCurrentUserEmailVerified() async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _firebaseAuth.currentUser?.emailVerified == true;
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Best-effort sign out from Google provider state.
    }
    await _firebaseAuth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final User? currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return;
    await currentUser.delete();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  @override
  Future<bool> ensureSession() async {
    final User? current = _firebaseAuth.currentUser;
    if (current == null) return false;
    try {
      await current.getIdToken(true);
      return true;
    } on FirebaseAuthException catch (error) {
      if (_isTokenExpired(error)) {
        _authGateStateController.add(
          const AuthGateState(status: AuthGateStatus.tokenExpired),
        );
      }
      return false;
    }
  }

  @override
  Future<UserProfile?> restoreSession() async {
    final User? current = _firebaseAuth.currentUser;
    if (current == null) return null;
    try {
      await current.reload();
      final User? reloaded = _firebaseAuth.currentUser;
      if (reloaded == null) return null;
      return _toProfile(reloaded, provider: _inferProvider(reloaded));
    } on FirebaseAuthException catch (error) {
      if (_isTokenExpired(error)) {
        _authGateStateController.add(
          const AuthGateState(status: AuthGateStatus.tokenExpired),
        );
      }
      return null;
    }
  }

  Future<UserProfile?> _signInGoogle() async {
    final GoogleSignInAccount? account = await _googleSignIn.signIn();
    if (account == null) return null;
    final GoogleSignInAuthentication auth = await account.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    final UserCredential userCredential = await _firebaseAuth
        .signInWithCredential(credential);
    final User? user = userCredential.user;
    if (user == null) return null;
    return _toProfile(
      user,
      provider: AuthProvider.google,
      accessToken: auth.accessToken,
    );
  }

  Future<UserProfile?> _signInApple() async {
    final bool isAvailable = await SignInWithApple.isAvailable();
    if (!isAvailable) {
      throw StateError('Apple Sign In is not available on this device.');
    }

    final AuthorizationCredentialAppleID appleCredential =
        await SignInWithApple.getAppleIDCredential(
          scopes: const <AppleIDAuthorizationScopes>[
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

    final OAuthCredential credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final UserCredential userCredential = await _firebaseAuth
        .signInWithCredential(credential);
    final User? user = userCredential.user;
    if (user == null) return null;

    final String displayName = <String>[
      appleCredential.givenName ?? '',
      appleCredential.familyName ?? '',
    ].where((String part) => part.trim().isNotEmpty).join(' ').trim();
    if (displayName.isNotEmpty) {
      await user.updateDisplayName(displayName);
    }
    return _toProfile(
      user,
      provider: AuthProvider.apple,
      accessToken: appleCredential.identityToken,
    );
  }

  Future<UserProfile> _toProfile(
    User user, {
    required AuthProvider provider,
    String? accessToken,
  }) async {
    final String? idToken = await user.getIdToken();
    return UserProfile(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? user.email ?? 'User',
      provider: provider.value,
      emailVerified: user.emailVerified,
      photoUrl: user.photoURL,
      accessToken: accessToken ?? idToken,
    );
  }

  AuthProvider _inferProvider(User user) {
    for (final UserInfo info in user.providerData) {
      if (info.providerId == 'apple.com') return AuthProvider.apple;
      if (info.providerId == 'password') return AuthProvider.email;
    }
    return AuthProvider.google;
  }

  bool _isTokenExpired(FirebaseAuthException error) {
    const Set<String> expiredCodes = <String>{
      'user-token-expired',
      'invalid-user-token',
      'requires-recent-login',
    };
    return expiredCodes.contains(error.code.toLowerCase());
  }

  String _readableAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-disabled':
        return 'Your account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'invalid-verification-code':
        return 'Could not verify your sign-in credentials.';
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account was found for this email.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
}

class CombinedAuthService extends FirebaseAuthService {
  CombinedAuthService({super.firebaseAuth, super.googleSignIn});
}
