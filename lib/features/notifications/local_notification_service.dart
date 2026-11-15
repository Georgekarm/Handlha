import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../tasks/domain/task.dart';
import 'native_alarm_bridge.dart';
import 'notification_preferences.dart';

/// Structured payload attached to scheduled notifications and ringing alarms.
class NotificationPayload {
  const NotificationPayload({
    required this.id,
    required this.title,
    required this.alertMode,
    this.taskId,
  });

  final String id;
  final String title;
  final String alertMode; // 'alarm' | 'notification'
  final String? taskId;

  bool get isAlarm => alertMode == 'alarm';

  String encode() => jsonEncode({
        'id': id,
        'title': title,
        'alertMode': alertMode,
        if (taskId != null) 'taskId': taskId,
      });

  static NotificationPayload? tryDecode(
    String? raw, {
    String fallbackTitle = '',
  }) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final id = (decoded['id'] ?? '').toString();
        if (id.isEmpty) return null;
        return NotificationPayload(
          id: id,
          title: (decoded['title'] ?? fallbackTitle).toString(),
          alertMode: (decoded['alertMode'] ?? 'notification').toString(),
          taskId: decoded['taskId']?.toString(),
        );
      }
    } catch (_) {
      // Backward compatibility: older scheduled notifications stored plain taskId.
    }
    return NotificationPayload(
      id: raw,
      title: fallbackTitle.isEmpty ? 'مهمة مجدولة' : fallbackTitle,
      alertMode: 'notification',
      taskId: raw,
    );
  }
}

/// Real OS notification & exact-alarm permission snapshot.
class NotificationPermissionStatus {
  const NotificationPermissionStatus({
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
    required this.hasNativePlatform,
  });

  final bool notificationsGranted;
  final bool exactAlarmsGranted;
  final bool hasNativePlatform;
}

/// Schedules real device notifications and full-screen alarms for tasks and
/// reminder items, with OS permission inspection and notification tap routing.
class LocalNotificationService {
  LocalNotificationService._();

  static final instance = LocalNotificationService._();

  static const _channelId = 'handelha_task_reminders';
  static const _channelName = 'تذكيرات هندلها';
  static const _channelDescription = 'إشعارات هادئة لتذكيرات المهام والمواعيد';

  static const _alarmChannelId = 'handelha_alarms_v2';
  static const _alarmChannelName = 'منبه هندلها';
  static const _alarmChannelDescription =
      'تنبيهات منبه كاملة الصوت للمهام المهمة والامتحانات';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationPayload> _tapController =
      StreamController<NotificationPayload>.broadcast();

  bool _initialized = false;
  NotificationPayload? _pendingLaunchPayload;
  String Function(String taskId)? taskAlertModeResolver;

  Stream<NotificationPayload> get onNotificationTap => _tapController.stream;

  NotificationPayload? takePendingLaunchPayload() {
    final next = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    return next;
  }

