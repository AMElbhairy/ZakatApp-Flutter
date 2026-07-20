import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/app_localizations.dart';
import '../core/services/zakat_engine.dart';
import '../screens/account/notifications_screen.dart';
import '../models/pending_transaction.dart';
import 'smart_capture_parser.dart';

abstract class SmartCaptureAlertService {
  const SmartCaptureAlertService();

  void attachNavigatorKey(GlobalKey<NavigatorState> navigatorKey);

  Future<void> initialize();

  Future<bool> areAndroidNotificationsEnabled();

  Future<bool> requestAndroidNotificationsPermission();

  Future<void> syncPendingReviewBadge(int pendingReviewCount);

  Future<void> flushPendingNotificationLaunch();

  Future<void> handleNotificationResponse(NotificationResponse response);

  Future<void> notifyCaptureState({
    required PendingTransaction pendingTransaction,
  });

  Future<void> notifyPendingReview({
    required PendingTransaction pendingTransaction,
    required int pendingReviewCount,
  });
}

class NoopSmartCaptureAlertService extends SmartCaptureAlertService {
  const NoopSmartCaptureAlertService();

  @override
  void attachNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {}

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> areAndroidNotificationsEnabled() async => false;

  @override
  Future<bool> requestAndroidNotificationsPermission() async => false;

  @override
  Future<void> flushPendingNotificationLaunch() async {}

  @override
  Future<void> handleNotificationResponse(
    NotificationResponse response,
  ) async {}

  @override
  Future<void> notifyCaptureState({
    required PendingTransaction pendingTransaction,
  }) async {}

  @override
  Future<void> notifyPendingReview({
    required PendingTransaction pendingTransaction,
    required int pendingReviewCount,
  }) async {}

  @override
  Future<void> syncPendingReviewBadge(int pendingReviewCount) async {}
}

