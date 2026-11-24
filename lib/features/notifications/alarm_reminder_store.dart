import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../authentication/presentation/auth_providers.dart';
import 'local_notification_service.dart';

/// Mode of delivery when a reminder/alarm triggers:
/// - `alarm`: Full-screen ringing alarm UI with melodic chime + snooze.
/// - `notification`: Quiet notification message banner & inbox card.
class AlarmReminderItem {
  const AlarmReminderItem({
    required this.id,
    required this.title,
    required this.scheduledAt,
    this.alertMode = 'alarm', // 'alarm' | 'notification'
    this.isEnabled = true,
    this.taskId,
    this.scheduleStatus = 'unknown',
  });

  final String id;
  final String title;
  final DateTime scheduledAt;
  final String alertMode; // 'alarm' | 'notification'
  final bool isEnabled;
  final String? taskId;

  /// Persisted last OS schedule outcome (`exactScheduled` | `inexactFallback` |
  /// `permissionDenied` | `disabledByPreferences` | `pastTime` | `failed` | `unknown`).
  final String scheduleStatus;

  bool get isFullAlarm => alertMode == 'alarm';

  AlarmReminderItem copyWith({
    String? id,
    String? title,
    DateTime? scheduledAt,
    String? alertMode,
    bool? isEnabled,
    String? taskId,
    String? scheduleStatus,
  }) {
    return AlarmReminderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      alertMode: alertMode ?? this.alertMode,
      isEnabled: isEnabled ?? this.isEnabled,
      taskId: taskId ?? this.taskId,
      scheduleStatus: scheduleStatus ?? this.scheduleStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'scheduledAt': scheduledAt.toIso8601String(),
        'alertMode': alertMode,
        'isEnabled': isEnabled,
        'taskId': taskId,
        'scheduleStatus': scheduleStatus,
      };

  factory AlarmReminderItem.fromJson(Map<String, dynamic> json) {
    return AlarmReminderItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      scheduledAt:
          DateTime.tryParse((json['scheduledAt'] ?? '').toString()) ??
              DateTime.now().add(const Duration(hours: 1)),
      alertMode: (json['alertMode'] ?? 'alarm').toString(),
      isEnabled: json['isEnabled'] != false,
      taskId: json['taskId']?.toString(),
      scheduleStatus: (json['scheduleStatus'] ?? 'unknown').toString(),
    );
  }
}

class AlarmReminderState {
  const AlarmReminderState({
    this.permissionGranted = false,
    this.exactAlarmGranted = false,
    this.defaultAlertMode = 'alarm', // 'alarm' | 'notification'
    this.items = const [],
    this.taskAlertModes = const {},
  });

  final bool permissionGranted;
  final bool exactAlarmGranted;
  final String defaultAlertMode;
  final List<AlarmReminderItem> items;
  final Map<String, String> taskAlertModes;

  String alertModeForTask(String taskId, {String fallback = 'notification'}) =>
      taskAlertModes[taskId] ?? fallback;

  AlarmReminderState copyWith({
    bool? permissionGranted,
    bool? exactAlarmGranted,
    String? defaultAlertMode,
    List<AlarmReminderItem>? items,
    Map<String, String>? taskAlertModes,
  }) {
    return AlarmReminderState(
      permissionGranted: permissionGranted ?? this.permissionGranted,
      exactAlarmGranted: exactAlarmGranted ?? this.exactAlarmGranted,
      defaultAlertMode: defaultAlertMode ?? this.defaultAlertMode,
      items: items ?? this.items,
      taskAlertModes: taskAlertModes ?? this.taskAlertModes,
    );
  }
}

class AlarmReminderStore {
  static AlarmReminderState _current = const AlarmReminderState();

  static AlarmReminderState get current => _current;

  static String _permKey(String userId) => 'handelha_notif_perm_$userId';
  static String _exactPermKey(String userId) =>
      'handelha_exact_alarm_perm_$userId';
  static String _modeKey(String userId) => 'handelha_default_alert_mode_$userId';
  static String _itemsKey(String userId) => 'handelha_alarms_list_$userId';
  static String _taskModesKey(String userId) =>
      'handelha_task_alert_modes_$userId';

  static Future<AlarmReminderState> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var perm = prefs.getBool(_permKey(userId)) ?? false;
      var exactPerm = prefs.getBool(_exactPermKey(userId)) ?? false;
      final mode = prefs.getString(_modeKey(userId)) ?? 'alarm';

      final osStatus = await LocalNotificationService.instance.checkPermissions();
      if (osStatus.hasNativePlatform) {
        perm = osStatus.notificationsGranted;
        exactPerm = osStatus.exactAlarmsGranted;
      }

      final raw = prefs.getString(_itemsKey(userId));
      var list = <AlarmReminderItem>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        list = decoded
            .whereType<Map>()
            .map((e) => AlarmReminderItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      }

