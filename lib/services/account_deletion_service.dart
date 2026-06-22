import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import 'account_deletion_auth_backend.dart';
import 'account_reauthentication_service.dart';
import 'app_state_controller.dart';
import 'auth_controller.dart';
import 'sync_diagnostics_service.dart';

class AccountDeletionService {
  AccountDeletionService({
    required this.appStateController,
    required this.authController,
    required this.authBackend,
    required this.reauthenticationService,
  });

  final AppStateController appStateController;
  final AuthController authController;
  final AccountDeletionAuthBackend authBackend;
  final AccountReauthenticationService reauthenticationService;

  Future<void> deleteAccount() async {
    final UserProfile? user = _currentUserProfile();
    if (user == null) {
      throw StateError('No signed-in user found.');
    }

    await _record(
      level: 'info',
      message: 'Delete requested',
      metadata: <String, dynamic>{
        'userId': user.id,
        'providers': authBackend.providerIds,
      },
    );

    final AccountReauthMethod? reauthMethod =
        await reauthenticationService.reauthenticateCurrentUser();
    if (reauthMethod == null) {
      await _record(
        level: 'warn',
        message: 'Reauth cancelled',
        metadata: <String, dynamic>{'userId': user.id},
      );
      throw StateError('Re-authentication was cancelled.');
    }

    await _record(
      level: 'info',
      message: 'Reauth succeeded',
      metadata: <String, dynamic>{
        'userId': user.id,
        'method': reauthMethod.name,
      },
    );

    await _deleteCloudData(user);
    await _deleteAuthAccount(user);
    Object? localCleanupError;
    StackTrace? localCleanupStackTrace;
    try {
      await _deleteLocalDataWithRetry(user);
    } catch (error, stackTrace) {
      localCleanupError = error;
      localCleanupStackTrace = stackTrace;
    }
    await _signOutAndFinalize(user);
    if (localCleanupError != null) {
      Error.throwWithStackTrace(
        localCleanupError,
        localCleanupStackTrace ?? StackTrace.current,
      );
    }
  }

  UserProfile? _currentUserProfile() {
    final String? uid = authBackend.uid;
    if (uid == null || uid.trim().isEmpty) {
      return null;
    }
    return UserProfile(
      id: uid,
      email: authBackend.email ?? '',
      displayName: authBackend.email ?? 'User',
      provider: authBackend.providerIds.contains('password')
          ? 'email'
          : authBackend.providerIds.contains('google.com')
              ? 'google'
              : 'google',
    );
  }

  Future<void> _deleteCloudData(UserProfile user) async {
    await _record(
      level: 'info',
      message: 'Cloud delete started',
      metadata: <String, dynamic>{'userId': user.id},
    );
    try {
      await appStateController.deleteCloudDataForUser(userId: user.id);
      await _record(
        level: 'info',
        message: 'Cloud delete completed',
        metadata: <String, dynamic>{'userId': user.id},
      );
    } catch (error, stackTrace) {
      debugPrint('AccountDeletionService cloud delete failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _record(
        level: 'error',
        message: 'Cloud delete failed',
        metadata: <String, dynamic>{
          'userId': user.id,
          'error': error.toString(),
        },
      );
      rethrow;
    }
  }

  Future<void> _deleteAuthAccount(UserProfile user) async {
    await _record(
      level: 'info',
      message: 'Auth delete started',
      metadata: <String, dynamic>{'userId': user.id},
    );
    try {
      await authBackend.deleteAccount();
      await _record(
        level: 'info',
        message: 'Auth delete completed',
        metadata: <String, dynamic>{'userId': user.id},
      );
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint('AccountDeletionService auth delete failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (error.code == 'requires-recent-login') {
        await _record(
          level: 'warn',
          message: 'Auth delete requires recent login',
          metadata: <String, dynamic>{'userId': user.id},
        );
        final AccountReauthMethod? retryMethod =
            await reauthenticationService.reauthenticateCurrentUser();
        if (retryMethod == null) {
          await _record(
            level: 'warn',
            message: 'Reauth cancelled',
            metadata: <String, dynamic>{'userId': user.id},
          );
          throw StateError('Re-authentication was cancelled.');
        }
        await _record(
          level: 'info',
          message: 'Reauth succeeded',
          metadata: <String, dynamic>{
            'userId': user.id,
            'method': retryMethod.name,
            'retry': true,
          },
        );
        await authBackend.deleteAccount();
        await _record(
          level: 'info',
          message: 'Auth delete completed',
          metadata: <String, dynamic>{
            'userId': user.id,
            'retry': true,
          },
        );
        return;
      }
      await _record(
        level: 'error',
        message: 'Auth delete failed',
        metadata: <String, dynamic>{
          'userId': user.id,
          'error': error.code,
        },
      );
      rethrow;
    }
  }

  Future<void> _deleteLocalDataWithRetry(UserProfile user) async {
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        await _record(
          level: 'info',
          message: 'Local cleanup started',
          metadata: <String, dynamic>{
            'userId': user.id,
            'attempt': attempt,
          },
        );
        await appStateController.deleteLocalDataForUser(userId: user.id);
        await _record(
          level: 'info',
          message: 'Local cleanup completed',
          metadata: <String, dynamic>{
            'userId': user.id,
            'attempt': attempt,
          },
        );
        return;
      } catch (error, stackTrace) {
        debugPrint(
          'AccountDeletionService local cleanup attempt $attempt failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        await _record(
          level: 'error',
          message: 'Local cleanup failed',
          metadata: <String, dynamic>{
            'userId': user.id,
            'attempt': attempt,
            'error': error.toString(),
          },
        );
        if (attempt == 2) {
          rethrow;
        }
      }
    }
  }

  Future<void> _signOutAndFinalize(UserProfile user) async {
    await _record(
      level: 'info',
      message: 'Sign out started',
      metadata: <String, dynamic>{'userId': user.id},
    );
    try {
      await authController.signOut();
      await _record(
        level: 'info',
        message: 'Sign out completed',
        metadata: <String, dynamic>{'userId': user.id},
      );
      await _record(
        level: 'info',
        message: 'Navigation completed',
        metadata: <String, dynamic>{'userId': user.id},
      );
    } catch (error, stackTrace) {
      debugPrint('AccountDeletionService sign out failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _record(
        level: 'error',
        message: 'Sign out failed',
        metadata: <String, dynamic>{
          'userId': user.id,
          'error': error.toString(),
        },
      );
      rethrow;
    }
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
}