class PlatformSmartCaptureAlertService extends SmartCaptureAlertService {
  PlatformSmartCaptureAlertService()
    : _notifications = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notifications;
  static const String _androidSmallIcon = 'notification_icon';
  static const String _languagePreferenceKey = 'language_preference';
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  bool _notificationsAvailable = false;
  bool _queuedInboxLaunch = false;
  String? _queuedNotificationLaunchSignature;
  final List<String> _recentNotificationLaunchSignatures = <String>[];

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'smart_capture_pending_review',
    'Capture Review',
    description: 'Alerts when a captured transaction needs approval.',
    importance: Importance.high,
  );

  @override
  void attachNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const AndroidInitializationSettings android =
          AndroidInitializationSettings(_androidSmallIcon);
      const DarwinInitializationSettings darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const InitializationSettings settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );

      await _notifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: handleNotificationResponse,
      );
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      await androidPlugin?.createNotificationChannel(_channel);
      await _requestNotificationPermissions();
      _notificationsAvailable = true;

      final NotificationAppLaunchDetails? launchDetails = await _notifications
          .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final NotificationResponse? response =
            launchDetails?.notificationResponse;
        if (response != null) {
          await handleNotificationResponse(response);
        }
      }
      await flushPendingNotificationLaunch();
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SmartCaptureAlertService initialize failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _notificationsAvailable = false;
    } catch (error, stackTrace) {
      debugPrint('SmartCaptureAlertService initialize failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _notificationsAvailable = false;
    } finally {
      _initialized = true;
    }
  }

  Future<void> _requestNotificationPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      return;
    }

    final IOSFlutterLocalNotificationsPlugin? iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
      return;
    }

    final MacOSFlutterLocalNotificationsPlugin? macosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macosPlugin != null) {
      await macosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  @override
  Future<bool> areAndroidNotificationsEnabled() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return false;
    try {
      return await androidPlugin.areNotificationsEnabled() ?? false;
    } catch (error, stackTrace) {
      debugPrint('SmartCaptureAlertService notification check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<bool> requestAndroidNotificationsPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return false;
    try {
      return await androidPlugin.requestNotificationsPermission() ?? false;
    } catch (error, stackTrace) {
      debugPrint(
        'SmartCaptureAlertService notification permission failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<void> syncPendingReviewBadge(int pendingReviewCount) async {
    try {
      if (pendingReviewCount <= 0) {
        await FlutterAppBadger.removeBadge();
      } else {
        await FlutterAppBadger.updateBadgeCount(pendingReviewCount);
      }
    } catch (error) {
      debugPrint('SmartCaptureAlertService badge sync failed: $error');
    }
  }

  @override
  Future<void> flushPendingNotificationLaunch() async {
    if (!_queuedInboxLaunch) return;
    if (!await _routeToCaptureInbox()) return;
    _queuedInboxLaunch = false;
    _queuedNotificationLaunchSignature = null;
  }

  @override
  Future<void> handleNotificationResponse(NotificationResponse response) async {
    final String signature = _extractNotificationLaunchSignature(
      response.payload,
    );
    if (_recentNotificationLaunchSignatures.contains(signature) ||
        signature == _queuedNotificationLaunchSignature) {
      return;
    }
    _recentNotificationLaunchSignatures.add(signature);
    while (_recentNotificationLaunchSignatures.length > 12) {
      _recentNotificationLaunchSignatures.removeAt(0);
    }
    _queuedInboxLaunch = true;
    _queuedNotificationLaunchSignature = signature;
    await flushPendingNotificationLaunch();
  }

  String _extractNotificationLaunchSignature(String? payload) {
    final String raw = (payload ?? '').trim();
    if (raw.isEmpty) return 'empty';

    try {
      final Object decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final String? token = decoded['notificationTapToken']
            ?.toString()
            .trim();
        if (token != null && token.isNotEmpty) return 'token:$token';

        final String? pendingTransactionId = decoded['pendingTransactionId']
            ?.toString()
            .trim();
        if (pendingTransactionId != null && pendingTransactionId.isNotEmpty) {
          return 'pending:$pendingTransactionId';
        }

        final String? target = decoded['targetInboxStatus']?.toString().trim();
        if (target != null && target.isNotEmpty) return 'target:$target';
      }
    } catch (_) {}

    return 'raw:$raw';
  }

  Future<bool> _routeToCaptureInbox() async {
    final GlobalKey<NavigatorState>? navigatorKey = _navigatorKey;
    final NavigatorState? navigator = navigatorKey?.currentState;
    if (navigator == null) return false;

    unawaited(navigator.push(NotificationsScreen.route()));
    return true;
  }

  @override
  Future<void> notifyCaptureState({
    required PendingTransaction pendingTransaction,
  }) async {
    await initialize();
    if (!_notificationsAvailable) return;
    final String languageCode = await _notificationLanguageCode();
    final AppLocalizations l10n = AppLocalizations(Locale(languageCode));
    final bool isArabic = languageCode == 'ar';

    final String rawType = pendingTransaction.suggestedType
        .trim()
        .toLowerCase();
    final String currencyCode =
        pendingTransaction.suggestedCurrency?.trim().isNotEmpty == true
        ? pendingTransaction.suggestedCurrency!.trim()
        : 'EGP';
    final SmartCaptureParseResult parsed = SmartCaptureParser.parse(
      pendingTransaction.rawMessage,
    );
    final CaptureStatus displayStatus =
        parsed.isValid ? pendingTransaction.status : CaptureStatus.ignored;
    final String amountStr = pendingTransaction.suggestedAmount != null
        ? '${_formatCaptureAmount(pendingTransaction.suggestedAmount!)} ${ZakatEngineService.getCurrencySymbol(currencyCode)}'
        : parsed.amount != null
            ? '${_formatCaptureAmount(parsed.amount!)} ${ZakatEngineService.getCurrencySymbol(parsed.currency?.trim().isNotEmpty == true ? parsed.currency!.trim() : currencyCode)}'
            : 'Amount not captured';
    final String merchant = _notificationMerchantText(
      pendingTransaction,
      parsed,
    );

    final String title = switch (displayStatus) {
      CaptureStatus.pendingReview => l10n.smartCapturePendingForApproval,
      CaptureStatus.autoApproved => l10n.smartCaptureAutoApproved,
      CaptureStatus.manuallyApproved => l10n.smartCaptureAutoApproved,
      CaptureStatus.ignored => l10n.smartCaptureRejected,
    };
    final String body = <String>[merchant, amountStr]
        .where((String line) => line.trim().isNotEmpty)
        .map((String line) => _localizedNotificationLine(line: line))
        .join('\n');

    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        icon: _androidSmallIcon,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _notifications.show(
        id: pendingTransaction.id.hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: details,
        payload: jsonEncode(<String, dynamic>{
          'pendingTransactionId': pendingTransaction.id,
          'notificationTapToken': pendingTransaction.id,
          'captureStatus': pendingTransaction.status.name,
          'rawType': rawType,
        }),
      );
    } catch (error) {
      debugPrint('SmartCaptureAlertService notification failed: $error');
    }
  }

  @override
  Future<void> notifyPendingReview({
    required PendingTransaction pendingTransaction,
    required int pendingReviewCount,
  }) async {
    await notifyCaptureState(pendingTransaction: pendingTransaction);
  }

  static String _formatCaptureAmount(double amount) {
    final String fixed = amount.toStringAsFixed(2);
    if (!fixed.contains('.')) {
      return fixed;
    }
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<String> _notificationLanguageCode() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String normalized =
          prefs.getString(_languagePreferenceKey)?.trim().toLowerCase() ?? '';
      if (normalized == 'ar') {
        return 'ar';
      }
    } catch (error, stackTrace) {
      debugPrint('SmartCaptureAlertService language lookup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return 'en';
  }

  static String _localizedNotificationLine({
    required String line,
  }) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) return trimmed;
    return '\u200E$trimmed';
  }

  static String _notificationMerchantText(
    PendingTransaction pendingTransaction,
    SmartCaptureParseResult parsed,
  ) {
    final String? explicitMerchant = pendingTransaction.merchantName?.trim();
    if (explicitMerchant != null && explicitMerchant.isNotEmpty) {
      return explicitMerchant;
    }

    final String? parsedMerchant = parsed.merchantName?.trim();
    if (parsedMerchant != null && parsedMerchant.isNotEmpty) {
      return parsedMerchant;
    }

    final String rawMessage = pendingTransaction.rawMessage.trim();
    if (rawMessage.isNotEmpty) {
      final String? extracted = _extractMerchantFromMessage(rawMessage);
      if (extracted != null && extracted.isNotEmpty) {
        return extracted;
      }
    }

    final String parsedDescription = parsed.description.trim();
    if (parsedDescription.isNotEmpty) {
      return parsedDescription;
    }

    final String? description = pendingTransaction.suggestedDescription?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }

    return pendingTransaction.sourceDisplayLabel;
  }

  static String? _extractMerchantFromMessage(String message) {
    final List<RegExp> patterns = <RegExp>[
      RegExp(
        r"\b(?:at|merchant|store|from|to)\s*[:\-]?\s*([A-Za-z0-9&'().\-\u0600-\u06FF ]{2,80})",
        caseSensitive: false,
      ),
      RegExp(
        r"\b(?:عند|لدى|من|إلى|الى)\s*[:\-]?\s*([A-Za-z0-9&'().\-\u0600-\u06FF ]{2,80})",
        caseSensitive: false,
      ),
    ];
    for (final RegExp pattern in patterns) {
      final Match? match = pattern.firstMatch(message);
      final String? candidate = match?.group(1)?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }

    final List<String> lines = message
        .replaceAll('\r', '\n')
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    for (final String line in lines) {
      final String lower = line.toLowerCase();
      if (lower.contains('otp') ||
          lower.contains('verification') ||
          lower.contains('code') ||
          lower.contains('amount') ||
          lower.contains('مبلغ') ||
          lower.contains('الرصيد')) {
        continue;
      }
      if (RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(line) &&
          !RegExp(r'^\d+([.,]\d+)?$').hasMatch(line)) {
        return line;
      }
    }
    return null;
  }
}