      final rawModes = prefs.getString(_taskModesKey(userId));
      var taskModes = <String, String>{};
      if (rawModes != null && rawModes.isNotEmpty) {
        final decoded = jsonDecode(rawModes) as Map<String, dynamic>;
        taskModes = decoded.map((k, v) => MapEntry(k, v.toString()));
      }

      _current = AlarmReminderState(
        permissionGranted: perm,
        exactAlarmGranted: exactPerm,
        defaultAlertMode: mode,
        items: list,
        taskAlertModes: taskModes,
      );
      LocalNotificationService.instance.taskAlertModeResolver =
          (id) => _current.alertModeForTask(id);
      return _current;
    } catch (_) {
      return _current;
    }
  }

  static Future<void> save(String userId, AlarmReminderState state) async {
    _current = state;
    LocalNotificationService.instance.taskAlertModeResolver =
        (id) => _current.alertModeForTask(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_permKey(userId), state.permissionGranted);
      await prefs.setBool(_exactPermKey(userId), state.exactAlarmGranted);
      await prefs.setString(_modeKey(userId), state.defaultAlertMode);
      await prefs.setString(
        _itemsKey(userId),
        jsonEncode([for (final item in state.items) item.toJson()]),
      );
      await prefs.setString(
        _taskModesKey(userId),
        jsonEncode(state.taskAlertModes),
      );
    } catch (_) {}
  }

  static Future<bool> requestUserPermission(
    String userId, {
    bool includeExactAlarm = true,
  }) async {
    final status = await LocalNotificationService.instance.requestPermissions(
      includeExactAlarm: includeExactAlarm,
    );
    final next = _current.copyWith(
      permissionGranted: status.notificationsGranted,
      exactAlarmGranted: status.exactAlarmsGranted,
    );
    await save(userId, next);
    return status.notificationsGranted;
  }

  static Future<void> setTaskAlertMode(
    String userId,
    String taskId,
    String alertMode,
  ) async {
    final nextModes = Map<String, String>.from(_current.taskAlertModes)
      ..[taskId] = alertMode;
    final next = _current.copyWith(taskAlertModes: nextModes);
    await save(userId, next);
  }

  static Future<void> clearForUser(String userId) async {
    _current = const AlarmReminderState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_permKey(userId));
      await prefs.remove(_exactPermKey(userId));
      await prefs.remove(_modeKey(userId));
      await prefs.remove(_itemsKey(userId));
      await prefs.remove(_taskModesKey(userId));
    } catch (_) {}
  }
}

class AlarmReminderNotifier extends StateNotifier<AlarmReminderState> {
  AlarmReminderNotifier(this._userId) : super(AlarmReminderStore.current) {
    _load();
  }

  final String _userId;

  Future<void> _load() async {
    final loaded = await AlarmReminderStore.load(_userId);
    if (mounted) {
      state = loaded;
    }
    await _syncFutureItems(loaded.items);
  }

  Future<void> _syncFutureItems(List<AlarmReminderItem> items) async {
    final now = DateTime.now();
    for (final item in items) {
      if (item.isEnabled && item.scheduledAt.isAfter(now)) {
        await LocalNotificationService.instance.scheduleReminderItem(
          id: item.id,
          title: item.title,
          scheduledAt: item.scheduledAt,
          alertMode: item.alertMode,
          taskId: item.taskId,
          userId: _userId,
          requestPermission: false,
        );
      }
    }
  }

  Future<void> refreshPermissions() async {
    final status = await LocalNotificationService.instance.checkPermissions();
    if (!status.hasNativePlatform) return;
    final next = state.copyWith(
      permissionGranted: status.notificationsGranted,
      exactAlarmGranted: status.exactAlarmsGranted,
    );
    if (mounted) state = next;
    await AlarmReminderStore.save(_userId, next);
  }

  Future<bool> requestPermission({bool includeExactAlarm = true}) async {
    final granted = await AlarmReminderStore.requestUserPermission(
      _userId,
      includeExactAlarm: includeExactAlarm,
    );
    if (mounted) {
      state = AlarmReminderStore.current;
    }
    if (granted) {
      await _syncFutureItems(state.items);
    }
    return granted;
  }

  Future<void> setDefaultAlertMode(String mode) async {
    final next = state.copyWith(defaultAlertMode: mode);
    state = next;
    await AlarmReminderStore.save(_userId, next);
  }

  Future<void> setTaskAlertMode(String taskId, String mode) async {
    final nextModes = Map<String, String>.from(state.taskAlertModes)
      ..[taskId] = mode;
    final next = state.copyWith(taskAlertModes: nextModes);
    state = next;
    await AlarmReminderStore.save(_userId, next);
  }

