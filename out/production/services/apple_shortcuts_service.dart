import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
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
        debugPrint('[Shortcut] Native ready handshake retry failed: $retryError');
      }
    } catch (e) {
      debugPrint('[Shortcut] Native ready handshake failed: $e');
    }
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'logBankMessage' ||
        call.method == 'shortcutMessageReceived') {
      debugPrint('[Shortcut] Flutter received');
      return handleLogBankMessagePayload(call.arguments);
    }
    return false;
  }

  static Future<void> clearPendingShortcutMessages() {
    return _nativeChannel.invokeMethod<void>('clearPendingShortcutMessages');
  }

  static Future<bool> simulateShortcutCapture(String messageText) {
    return handleLogBankMessagePayload(<String, dynamic>{
      'messageContent': messageText,
      });
  }

  @visibleForTesting
  static void resetForTests() {
    _channel.setMethodCallHandler(null);
    _appStateController = null;
    _initialized = false;
    _isFlushing = false;
    _nativeReadyAcked = false;
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

      final List<String> queuedMessages = (rawQueuedMessages ?? <dynamic>[])
          .whereType<String>()
          .map((String message) => message.trim())
          .where((String message) => message.isNotEmpty)
          .toList(growable: false);

      if (epoch != _initEpoch) {
        return;
      }

      debugPrint('[Shortcut] Queued messages received: ${queuedMessages.length}');
      for (final String messageText in queuedMessages) {
        if (epoch != _initEpoch) {
          return;
        }
        await handleLogBankMessagePayload(
          <String, dynamic>{'messageContent': messageText},
        );
      }
    } finally {
      _isFlushing = false;
    }
  }

  static Future<bool> handleLogBankMessagePayload(dynamic arguments) async {
    final String? originalMessageText = _extractMessageText(arguments);
    if (originalMessageText == null) {
      debugPrint('[Shortcut] Processing started');
      debugPrint('[Shortcut] Rejected: missing payload');
      return false;
    }

    final String messageText = originalMessageText;
    final String trimmed = messageText.trim();
    debugPrint('[Shortcut] Processing started');
    debugPrint('[Shortcut] Flutter received message length: ${trimmed.length}');
    debugPrint(
      '[Shortcut] First 100 chars: ${trimmed.substring(0, trimmed.length > 100 ? 100 : trimmed.length)}',
    );
    if (trimmed.isEmpty) {
      debugPrint('[Shortcut] Rejected: empty payload');
      return false;
    }
    if (trimmed.length > 10000) {
      debugPrint('Apple Shortcut message ignored: payload too large.');
      debugPrint('[Shortcut] Rejected: payload too large');
      return false;
    }

    try {
      final int pendingBefore = _appStateController?.state.pendingTransactions.length ?? 0;
      final int transactionsBefore = _appStateController?.state.transactions.length ?? 0;
      final bool result = await _appStateController
              ?.createPendingTransactionFromMessageWithResult(
                trimmed,
                PendingTransactionSource.shortcut,
                sourceIdentifier: 'Apple Automation',
              ) ??
          false;
      debugPrint('[Shortcut] Pending item created: $result');
      debugPrint(
        '[Shortcut] AppState pending count after: ${_appStateController?.state.pendingTransactions.length ?? 0}',
      );
      debugPrint(
        '[Shortcut] AppState transactions count after: ${_appStateController?.state.transactions.length ?? 0}',
      );
      debugPrint(
        '[Shortcut] AppState captureAnalytics after: ${_appStateController?.state.captureAnalytics.toJson()}',
      );
      debugPrint(
        '[Shortcut] AppState delta: pending=${(_appStateController?.state.pendingTransactions.length ?? 0) - pendingBefore}, transactions=${(_appStateController?.state.transactions.length ?? 0) - transactionsBefore}',
      );
      return result;
    } catch (e) {
      debugPrint('Error processing Apple Shortcut message: $e');
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
}
