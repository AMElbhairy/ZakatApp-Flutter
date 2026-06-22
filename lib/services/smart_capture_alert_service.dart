import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:provider/provider.dart';

import '../screens/account/notifications_screen.dart';
import '../screens/account/review_pending_transaction_screen.dart';
import 'app_state_controller.dart';
import '../models/pending_transaction.dart';

abstract class SmartCaptureAlertService {
  const SmartCaptureAlertService();

  void attachNavigatorKey(GlobalKey<NavigatorState> navigatorKey);

  Future<void> initialize();

  Future<void> syncPendingReviewBadge(int pendingReviewCount);

  Future<void> flushPendingNotificationLaunch();

  Future<void> handleNotificationResponse(NotificationResponse response);

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
  Future<void> flushPendingNotificationLaunch() async {}

  @override
  Future<void> handleNotificationResponse(
    NotificationResponse response,
  ) async {}

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
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  String? _queuedPendingTransactionId;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'smart_capture_pending_review',
    'Smart Capture review',
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

    const AndroidInitializationSettings android = AndroidInitializationSettings(
      'launcher_icon',
    );
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
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);
    _initialized = true;

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
    final String? pendingTransactionId = _queuedPendingTransactionId;
    if (pendingTransactionId == null || pendingTransactionId.isEmpty) return;
    if (!await _routeToPendingTransactionReview(pendingTransactionId)) return;
    _queuedPendingTransactionId = null;
  }

  @override
  Future<void> handleNotificationResponse(NotificationResponse response) async {
    final String? pendingTransactionId = _extractPendingTransactionId(
      response.payload,
    );
    if (pendingTransactionId == null || pendingTransactionId.isEmpty) return;
    if (!await _routeToPendingTransactionReview(pendingTransactionId)) {
      _queuedPendingTransactionId = pendingTransactionId;
    }
  }

  @override
  Future<void> notifyPendingReview({
    required PendingTransaction pendingTransaction,
    required int pendingReviewCount,
  }) async {
    await initialize();

    final String rawType = pendingTransaction.suggestedType.trim().toLowerCase();
    final String title = switch (rawType) {
      'income' => 'Pending Income',
      'expense' => 'Pending Expense',
      'transfer' => 'Pending Transfer',
      _ => 'Pending Review',
    };

    final String amountStr = pendingTransaction.suggestedAmount != null
        ? '${pendingTransaction.suggestedCurrency ?? 'EGP'} ${pendingTransaction.suggestedAmount!.toStringAsFixed(2)}'
        : 'Amount not captured';

    final String body = pendingTransaction.merchantName?.trim().isNotEmpty == true
        ? '${pendingTransaction.merchantName!.trim()}: $amountStr'
        : amountStr;

    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        icon: 'launcher_icon',
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
          'pendingReviewCount': pendingReviewCount,
        }),
      );
    } catch (error) {
      debugPrint('SmartCaptureAlertService notification failed: $error');
    }
  }

  String? _extractPendingTransactionId(String? payload) {
    final String raw = (payload ?? '').trim();
    if (raw.isEmpty) return null;

    try {
      final Object decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final String? id = decoded['pendingTransactionId']?.toString();
        return id?.trim().isEmpty == true ? null : id?.trim();
      }
    } catch (_) {}

    return null;
  }

  Future<bool> _routeToPendingTransactionReview(
    String pendingTransactionId,
  ) async {
    final GlobalKey<NavigatorState>? navigatorKey = _navigatorKey;
    final BuildContext? context = navigatorKey?.currentContext;
    final NavigatorState? navigator = navigatorKey?.currentState;
    if (context == null || navigator == null) return false;

    final AppStateController controller = context.read<AppStateController>();
    final List<PendingTransaction> matches = controller
        .state
        .pendingTransactions
        .where((PendingTransaction item) => item.id == pendingTransactionId)
        .toList(growable: false);
    if (matches.isEmpty) {
      navigator.push(NotificationsScreen.route());
      return true;
    }

    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ReviewPendingTransactionScreen(pendingTransaction: matches.first),
        ),
      ),
    );
    return true;
  }
}
