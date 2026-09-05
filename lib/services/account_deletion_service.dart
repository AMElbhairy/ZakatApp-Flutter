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
    this.deleteCloudBackupData,
  });

  final AppStateController appStateController;
  final AuthController authController;
  final AccountDeletionAuthBackend authBackend;
  final AccountReauthenticationService reauthenticationService;
  final Future<void> Function(UserProfile user)? deleteCloudBackupData;

  Future<void> deleteAccount({bool requireReauth = false}) async {
    final UserProfile? user = _currentUserProfile() ?? authController.currentUser;
    final String userId =
        (user?.id ?? appStateController.state.userId ?? '').trim();

    if (userId.isEmpty && user == null) {
      // Guest or anonymous mode cleanup
      await appStateController.deleteLocalDataForUser(userId: 'anonymous');
      await authController.signOut();
      return;
    }

    final UserProfile effectiveUser = user ??
        UserProfile(
          id: userId,
          email: appStateController.state.userEmail ?? '',
          displayName: 'User',
          provider: appStateController.state.userProvider ?? 'local',
        );

    await _record(
      level: 'info',
      message: 'Delete requested',
      metadata: <String, dynamic>{
        'userId': effectiveUser.id,
        'providers': authBackend.providerIds,
      },
    );

    if (requireReauth) {
      final AccountReauthMethod? reauthMethod = await reauthenticationService
          .reauthenticateCurrentUser();
      if (reauthMethod == null) {
        await _record(
          level: 'warn',
          message: 'Reauth cancelled',
          metadata: <String, dynamic>{'userId': effectiveUser.id},
        );
        throw StateError('Re-authentication was cancelled.');
      }
      await _record(
        level: 'info',
        message: 'Reauth succeeded',
        metadata: <String, dynamic>{
          'userId': effectiveUser.id,
          'method': reauthMethod.name,
        },
      );
    }

    // 1. Delete all online cloud data (Google Drive, iCloud, Firestore)
    await _deleteCloudData(effectiveUser);

    // 2. Delete Firebase Auth user credentials
    await _deleteAuthAccount(
      effectiveUser,
      allowSkipOnAuthFailure: !requireReauth,
    );

    // 3. Delete all local database files, local snapshots, secure storage & widgets
    Object? localCleanupError;
    StackTrace? localCleanupStackTrace;
    try {
      await _deleteLocalDataWithRetry(effectiveUser);
    } catch (error, stackTrace) {
      localCleanupError = error;
      localCleanupStackTrace = stackTrace;
    }

    // 4. Sign out & finalize
    await _signOutAndFinalize(effectiveUser);

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
      return authController.currentUser;
    }
    return UserProfile(
      id: uid,
      email: authBackend.email ?? authController.currentUser?.email ?? '',
      displayName: authBackend.email ?? authController.currentUser?.displayName ?? 'User',
      provider: authBackend.providerIds.contains('password')
          ? 'email'
          : authBackend.providerIds.contains('google.com')
          ? 'google'
          : (authController.currentUser?.provider ?? 'local'),
    );
  }

  Future<void> _deleteCloudData(UserProfile user) async {
    await _record(
      level: 'info',
      message: 'Cloud delete started',
      metadata: <String, dynamic>{'userId': user.id},
    );
    if (deleteCloudBackupData != null) {
      try {
        await deleteCloudBackupData!(user);
      } catch (error, stackTrace) {
        debugPrint('AccountDeletionService Drive cleanup failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        await _record(
          level: 'warn',
          message: 'Drive cleanup failed',
          metadata: <String, dynamic>{
            'userId': user.id,
            'error': error.toString(),
          },
        );
      }
    }
    try {
      await appStateController.deleteCloudDataForUser(userId: user.id);
    } catch (error, stackTrace) {
      debugPrint('AccountDeletionService cloud delete failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _record(
        level: 'warn',
        message: 'Cloud delete skipped',
        metadata: <String, dynamic>{
          'userId': user.id,
          'error': error.toString(),
        },
      );
    }
    await _record(
      level: 'info',
      message: 'Cloud delete completed',
      metadata: <String, dynamic>{'userId': user.id},
    );
  }

  Future<void> _deleteAuthAccount(
    UserProfile user, {
    bool allowSkipOnAuthFailure = true,
  }) async {
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
      if (error.code == 'requires-recent-login' && !allowSkipOnAuthFailure) {
        await _record(
          level: 'warn',
          message: 'Auth delete requires recent login',
          metadata: <String, dynamic>{'userId': user.id},
        );
        final AccountReauthMethod? retryMethod = await reauthenticationService
            .reauthenticateCurrentUser();
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
          metadata: <String, dynamic>{'userId': user.id, 'retry': true},
        );
        return;
      }
      await _record(
        level: 'warn',
        message: 'Auth delete skipped or failed',
        metadata: <String, dynamic>{'userId': user.id, 'error': error.code},
      );
      if (!allowSkipOnAuthFailure) {
        rethrow;
      }
    } catch (error, stackTrace) {
      debugPrint('AccountDeletionService auth delete error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!allowSkipOnAuthFailure) {
        rethrow;
      }
    }
  }

  Future<void> _deleteLocalDataWithRetry(UserProfile user) async {
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        await _record(
          level: 'info',
          message: 'Local cleanup started',
          metadata: <String, dynamic>{'userId': user.id, 'attempt': attempt},
        );
        await appStateController.deleteLocalDataForUser(userId: user.id);
        await _record(
          level: 'info',
          message: 'Local cleanup completed',
          metadata: <String, dynamic>{'userId': user.id, 'attempt': attempt},
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
