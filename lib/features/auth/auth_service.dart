import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/user_profile.dart';

enum AuthProvider { google, apple }

extension AuthProviderX on AuthProvider {
  String get value => switch (this) {
    AuthProvider.google => 'google',
    AuthProvider.apple => 'apple',
  };

  static AuthProvider parse(String? raw) {
    return switch ((raw ?? '').toLowerCase().trim()) {
      'apple' => AuthProvider.apple,
      _ => AuthProvider.google,
    };
  }
}

abstract class AuthService {
  Future<UserProfile?> signIn({AuthProvider provider = AuthProvider.google});
  Future<void> signOut();
  Future<UserProfile?> restoreSession();
  Future<bool> ensureSession();
}

class CombinedAuthService implements AuthService {
  CombinedAuthService({
    GoogleAuthService? googleAuthService,
    AppleAuthService? appleAuthService,
  })  : _googleAuthService = googleAuthService ?? GoogleAuthService(),
        _appleAuthService = appleAuthService ?? AppleAuthService();

  final GoogleAuthService _googleAuthService;
  final AppleAuthService _appleAuthService;

  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) {
    return switch (provider) {
      AuthProvider.google => _googleAuthService.signIn(provider: provider),
      AuthProvider.apple => _appleAuthService.signIn(provider: provider),
    };
  }

  @override
  Future<void> signOut() async {
    await Future.wait(<Future<void>>[
      _googleAuthService.signOut(),
      _appleAuthService.signOut(),
    ]);
  }

  @override
  Future<UserProfile?> restoreSession() async {
    final UserProfile? restored = await _googleAuthService.restoreSession();
    if (restored != null) return restored;
    return _appleAuthService.restoreSession();
  }

  @override
  Future<bool> ensureSession() {
    return _googleAuthService.ensureSession();
  }
}

class GoogleAuthService implements AuthService {
  static const String _iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  GoogleAuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
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

  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) async {
    if (provider != AuthProvider.google) {
      throw StateError('GoogleAuthService only supports Google sign-in.');
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
  Future<bool> ensureSession() async {
    final GoogleSignInAccount? account = _googleSignIn.currentUser;
    if (account == null) return false;
    try {
      await account.authentication;
      return true;
    } catch (_) {
      return false;
    }
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
      displayName: account.displayName ?? account.email,
      provider: AuthProvider.google.value,
      photoUrl: account.photoUrl,
      accessToken: auth.accessToken,
    );
  }
}

class AppleAuthService implements AuthService {
  static const MethodChannel _channel = MethodChannel(
    'zakatapp_flutter/apple_sign_in',
  );

  @override
  Future<UserProfile?> signIn({
    AuthProvider provider = AuthProvider.google,
  }) async {
    if (provider != AuthProvider.apple) {
      throw StateError('AppleAuthService only supports Apple sign-in.');
    }
    final Map<dynamic, dynamic>? result;
    try {
      result = await _channel.invokeMethod<Map<dynamic, dynamic>>('signIn');
    } on MissingPluginException {
      throw StateError('Apple Sign In is not available on this build yet.');
    } on PlatformException catch (error) {
      throw StateError(error.message ?? 'Apple sign-in failed.');
    }
    if (result == null) return null;
    final String displayName = <String>[
      (result['givenName'] ?? '').toString(),
      (result['familyName'] ?? '').toString(),
    ].where((String part) => part.trim().isNotEmpty).join(' ').trim();
    return UserProfile(
      id: (result['userId'] ?? '').toString(),
      email: (result['email'] ?? '').toString(),
      displayName: displayName.isEmpty
          ? ((result['email'] ?? '').toString().isEmpty
                ? 'Apple User'
                : (result['email'] ?? '').toString())
          : displayName,
      provider: AuthProvider.apple.value,
      photoUrl: null,
      accessToken: (result['identityToken'] ?? '').toString(),
    );
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> ensureSession() async => true;

  @override
  Future<UserProfile?> restoreSession() async => null;
}
