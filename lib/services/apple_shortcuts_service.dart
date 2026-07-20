import 'dart:convert';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app_state_controller.dart';
import '../models/pending_transaction.dart';

class AppleShortcutsService {
  AppleShortcutsService._();

  static const MethodChannel _channel = MethodChannel(
    'com.zakahwealth.smartcapture',
  );
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.zakahwealth.smartcapture.native',
  );
  static AppStateController? _appStateController;
  static bool _initialized = false;
  static bool _isFlushing = false;
  static bool _nativeReadyAcked = false;
  static int _initEpoch = 0;
  static String? _lastHandledNotificationLaunchToken;

  static void initialize(AppStateController appStateController) {
    if (_initialized && identical(_appStateController, appStateController)) {
      return;
    }
    _initialized = true;
    _initEpoch += 1;
    final int epoch = _initEpoch;
    _appStateController = appStateController;
    _channel.setMethodCallHandler(_handleMethodCall);
    debugPrint('[Shortcut] Flutter handler initialized');
    unawaited(_markNativeServiceReady(epoch));
    unawaited(_requestPendingShortcutMessages(epoch));
  }

  static Future<void> _markNativeServiceReady(int epoch) async {
    if (epoch != _initEpoch) {
      return;
    }
    if (_nativeReadyAcked) {
      return;
    }
    try {
      await _nativeChannel.invokeMethod<bool>('markShortcutServiceReady');
      if (epoch != _initEpoch) return;
      _nativeReadyAcked = true;
    } on MissingPluginException catch (e) {
      debugPrint('[Shortcut] Native ready handshake failed: $e');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (epoch != _initEpoch) {
        return;
      }
      try {
        await _nativeChannel.invokeMethod<bool>('markShortcutServiceReady');
        if (epoch != _initEpoch) return;
        _nativeReadyAcked = true;
      } catch (retryError) {
        debugPrint(
          '[Shortcut] Native ready handshake retry failed: $retryError',
        );
      }
    } catch (e) {
      debugPrint('[Shortcut] Native ready handshake failed: $e');
    }
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'logBankMessage' ||
        call.method == 'shortcutMessageReceived') {
      debugPrint('[Shortcut] Flutter received');
      return handleCapturePayload(
        call.arguments,
        source: PendingTransactionSource.shortcut,
      );
    }
    if (call.method == 'smsMessageReceived') {
      debugPrint('[SMS] Flutter received');
      return handleCapturePayload(
        call.arguments,
        source: PendingTransactionSource.sms,
      );
    }
    if (call.method == 'notificationLaunchReceived') {
      debugPrint('[SMS] Notification launch received');
      return handleNotificationLaunchPayload(call.arguments);
    }
    return false;
  }

  static Future<void> clearPendingShortcutMessages() {
    return _nativeChannel.invokeMethod<void>('clearPendingShortcutMessages');
  }

  static Future<bool> openShortcutsApp() async {
    if (!kIsWeb) {
      try {
        return await _nativeChannel.invokeMethod<bool>('openShortcutsApp') ??
            false;
      } catch (error) {
        debugPrint('AppleShortcutsService.openShortcutsApp failed: $error');
        return false;
      }
    }
    return false;
  }

  static Future<bool> simulateShortcutCapture(String messageText) {
    return handleCapturePayload(<String, dynamic>{
      'messageContent': messageText,
    }, source: PendingTransactionSource.shortcut);
  }

  static Future<bool> simulateSmsCapture(String messageText) {
    return handleCapturePayload(<String, dynamic>{
      'messageContent': messageText,
    }, source: PendingTransactionSource.sms);
  }

  @visibleForTesting
  static void resetForTests() {
    _channel.setMethodCallHandler(null);
    _appStateController = null;
    _initialized = false;
    _isFlushing = false;
    _nativeReadyAcked = false;
    _lastHandledNotificationLaunchToken = null;
    _initEpoch += 1;
  }

  static Future<void> _requestPendingShortcutMessages(int epoch) async {
    if (epoch != _initEpoch) {
      return;
    }
    if (_isFlushing) {
      return;
    }
    _isFlushing = true;
    try {
      debugPrint('[Shortcut] Requesting queued shortcut messages');
      List<dynamic>? rawQueuedMessages;
      try {
        rawQueuedMessages = await _nativeChannel.invokeMethod<List<dynamic>>(
          'getPendingShortcutMessages',
        );
        if (epoch != _initEpoch) return;
      } on MissingPluginException catch (e) {
        debugPrint('[Shortcut] Native drain failed: $e');
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (epoch != _initEpoch) {
          return;
        }
        try {
          rawQueuedMessages = await _nativeChannel.invokeMethod<List<dynamic>>(
            'getPendingShortcutMessages',
          );
          if (epoch != _initEpoch) return;
        } catch (retryError) {
          debugPrint('[Shortcut] Native drain retry failed: $retryError');
          return;
        }
      } catch (e) {
        debugPrint('[Shortcut] Native drain failed: $e');
        return;
      }

      final List<Map<String, dynamic>> queuedMessages =
          (rawQueuedMessages ?? <dynamic>[])
              .map((dynamic item) {
                if (item is String) {
                  return <String, dynamic>{
                    'messageContent': item,
                    'source': PendingTransactionSource.shortcut,
                  };
                }
                if (item is Map) {
                  return item.map(
                    (dynamic key, dynamic value) =>
                        MapEntry<String, dynamic>(key.toString(), value),
                  );
                }
                return <String, dynamic>{};
              })
              .where((Map<String, dynamic> item) {
                final String message = _extractMessageText(item)?.trim() ?? '';
                final bool isNotificationLaunch =
                    _extractNotificationLaunchToken(item) != null ||
                    _extractNotificationLaunchFlag(item);
                return message.isNotEmpty || isNotificationLaunch;
              })
              .toList(growable: false);

      if (epoch != _initEpoch) {
        return;
      }

      debugPrint(
        '[Shortcut] Queued messages received: ${queuedMessages.length}',
      );
      for (final Map<String, dynamic> payload in queuedMessages) {
        if (epoch != _initEpoch) {
          return;
        }
        if (_extractNotificationLaunchToken(payload) != null ||
            _extractNotificationLaunchFlag(payload)) {
          await handleNotificationLaunchPayload(payload);
          continue;
        }
        final String source =
            payload['source']?.toString() == PendingTransactionSource.sms
            ? PendingTransactionSource.sms
            : PendingTransactionSource.shortcut;
        await handleCapturePayload(payload, source: source);
      }
    } finally {
      _isFlushing = false;
    }
  }

  static Future<bool> handleLogBankMessagePayload(dynamic arguments) async {
    return handleCapturePayload(
      arguments,
      source: PendingTransactionSource.shortcut,
    );
  }

  static Future<bool> handleNotificationLaunchPayload(dynamic arguments) async {
    final String? tapToken = _extractNotificationLaunchToken(arguments);
    if (tapToken != null &&
        tapToken.isNotEmpty &&
        tapToken == _lastHandledNotificationLaunchToken) {
      debugPrint('[SMS] Ignored duplicate notification launch');
      return false;
    }
    if (tapToken != null && tapToken.isNotEmpty) {
      _lastHandledNotificationLaunchToken = tapToken;
    }

    final String payload = _encodeNotificationLaunchPayload(arguments);

    try {
      await _appStateController?.smartCaptureAlertService
          .handleNotificationResponse(
            NotificationResponse(
              notificationResponseType:
                  NotificationResponseType.selectedNotification,
              payload: payload,
            ),
          );
      return true;
    } catch (e) {
      debugPrint('Error routing smart capture notification launch: $e');
      return false;
    }
  }

  static Future<bool> handleCapturePayload(
    dynamic arguments, {
    required String source,
  }) async {
    final String? originalMessageText = _extractMessageText(arguments);
    if (originalMessageText == null) {
      debugPrint('[$source] Processing started');
      debugPrint('[$source] Rejected: missing payload');
      return false;
    }

    final String messageText = originalMessageText;
    final String trimmed = messageText.trim();
    debugPrint('[$source] Processing started');
    debugPrint('[$source] Flutter received message length: ${trimmed.length}');
    debugPrint(
      '[$source] First 100 chars: ${trimmed.substring(0, trimmed.length > 100 ? 100 : trimmed.length)}',
    );
    if (trimmed.isEmpty) {
      debugPrint('[$source] Rejected: empty payload');
      return false;
    }
    if (trimmed.length > 10000) {
      debugPrint('Smart capture message ignored: payload too large.');
      debugPrint('[$source] Rejected: payload too large');
      return false;
    }

    try {
      final int pendingBefore =
          _appStateController?.state.pendingTransactions.length ?? 0;
      final int transactionsBefore =
          _appStateController?.state.transactions.length ?? 0;
      final bool alreadyNotified = _extractNotificationAlreadyShown(arguments);
      final bool result =
          await _appStateController
              ?.createPendingTransactionFromMessageWithResult(
                trimmed,
                source,
                sourceIdentifier: source == PendingTransactionSource.sms
                    ? 'Android SMS'
                    : 'Apple Automation',
                sendNotification: !alreadyNotified,
              ) ??
          false;
      final String? launchToken = _extractNotificationLaunchToken(arguments);
      if (result &&
          (launchToken != null || _extractNotificationLaunchFlag(arguments))) {
        await _appStateController?.smartCaptureAlertService
            .handleNotificationResponse(
              NotificationResponse(
                notificationResponseType:
                    NotificationResponseType.selectedNotification,
                payload: _encodeNotificationLaunchPayload(arguments),
              ),
            );
      }
      debugPrint('[$source] Pending item created: $result');
      debugPrint(
        '[$source] AppState pending count after: ${_appStateController?.state.pendingTransactions.length ?? 0}',
      );
      debugPrint(
        '[$source] AppState transactions count after: ${_appStateController?.state.transactions.length ?? 0}',
      );
      debugPrint(
        '[$source] AppState captureAnalytics after: ${_appStateController?.state.captureAnalytics.toJson()}',
      );
      debugPrint(
        '[$source] AppState delta: pending=${(_appStateController?.state.pendingTransactions.length ?? 0) - pendingBefore}, transactions=${(_appStateController?.state.transactions.length ?? 0) - transactionsBefore}',
      );
      return result;
    } catch (e) {
      debugPrint('Error processing smart capture message: $e');
      return false;
    }
  }

  static String? _extractMessageText(dynamic arguments) {
    if (arguments is String) {
      return arguments;
    }
    if (arguments is Map) {
      final dynamic value =
          arguments['messageContent'] ?? arguments['messageText'];
      return value?.toString();
    }
    return null;
  }

  static bool _extractNotificationAlreadyShown(dynamic arguments) {
    if (arguments is Map) {
      final dynamic value = arguments['notificationAlreadyShown'];
      final String raw = value?.toString().trim().toLowerCase() ?? '';
      return raw == 'true' || raw == '1';
    }
    return false;
  }

  static bool _extractNotificationLaunchFlag(dynamic arguments) {
    if (arguments is Map) {
      final String flag = arguments['notificationTap']?.toString().trim() ?? '';
      return flag.toLowerCase() == 'true';
    }
    return false;
  }

  static String? _extractNotificationLaunchToken(dynamic arguments) {
    if (arguments is Map) {
      final String token =
          arguments['notificationTapToken']?.toString().trim() ?? '';
      return token.isEmpty ? null : token;
    }
    return null;
  }

  static String _encodeNotificationLaunchPayload(dynamic arguments) {
    final String? token = _extractNotificationLaunchToken(arguments);
    if (token != null && token.isNotEmpty) {
      return jsonEncode(<String, dynamic>{
        'notificationTap': 'true',
        'notificationTapToken': token,
      });
    }
    if (arguments is Map) {
      final bool tapped = _extractNotificationLaunchFlag(arguments);
      return jsonEncode(<String, dynamic>{
        'notificationTap': tapped ? 'true' : 'false',
      });
    }
    return jsonEncode(<String, dynamic>{'notificationTap': 'true'});
  }
}