  Future<void> initialize({bool requestPermission = false}) async {
    if (_initialized) {
      if (requestPermission) {
        await requestPermissions(includeExactAlarm: false);
      }
      return;
    }
    try {
      tz_data.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
      } catch (_) {
        // Keep package default timezone if Cairo lookup is unavailable.
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _alarmChannelId,
          _alarmChannelName,
          description: _alarmChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );

      try {
        final launchDetails = await _plugin.getNotificationAppLaunchDetails();
        if (launchDetails != null &&
            launchDetails.didNotificationLaunchApp &&
            launchDetails.notificationResponse != null) {
          _pendingLaunchPayload = NotificationPayload.tryDecode(
            launchDetails.notificationResponse!.payload,
          );
        }
      } catch (_) {}

      _initialized = true;
      if (requestPermission) {
        await requestPermissions(includeExactAlarm: false);
      }
    } catch (_) {
      // Keep usable on desktop targets and headless widget tests.
      _initialized = false;
    }
  }

  void _handleNotificationResponse(NotificationResponse details) {
    final payload = NotificationPayload.tryDecode(details.payload);
    if (payload == null) return;
    _tapController.add(payload);
  }

  Future<bool> _safeAreNotificationsEnabled(
    AndroidFlutterLocalNotificationsPlugin androidPlugin,
  ) async {
    try {
      return await androidPlugin.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> _safeCanScheduleExact(
    AndroidFlutterLocalNotificationsPlugin androidPlugin,
  ) async {
    try {
      return await androidPlugin.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Queries actual OS notification and exact-alarm authorization.
  Future<NotificationPermissionStatus> checkPermissions() async {
    await initialize(requestPermission: false);
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final enabled = await _safeAreNotificationsEnabled(androidPlugin);
        final exact = await _safeCanScheduleExact(androidPlugin);
        return NotificationPermissionStatus(
          notificationsGranted: enabled,
          exactAlarmsGranted: exact,
          hasNativePlatform: true,
        );
      }
    } catch (_) {}

    return const NotificationPermissionStatus(
      notificationsGranted: false,
      exactAlarmsGranted: false,
      hasNativePlatform: false,
    );
  }

  /// Prompts the user at OS level for notification and (optionally) exact alarm permission.
  Future<NotificationPermissionStatus> requestPermissions({
    bool includeExactAlarm = true,
  }) async {
    await initialize(requestPermission: false);
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        try {
          await androidPlugin.requestNotificationsPermission();
        } catch (_) {}
        if (includeExactAlarm) {
          final canExact = await _safeCanScheduleExact(androidPlugin);
          if (!canExact) {
            try {
              await androidPlugin.requestExactAlarmsPermission();
            } catch (_) {}
          }
        }
        final enabled = await _safeAreNotificationsEnabled(androidPlugin);
        final exact = await _safeCanScheduleExact(androidPlugin);
        return NotificationPermissionStatus(
          notificationsGranted: enabled,
          exactAlarmsGranted: exact,
          hasNativePlatform: true,
        );
      }
    } catch (_) {}

    // Fallback on non-Android platforms or headless tests after user explicitly opted in.
    return const NotificationPermissionStatus(
      notificationsGranted: true,
      exactAlarmsGranted: true,
      hasNativePlatform: false,
    );
  }

  Future<void> scheduleReminderItem({
    required String id,
    required String title,
    required DateTime scheduledAt,
    required String alertMode,
    String? taskId,
    String userId = 'guest',
    bool requestPermission = false,
  }) async {
    try {
      await initialize(requestPermission: requestPermission);
      final isAlarm = alertMode == 'alarm';
      final preferences = await LocalNotificationPreferences.load(userId);
      if (!isAlarm && !preferences.enabled) {
        await cancelById(id);
        return;
      }

      final now = tz.TZDateTime.now(tz.local);
      var when = _tzDateTime(scheduledAt.toLocal());
      if (!isAlarm) {
        when = _moveOutOfQuietHours(when, preferences);
      }
      if (!when.isAfter(now)) {
        await cancelById(id);
        return;
      }

      if (isAlarm) {
        final scheduledNatively = await NativeAlarmBridge.instance.scheduleAlarm(
          id: id,
          title: title,
          scheduledAtMs: scheduledAt.toLocal().millisecondsSinceEpoch,
          alertMode: alertMode,
          taskId: taskId,
        );
        if (scheduledNatively) {
          // Avoid duplicate competing notification banners when AlarmReceiver
          // owns the external AlarmActivity & lockscreen notification.
          await _plugin.cancel(_notificationId(id));
          return;
        }
      } else {
        await NativeAlarmBridge.instance.cancelAlarm(id);
      }

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact = androidPlugin != null
          ? await _safeCanScheduleExact(androidPlugin)
          : false;
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      final payload = NotificationPayload(
        id: id,
        title: title,
        alertMode: alertMode,
        taskId: taskId,
      ).encode();

      final details = isAlarm
          ? NotificationDetails(
              android: AndroidNotificationDetails(
                _alarmChannelId,
                _alarmChannelName,
                channelDescription: _alarmChannelDescription,
                importance: Importance.max,
                priority: Priority.max,
                category: AndroidNotificationCategory.alarm,
                fullScreenIntent: true,
                audioAttributesUsage: AudioAttributesUsage.alarm,
                visibility: NotificationVisibility.public,
                additionalFlags: Int32List.fromList(<int>[4]),
                icon: '@mipmap/ic_launcher',
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentSound: true,
                interruptionLevel: InterruptionLevel.timeSensitive,
              ),
              macOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentSound: true,
              ),
            )
          : const NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                _channelName,
                channelDescription: _channelDescription,
                importance: Importance.high,
                priority: Priority.high,
                category: AndroidNotificationCategory.reminder,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: DarwinNotificationDetails(),
              macOS: DarwinNotificationDetails(),
            );

      final notificationTitle = isAlarm ? 'منبه هندلها' : 'تذكير من هندلها';
      final notificationId = _notificationId(id);
      try {
        await _plugin.zonedSchedule(
          notificationId,
          notificationTitle,
          title,
          when,
          details,
          androidScheduleMode: scheduleMode,
          payload: payload,
        );
      } catch (_) {
        if (scheduleMode != AndroidScheduleMode.exactAllowWhileIdle) rethrow;
        // Fallback to inexact scheduling when OEM restricts exact alarms at runtime.
        await _plugin.zonedSchedule(
          notificationId,
          notificationTitle,
          title,
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      }
    } catch (_) {
      // Notification support is best-effort and must not break task/reminder CRUD.
    }
  }

  Future<void> scheduleTask(
    Task task, {
    String? alertMode,
  }) async {
    final taskDate = task.dueAt ?? task.scheduledStartAt;
    if (taskDate == null ||
        task.isCompleted ||
        task.isCancelled ||
        task.isDeleted) {
      await cancelTask(task.id);
      return;
    }

    var local = taskDate.toLocal();
    if (_isDateOnly(local)) {
      local = DateTime(local.year, local.month, local.day, 9);
    }

    final resolvedMode =
        alertMode ?? taskAlertModeResolver?.call(task.id) ?? 'notification';

    await scheduleReminderItem(
      id: task.id,
      title: task.title,
      scheduledAt: local,
      alertMode: resolvedMode,
      taskId: task.id,
      userId: task.userId,
      requestPermission: false,
    );
  }

  Future<void> cancelById(String id) async {
    try {
      await NativeAlarmBridge.instance.cancelAlarm(id);
      await initialize();
      await _plugin.cancel(_notificationId(id));
    } catch (_) {
      // Safe to ignore when notifications are unavailable or permission is off.
    }
  }

  Future<void> cancelTask(String taskId) => cancelById(taskId);

  Future<void> cancelAll() async {
    try {
      await NativeAlarmBridge.instance.cancelAllAlarms();
      await initialize();
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<void> rescheduleTasks(
    Iterable<Task> tasks, {
    String Function(String taskId)? alertModeLookup,
  }) async {
    for (final task in tasks) {
      final mode = alertModeLookup?.call(task.id) ?? 'notification';
      await scheduleTask(task, alertMode: mode);
    }
  }

  int _notificationId(String id) {
    var hash = 17;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  tz.TZDateTime _tzDateTime(DateTime value) {
    final local = value.toLocal();
    return tz.TZDateTime(
      tz.local,
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
  }

  bool _isDateOnly(DateTime value) =>
      value.hour == 0 && value.minute == 0 && value.second == 0;

  tz.TZDateTime _moveOutOfQuietHours(
    tz.TZDateTime value,
    NotificationPreferences preferences,
  ) {
    final start = preferences.quietHoursStartMinutes;
    final end = preferences.quietHoursEndMinutes;
    final minute = value.hour * 60 + value.minute;
    final overnight = start > end;
    final quiet = overnight
        ? minute >= start || minute < end
        : (start < end && minute >= start && minute < end);
    if (!quiet) return value;

    if (overnight && minute < end) {
      return tz.TZDateTime(
        tz.local,
        value.year,
        value.month,
        value.day,
        end ~/ 60,
        end % 60,
      );
    }
    final nextDay = value.add(const Duration(days: 1));
    return tz.TZDateTime(
      tz.local,
      nextDay.year,
      nextDay.month,
      nextDay.day,
      end ~/ 60,
      end % 60,
    );
  }
}
