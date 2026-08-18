import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/recurring_transaction.dart';

class RecurringNotificationManager {
  RecurringNotificationManager._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _timezoneInitialized = false;

  static Future<void> _ensureTimezoneInitialized() async {
    if (_timezoneInitialized) return;
    try {
      tz.initializeTimeZones();
      _timezoneInitialized = true;
    } catch (e) {
      debugPrint('Error initializing timezone: $e');
    }
  }

  /// Calculates the next occurrence date-time for a recurring transaction.
  static DateTime calculateNextNotificationDateTime(
    RecurringTransaction recurring,
    DateTime now,
  ) {
    final int safeDay = recurring.dayOfMonth.clamp(1, 31);
    final List<String> parts = recurring.reminderTime.split(':');
    final int hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 9) : 9;
    final int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    // Construct scheduled date in the current month
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    int targetDay = safeDay > daysInMonth ? daysInMonth : safeDay;

    // Apply day offset
    targetDay -= recurring.reminderDayOffset;

    // If target day falls below 1, we roll back to previous month
    DateTime scheduledDate;
    if (targetDay < 1) {
      final prevMonth = DateTime(now.year, now.month, 0); // Last day of previous month
      final dayVal = prevMonth.day + targetDay; // e.g. 30 + (-0) = 30
      scheduledDate = DateTime(
          prevMonth.year, prevMonth.month, dayVal, hour, minute);
    } else {
      scheduledDate = DateTime(now.year, now.month, targetDay, hour, minute);
    }

    // If next notification date-time has already passed, move to next month
    if (scheduledDate.isBefore(now)) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final int daysInNextMonth =
          DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
      int nextTargetDay = safeDay > daysInNextMonth ? daysInNextMonth : safeDay;
      nextTargetDay -= recurring.reminderDayOffset;

      if (nextTargetDay < 1) {
        final prevOfNext = DateTime(nextMonth.year, nextMonth.month, 0);
        final dayVal = prevOfNext.day + nextTargetDay;
        scheduledDate = DateTime(
            prevOfNext.year, prevOfNext.month, dayVal, hour, minute);
      } else {
        scheduledDate = DateTime(
            nextMonth.year, nextMonth.month, nextTargetDay, hour, minute);
      }
    }
    return scheduledDate;
  }

  /// Unique integer ID for notification scheduling
  static int _getNotificationId(String stringId) {
    return stringId.hashCode & 0x7fffffff;
  }

  /// Schedules local notification reminder for a recurring transaction
  static Future<void> scheduleReminder(RecurringTransaction recurring) async {
    final int notificationId = _getNotificationId(recurring.id);

    // Cancel existing reminder first
    try {
      await _notifications.cancel(id: notificationId);
    } catch (_) {}

    if (!recurring.enabled || !recurring.reminderEnabled) {
      return;
    }

    await _ensureTimezoneInitialized();

    final DateTime now = DateTime.now();
    final DateTime targetDateTime =
        calculateNextNotificationDateTime(recurring, now);

    final tz.TZDateTime tzScheduled =
        tz.TZDateTime.from(targetDateTime, tz.local);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'recurring_reminders_channel',
      'Recurring Reminders',
      channelDescription: 'Reminders for recurring payments or income transactions.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
      macOS: iOSDetails,
    );

    try {
      await _notifications.zonedSchedule(
        id: notificationId,
        title: 'Reminder: ${recurring.name}',
        body: 'Your recurring transaction of ${recurring.amount.toStringAsFixed(recurring.amount.truncateToDouble() == recurring.amount ? 0 : 2)} ${recurring.currency} is scheduled.',
        scheduledDate: tzScheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: jsonEncode(<String, dynamic>{
          'recurringTransactionId': recurring.id,
          'type': 'recurring_reminder',
        }),
      );
    } catch (e) {
      debugPrint('Error scheduling recurring notification: $e');
    }
  }

  /// Cancels scheduled reminder notification
  static Future<void> cancelNotification(String stringId) async {
    final int notificationId = _getNotificationId(stringId);
    try {
      await _notifications.cancel(id: notificationId);
    } catch (_) {}
  }
}
