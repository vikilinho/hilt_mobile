import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app_permission_gate.dart';

const int _hydrationReminderMlPerCup = 200;
const String _remindersEnabledKey = 'hydration_smart_reminders_enabled';
const String _hydrationReminderChannelId = 'hydration_smart_reminders';
const String _hydrationReminderThreadId = 'hydration_smart_reminders';
const int _hydrationReminderIntervalHours = 2;
const int _hydrationReminderPreviewId = 6999;
const int _hydrationReminderScheduledId = 7000;

enum HydrationReminderEnableResult {
  enabled,
  disabled,
  denied,
  exactAlarmDenied,
  unavailable,
}

class HydrationReminderService {
  HydrationReminderService._();

  static final HydrationReminderService instance = HydrationReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isAvailable = false;
  Future<void>? _initializing;

  Future<void> initialize() async {
    if (_isAvailable) return;
    final inFlight = _initializing;
    if (inFlight != null) {
      return inFlight;
    }

    final initialization = _initializeInternal();
    _initializing = initialization;
    try {
      await initialization;
    } finally {
      _initializing = null;
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_remindersEnabledKey) ?? false;
  }

  Future<void> requestStartupPermissions() async {
    await initialize();

    if (Platform.isAndroid) {
      final notificationsGranted =
          await _requestAndroidNotificationPermission();
      if (notificationsGranted) {
        await _requestExactAlarmStartupPermission();
        await _ensureExactAlarmPermission();
      }
      return;
    }

    await _requestPermissions();
  }

  Future<HydrationReminderEnableResult> setEnabled(bool enabled) async {
    if (!enabled) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_remindersEnabledKey, false);
      await cancelScheduledReminders();
      return HydrationReminderEnableResult.disabled;
    }

    if (Platform.isAndroid) {
      final granted = await _requestAndroidNotificationPermission();
      if (!granted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_remindersEnabledKey, false);
        await cancelScheduledReminders();
        return HydrationReminderEnableResult.denied;
      }
    }

    await initialize();
    if (!_isAvailable) {
      return HydrationReminderEnableResult.unavailable;
    }

    if (Platform.isAndroid) {
      final exactAlarmGranted = await _ensureExactAlarmPermission();
      if (!exactAlarmGranted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_remindersEnabledKey, false);
        await cancelScheduledReminders();
        return HydrationReminderEnableResult.exactAlarmDenied;
      }
    }

    final granted = await _requestPermissions();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersEnabledKey, granted);

    if (!granted) {
      await cancelScheduledReminders();
      return HydrationReminderEnableResult.denied;
    }

    return HydrationReminderEnableResult.enabled;
  }

  Future<void> syncDailyReminders({
    required bool enabled,
    required int consumedMl,
    required int goalMl,
  }) async {
    await initialize();
    if (!_isAvailable) return;
    await cancelScheduledReminders();

    if (!enabled || consumedMl >= goalMl) return;
    if (!await _canScheduleRemindersSilently()) return;

    final now = DateTime.now();
    final notifications = _buildUpcomingReminders(
      now: now,
      consumedMl: consumedMl,
      goalMl: goalMl,
    );

    for (final reminder in notifications) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: 'Hydration check-in',
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _hydrationReminderChannelId,
            'Hydration reminders',
            channelDescription:
                'Smart nudges when you are behind your hydration goal.',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(
            threadIdentifier: _hydrationReminderThreadId,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exact,
      );
    }
  }

  Future<void> cancelScheduledReminders() async {
    await initialize();
    if (!_isAvailable) return;
    await _plugin.cancel(id: _hydrationReminderPreviewId);
    await _plugin.cancel(id: _hydrationReminderScheduledId);
    await _plugin.cancelAllPendingNotifications();
  }

  Future<void> _initializeInternal() async {
    try {
      tz.initializeTimeZones();
      await _configureLocalTimezone();

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('app_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _plugin.initialize(settings: settings);
      _isAvailable = true;
    } catch (error, stackTrace) {
      debugPrint(
        '[HydrationReminderService] Android notification init failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      _isAvailable = false;
    }
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone()
          .timeout(const Duration(seconds: 3));
      final identifier = _extractTimezoneIdentifier(timezone);
      tz.setLocalLocation(tz.getLocation(identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  String _extractTimezoneIdentifier(dynamic timezone) {
    if (timezone is String && timezone.isNotEmpty) {
      return timezone;
    }

    final dynamic identifier = timezone?.identifier;
    if (identifier is String && identifier.isNotEmpty) {
      return identifier;
    }

    return 'UTC';
  }

  List<_HydrationReminder> _buildUpcomingReminders({
    required DateTime now,
    required int consumedMl,
    required int goalMl,
  }) {
    final expectedMl = (goalMl * 0.2).round();
    final deficitMl = expectedMl - consumedMl;
    if (deficitMl <= (_hydrationReminderMlPerCup ~/ 2)) {
      return const [];
    }

    final cupsBehind = (deficitMl / _hydrationReminderMlPerCup).ceil();
    return [
      _HydrationReminder(
        id: _hydrationReminderScheduledId,
        when: now.add(const Duration(hours: _hydrationReminderIntervalHours)),
        body:
            'You\'re at ${_formatCupCount(consumedMl)} of ${_formatCupCount(goalMl)}. '
            'Drink ${_formatCupCount(cupsBehind * _hydrationReminderMlPerCup)} soon to stay on track.',
      ),
    ];
  }

  Future<bool> _requestPermissions() async {
    var granted = true;

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosGranted != null) {
      granted = granted && iosGranted;
    }

    return granted;
  }

  Future<bool> _requestAndroidNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final requested = await AppPermissionGate.request(
      Permission.notification,
      label: 'notifications',
    );
    return requested.isGranted;
  }

  Future<bool> _ensureExactAlarmPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;

    final alreadyGranted = await android.canScheduleExactNotifications();
    if (alreadyGranted == true) return true;

    final requested = await android.requestExactAlarmsPermission();
    if (requested == true) return true;

    return await android.canScheduleExactNotifications() ?? false;
  }

  Future<void> _requestExactAlarmStartupPermission() async {
    final status = await Permission.scheduleExactAlarm.status;
    if (status.isGranted) return;

    final requested = await AppPermissionGate.request(
      Permission.scheduleExactAlarm,
      label: 'exact alarm',
    );
    debugPrint(
      '[HydrationReminderService] Exact alarm permission: $requested',
    );
  }

  Future<bool> _canScheduleRemindersSilently() async {
    if (Platform.isAndroid) {
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) return false;

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;

      final exactAlarmGranted = await android.canScheduleExactNotifications();
      if (exactAlarmGranted != true) return false;
    }

    return true;
  }

  String _formatCupCount(int amountMl) {
    final cups = amountMl / _hydrationReminderMlPerCup;
    final display =
        cups % 1 == 0 ? cups.toStringAsFixed(0) : cups.toStringAsFixed(1);
    return '$display cup${cups == 1 ? '' : 's'}';
  }
}

class _HydrationReminder {
  const _HydrationReminder({
    required this.id,
    required this.when,
    required this.body,
  });

  final int id;
  final DateTime when;
  final String body;
}