  Future<AlarmReminderItem> addOrUpdateAlarm({
    String? id,
    required String title,
    required DateTime scheduledAt,
    required String alertMode,
    String? taskId,
    bool requestPermission = false,
  }) async {
    final resolvedId =
        id ?? taskId ?? 'alarm_${DateTime.now().millisecondsSinceEpoch}';
    final outcome = await LocalNotificationService.instance.scheduleReminderItem(
      id: resolvedId,
      title: title,
      scheduledAt: scheduledAt,
      alertMode: alertMode,
      taskId: taskId,
      userId: _userId,
      requestPermission: requestPermission,
    );
    final item = AlarmReminderItem(
      id: resolvedId,
      title: title,
      scheduledAt: scheduledAt,
      alertMode: alertMode,
      isEnabled: true,
      taskId: taskId,
      scheduleStatus: outcome.status.name,
    );
    final nextModes = Map<String, String>.from(state.taskAlertModes);
    if (taskId != null) {
      nextModes[taskId] = alertMode;
    }
    final filtered = state.items.where((e) => e.id != item.id).toList();
    final updated = [item, ...filtered]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final next = state.copyWith(
      defaultAlertMode: alertMode,
      items: updated,
      taskAlertModes: nextModes,
    );
    state = next;
    await AlarmReminderStore.save(_userId, next);
    return item;
  }

  Future<void> toggleItemAlertMode(String id) async {
    AlarmReminderItem? changed;
    final updated = [
      for (final item in state.items)
        if (item.id == id)
          (changed = item.copyWith(
            alertMode: item.isFullAlarm ? 'notification' : 'alarm',
          ))
        else
          item,
    ];
    final nextModes = Map<String, String>.from(state.taskAlertModes);
    if (changed?.taskId != null) {
      nextModes[changed!.taskId!] = changed.alertMode;
    }
    var nextItems = updated;
    if (changed != null && changed.isEnabled) {
      final outcome =
          await LocalNotificationService.instance.scheduleReminderItem(
        id: changed.id,
        title: changed.title,
        scheduledAt: changed.scheduledAt,
        alertMode: changed.alertMode,
        taskId: changed.taskId,
        userId: _userId,
      );
      nextItems = [
        for (final item in updated)
          if (item.id == changed.id)
            item.copyWith(scheduleStatus: outcome.status.name)
          else
            item,
      ];
    }
    final next = state.copyWith(items: nextItems, taskAlertModes: nextModes);
    state = next;
    await AlarmReminderStore.save(_userId, next);
  }

  Future<void> toggleItemEnabled(String id) async {
    AlarmReminderItem? changed;
    final updated = [
      for (final item in state.items)
        if (item.id == id)
          (changed = item.copyWith(isEnabled: !item.isEnabled))
        else
          item,
    ];
    var nextItems = updated;
    if (changed != null) {
      if (changed.isEnabled) {
        final outcome =
            await LocalNotificationService.instance.scheduleReminderItem(
          id: changed.id,
          title: changed.title,
          scheduledAt: changed.scheduledAt,
          alertMode: changed.alertMode,
          taskId: changed.taskId,
          userId: _userId,
        );
        nextItems = [
          for (final item in updated)
            if (item.id == changed.id)
              item.copyWith(scheduleStatus: outcome.status.name)
            else
              item,
        ];
      } else {
        await LocalNotificationService.instance.cancelById(changed.id);
      }
    }
    final next = state.copyWith(items: nextItems);
    state = next;
    await AlarmReminderStore.save(_userId, next);
  }

  Future<AlarmReminderItem> snoozeAlarm(
    String id, {
    required String fallbackTitle,
    String? taskId,
    int minutes = 5,
  }) async {
    final existing = state.items.where((e) => e.id == id).firstOrNull;
    final snoozedAt = DateTime.now().add(Duration(minutes: minutes));
    return addOrUpdateAlarm(
      id: existing?.id ?? id,
      title: existing?.title ?? fallbackTitle,
      scheduledAt: snoozedAt,
      alertMode: 'alarm',
      taskId: existing?.taskId ?? taskId,
    );
  }

  Future<void> markAlarmDismissed(String id) async {
    final hasItem = state.items.any((e) => e.id == id);
    if (!hasItem) return;
    final updated = [
      for (final item in state.items)
        if (item.id == id) item.copyWith(isEnabled: false) else item,
    ];
    final next = state.copyWith(items: updated);
    state = next;
    await AlarmReminderStore.save(_userId, next);
    await LocalNotificationService.instance.cancelById(id);
  }

  Future<void> removeAlarm(String id) async {
    final updated = state.items.where((e) => e.id != id).toList();
    final next = state.copyWith(items: updated);
    state = next;
    await AlarmReminderStore.save(_userId, next);
    await LocalNotificationService.instance.cancelById(id);
  }
}

final alarmReminderProvider =
    StateNotifierProvider<AlarmReminderNotifier, AlarmReminderState>((ref) {
  final user = ref.watch(authNotifierProvider).value;
  final userId = user?.id ?? 'guest';
  return AlarmReminderNotifier(userId);
});
