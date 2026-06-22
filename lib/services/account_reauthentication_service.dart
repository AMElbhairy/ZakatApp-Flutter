// ignore_for_file: prefer_initializing_formals
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'account_deletion_auth_backend.dart';
import '../models/user_profile.dart';
import 'sync_diagnostics_service.dart';

typedef PasswordPrompt = Future<String?> Function(UserProfile user);
typedef ReauthMethodChooser = Future<AccountReauthMethod?> Function({
  required List<AccountReauthMethod> availableMethods,
});
typedef GoogleReauthFlow = Future<AuthCredential?> Function();

enum AccountReauthMethod { google, password }

class AccountReauthenticationService {
  AccountReauthenticationService({
    required this.authBackend,
    required this.promptPassword,
    required this.chooseMethod,
    GoogleReauthFlow? googleReauthFlow,
    GoogleSignIn? googleSignIn,
  })  : _googleReauthFlow = googleReauthFlow,
        _googleSignIn = googleSignIn;

  final AccountDeletionAuthBackend authBackend;
  final GoogleSignIn? _googleSignIn;
  final GoogleReauthFlow? _googleReauthFlow;
  final PasswordPrompt promptPassword;
  final ReauthMethodChooser chooseMethod;

  GoogleSignIn get googleSignIn => _googleSignIn ?? GoogleSignIn(
    clientId: _iosClientId.trim().isEmpty ? null : _iosClientId,
    scopes: const <String>['profile', 'email'],
  );

  static const String _iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  Future<AccountReauthMethod?> reauthenticateCurrentUser() async {
    final List<String> providers = authBackend.providerIds;
    final Set<String> providerSet = providers
        .map((String id) => id.toLowerCase())
        .toSet();
    final List<AccountReauthMethod> availableMethods = <AccountReauthMethod>[
      if (providerSet.contains('google.com')) AccountReauthMethod.google,
      if (providerSet.contains('password')) AccountReauthMethod.password,
    ];
    await _record(
      level: 'info',
      message: 'Detected providers',
      metadata: <String, dynamic>{'providers': providers},
    );

    if (availableMethods.isEmpty) {
      throw StateError('No supported reauthentication method is linked.');
    }

    AccountReauthMethod selectedMethod;
    if (availableMethods.length == 1) {
      selectedMethod = availableMethods.first;
    } else {
      final AccountReauthMethod? chosen = await chooseMethod(
        availableMethods: availableMethods,
      );
      if (chosen == null) {
        return null;
      }
      selectedMethod = chosen;
    }

    await _record(
      level: 'info',
      message: 'Selected reauth method',
      metadata: <String, dynamic>{'method': selectedMethod.name},
    );
    await _record(
      level: 'info',
      message: 'Reauth started',
      metadata: <String, dynamic>{'method': selectedMethod.name},
    );

    try {
      switch (selectedMethod) {
        case AccountReauthMethod.password:
          final String? password = await promptPassword(
            UserProfile(
              id: authBackend.uid ?? '',
              email: authBackend.email ?? '',
              displayName: authBackend.email ?? 'User',
              provider: 'password',
            ),
          );
          if (password == null || password.trim().isEmpty) {
            await _record(
              level: 'warn',
              message: 'Reauth cancelled',
              metadata: <String, dynamic>{'method': selectedMethod.name},
            );
            return null;
          }
          final String email = authBackend.email?.trim() ?? '';
          if (email.isEmpty) {
            throw StateError('Password reauthentication requires an email.');
          }
          await authBackend.reauthenticateWithCredential(
            EmailAuthProvider.credential(email: email, password: password.trim()),
          );
          break;
        case AccountReauthMethod.google:
          final AuthCredential? credential =
              await _googleAuthenticate();
          if (credential == null) {
            await _record(
              level: 'warn',
              message: 'Reauth cancelled',
              metadata: <String, dynamic>{'method': selectedMethod.name},
            );
            return null;
          }
          await authBackend.reauthenticateWithCredential(credential);
          break;
      }
    } on FirebaseAuthException catch (error) {
      await _record(
        level: 'error',
        message: 'Reauth failed',
        metadata: <String, dynamic>{
          'method': selectedMethod.name,
          'error': error.code,
        },
      );
      rethrow;
    }

    await _record(
      level: 'info',
      message: 'Reauth succeeded',
      metadata: <String, dynamic>{'method': selectedMethod.name},
    );
    return selectedMethod;
  }

  Future<void> _record({
    required String level,
    required String message,
    required Map<String, dynamic> metadata,
  }) async {
    await SyncDiagnosticsService.record(
      level: level,
      subsystem: 'account',
      message: message,
      metadata: metadata,
    );
  }

  Future<AuthCredential?> _googleAuthenticate() async {
    final GoogleReauthFlow? flow = _googleReauthFlow;
    if (flow != null) {
      return flow();
    }
    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) {
      return null;
    }
    final GoogleSignInAuthentication authentication = await account.authentication;
    return GoogleAuthProvider.credential(
      accessToken: authentication.accessToken,
      idToken: authentication.idToken,
    );
  }
}
