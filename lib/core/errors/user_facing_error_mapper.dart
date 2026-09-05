import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../i18n/app_localizations.dart';

enum UserErrorCategory {
  network,
  timeout,
  authentication,
  authorization,
  permission,
  validation,
  parsing,
  duplicate,
  rejected,
  storage,
  backup,
  restore,
  sync,
  conflict,
  unavailableService,
  rateLimited,
  sessionExpired,
  unknown,
}

class UserFacingError {
  const UserFacingError({
    required this.category,
    required this.code,
    required this.messageKey,
    this.actionKey,
    this.cause,
  });

  final UserErrorCategory category;
  final String code;
  final String messageKey;
  final String? actionKey;

  // Retained for developer diagnostics only. Never render this directly.
  final Object? cause;
}

class UserFacingErrorMapper {
  const UserFacingErrorMapper._();

  static UserFacingError map(Object? error, {String? context}) {
    final String raw = error?.toString().toLowerCase() ?? '';
    final String operation = context?.toLowerCase() ?? '';

    if (error is TimeoutException ||
        raw.contains('timeout') ||
        raw.contains('timed out') ||
        raw.contains('errno = 60')) {
      return UserFacingError(
        category: UserErrorCategory.timeout,
        code: 'network.timeout',
        messageKey: 'error_network_timeout',
        cause: error,
      );
    }
    if (error is SocketException ||
        raw.contains('socketexception') ||
        raw.contains('network is unreachable') ||
        raw.contains('no internet') ||
        raw.contains('failed host lookup') ||
        raw.contains('connection refused')) {
      return UserFacingError(
        category: UserErrorCategory.network,
        code: 'network.offline',
        messageKey: 'error_network_offline',
        cause: error,
      );
    }
    if (error is PlatformException || raw.contains('permission')) {
      return UserFacingError(
        category: UserErrorCategory.permission,
        code: 'permission.required',
        messageKey: 'error_permission_required',
        cause: error,
      );
    }
    if (raw.contains('too many requests') || raw.contains('rate limit')) {
      return UserFacingError(
        category: UserErrorCategory.rateLimited,
        code: 'auth.rateLimited',
        messageKey: 'error_rate_limited',
        cause: error,
      );
    }
    if (raw.contains('user-disabled') ||
        raw.contains('account has been disabled')) {
      return UserFacingError(
        category: UserErrorCategory.authentication,
        code: 'auth.accountDisabled',
        messageKey: 'error_auth_account_disabled',
        cause: error,
      );
    }
    if (raw.contains('user-token-expired') ||
        raw.contains('invalid-user-token') ||
        raw.contains('session expired') ||
        raw.contains('requires-recent-login')) {
      return UserFacingError(
        category: UserErrorCategory.sessionExpired,
        code: 'auth.sessionExpired',
        messageKey: 'error_auth_session_expired',
        cause: error,
      );
    }
    if (raw.contains('wrong-password') ||
        raw.contains('invalid-credential') ||
        raw.contains('invalid credentials') ||
        raw.contains('incorrect password')) {
      return UserFacingError(
        category: UserErrorCategory.authentication,
        code: 'auth.invalidCredentials',
        messageKey: 'error_auth_invalid_credentials',
        cause: error,
      );
    }
    if (raw.contains('unauthorized') ||
        raw.contains('unauthenticated') ||
        raw.contains('access denied') ||
        raw.contains('permission-denied') ||
        raw.contains('403')) {
      return UserFacingError(
        category: UserErrorCategory.authorization,
        code: 'sync.authorizationFailed',
        messageKey: 'error_authorization_failed',
        cause: error,
      );
    }
    if (raw.contains('checksum mismatch') ||
        raw.contains('corrupt') ||
        raw.contains('damaged') ||
        raw.contains('invalid backup') ||
        raw.contains('not a json object')) {
      return UserFacingError(
        category: UserErrorCategory.restore,
        code: 'restore.invalidBackup',
        messageKey: 'error_restore_invalid_backup',
        cause: error,
      );
    }
    if (raw.contains('conflict') ||
        raw.contains('etag') ||
        raw.contains('revision mismatch')) {
      return UserFacingError(
        category: UserErrorCategory.conflict,
        code: 'sync.conflict',
        messageKey: 'error_sync_conflict',
        cause: error,
      );
    }
    if (operation.contains('restore')) {
      return UserFacingError(
        category: UserErrorCategory.restore,
        code: 'restore.failed',
        messageKey: 'error_restore_failed',
        cause: error,
      );
    }
    if (operation.contains('backup') || operation.contains('export')) {
      return UserFacingError(
        category: UserErrorCategory.backup,
        code: 'backup.failed',
        messageKey: 'error_backup_failed',
        cause: error,
      );
    }
    if (operation.contains('sync') ||
        operation.contains('pull') ||
        operation.contains('push')) {
      return UserFacingError(
        category: UserErrorCategory.sync,
        code: 'sync.failed',
        messageKey: 'error_sync_failed',
        cause: error,
      );
    }
    if (operation.contains('save') || operation.contains('write')) {
      return UserFacingError(
        category: UserErrorCategory.storage,
        code: 'storage.saveFailed',
        messageKey: 'error_save_failed',
        cause: error,
      );
    }
    if (operation.contains('parse') || operation.contains('import')) {
      return UserFacingError(
        category: UserErrorCategory.parsing,
        code: 'parsing.failed',
        messageKey: 'error_parsing_failed',
        cause: error,
      );
    }
    return UserFacingError(
      category: UserErrorCategory.unknown,
      code: 'unknown.general',
      messageKey: 'error_unknown',
      cause: error,
    );
  }

  static String message(
    AppLocalizations l10n,
    Object? error, {
    String? context,
  }) => l10n.tr(map(error, context: context).messageKey);
}
