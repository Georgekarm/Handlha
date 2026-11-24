import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class NativeAlarmCapabilities {
  const NativeAlarmCapabilities({
    this.exactAlarm = true,
    this.canDrawOverlays = true,
    this.fullScreenIntent = true,
  });

  final bool exactAlarm;
  final bool canDrawOverlays;
  final bool fullScreenIntent;
}

@immutable
class NativeAlarmScheduleResult {
  const NativeAlarmScheduleResult({
    required this.scheduled,
    required this.exact,
    required this.mode,
  });

  const NativeAlarmScheduleResult.unavailable()
      : scheduled = false,
        exact = false,
        mode = 'unavailable';

  final bool scheduled;
  final bool exact;
  final String mode; // 'exact' | 'inexact' | 'past_time' | 'cancelled' | 'failed' | 'unavailable'
}

@immutable
class NativeAlarmAction {
  const NativeAlarmAction({
    required this.action,
    required this.id,
    required this.title,
    this.taskId,
    this.snoozeAtMs = 0,
  });

  final String action; // 'dismiss' | 'snooze' | 'start_focus'
  final String id;
  final String title;
  final String? taskId;
  final int snoozeAtMs;
}

/// Bridges Dart alarm scheduling & previews to native Android [AlarmActivity]
/// and [AlarmManager.setAlarmClock] so alarms ring outside the app.
class NativeAlarmBridge {
  NativeAlarmBridge._();

  static final NativeAlarmBridge instance = NativeAlarmBridge._();

  static const MethodChannel _channel = MethodChannel('com.handelha.app/alarm');

  bool _handlerRegistered = false;
  VoidCallback? _onNativeUpdate;
  ValueChanged<String>? _onSharedText;

  bool get _isAndroidNative {
    if (kIsWeb) return false;
    try {
      if (!Platform.isAndroid) return false;
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  void setNativeActionListener(
    VoidCallback? onUpdated, {
    ValueChanged<String>? onSharedText,
  }) {
    _onNativeUpdate = onUpdated;
    _onSharedText = onSharedText;
    if (!_isAndroidNative || _handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPendingActionsUpdated') {
        _onNativeUpdate?.call();
      } else if (call.method == 'onSharedTextReceived') {
        final shared = call.arguments?.toString().trim() ?? '';
        if (shared.isNotEmpty) {
          _onSharedText?.call(shared);
        }
      }
    });
  }

  Future<NativeAlarmScheduleResult> scheduleAlarmDetailed({
    required String id,
    required String title,
    required int scheduledAtMs,
    required String alertMode,
    String? taskId,
    bool isEn = false,
  }) async {
    if (!_isAndroidNative) {
      return const NativeAlarmScheduleResult.unavailable();
    }
    try {
      final res = await _channel.invokeMethod<dynamic>('scheduleAlarm', {
        'id': id,
        'title': title,
        'scheduledAtMs': scheduledAtMs,
        'alertMode': alertMode,
        'taskId': ?taskId,
        'isEn': isEn,
      });
      if (res is Map) {
        final mode = (res['mode'] ?? 'failed').toString();
        final scheduled =
            res['scheduled'] == true || mode == 'exact' || mode == 'inexact';
        return NativeAlarmScheduleResult(
          scheduled: scheduled,
          exact: mode == 'exact',
          mode: mode,
        );
      }
      if (res is bool) {
        return NativeAlarmScheduleResult(
          scheduled: res,
          exact: res,
          mode: res ? 'exact' : 'failed',
        );
      }
      return const NativeAlarmScheduleResult(
        scheduled: false,
        exact: false,
        mode: 'failed',
      );
    } catch (_) {
      return const NativeAlarmScheduleResult(
        scheduled: false,
        exact: false,
        mode: 'failed',
      );
    }
  }

  Future<bool> scheduleAlarm({
    required String id,
    required String title,
    required int scheduledAtMs,
    required String alertMode,
    String? taskId,
    bool isEn = false,
  }) async {
    final res = await scheduleAlarmDetailed(
      id: id,
      title: title,
      scheduledAtMs: scheduledAtMs,
      alertMode: alertMode,
      taskId: taskId,
      isEn: isEn,
    );
    return res.scheduled;
  }

  Future<String?> getDeviceTimeZone() async {
    if (!_isAndroidNative) return null;
    try {
      return await _channel.invokeMethod<String>('getDeviceTimeZone');
    } catch (_) {
      return null;
    }
  }

  Future<void> startOrUpdateFocusService({
    required String title,
    required String subtitle,
    bool isEn = false,
  }) async {
    if (!_isAndroidNative) return;
    try {
      await _channel.invokeMethod<bool>('startFocusService', {
        'title': title,
        'subtitle': subtitle,
        'isEn': isEn,
      });
    } catch (_) {}
  }

  Future<void> stopFocusService() async {
    if (!_isAndroidNative) return;
    try {
      await _channel.invokeMethod<bool>('stopFocusService');
    } catch (_) {}
  }

  Future<void> cancelAlarm(String id) async {
    if (!_isAndroidNative) return;
    try {
      await _channel.invokeMethod<bool>('cancelAlarm', {'id': id});
    } catch (_) {}
  }

  Future<void> cancelAllAlarms() async {
    if (!_isAndroidNative) return;
    try {
      await _channel.invokeMethod<bool>('cancelAllAlarms');
    } catch (_) {}
  }

  Future<bool> showExternalAlarm({
    required String id,
    required String title,
    String? taskId,
    bool isEn = false,
    bool isPreview = true,
  }) async {
    if (!_isAndroidNative) return false;
    try {
      final res = await _channel.invokeMethod<bool>('showAlarmNow', {
        'id': id,
        'title': title,
        'taskId': ?taskId,
        'isEn': isEn,
        'isPreview': isPreview,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopAlarmAudio() async {
    if (!_isAndroidNative) return;
    try {
      await _channel.invokeMethod<bool>('stopAlarmAudio');
    } catch (_) {}
  }

  Future<NativeAlarmCapabilities> checkCapabilities() async {
    if (!_isAndroidNative) {
      return const NativeAlarmCapabilities();
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'checkCapabilities',
      );
      if (raw == null) return const NativeAlarmCapabilities();
      return NativeAlarmCapabilities(
        exactAlarm: raw['exactAlarm'] as bool? ?? true,
        canDrawOverlays: raw['canDrawOverlays'] as bool? ?? true,
        fullScreenIntent: raw['fullScreenIntent'] as bool? ?? true,
      );
    } catch (_) {
      return const NativeAlarmCapabilities();
    }
  }

  Future<void> requestOverlayPermission() async {
    if (!_isAndroidNative) return;
    try {
      await _channel.invokeMethod<bool>('requestOverlayPermission');
    } catch (_) {}
  }

  Future<void> requestExactAlarmPermission() async {
    if (!_isAndroidNative) return;
    try {
      await _channel.invokeMethod<bool>('requestExactAlarmPermission');
    } catch (_) {}
  }

  Future<void> requestFullScreenIntentPermission() async {
    if (!_isAndroidNative) return;
    try {
      await _channel.invokeMethod<bool>('requestFullScreenIntentPermission');
    } catch (_) {}
  }

  Future<String?> consumeSharedText() async {
    if (!_isAndroidNative) return null;
    try {
      final raw = await _channel.invokeMethod<String>('consumeSharedText');
      final trimmed = raw?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    } catch (_) {
      return null;
    }
  }

  Future<List<NativeAlarmAction>> consumePendingActions() async {
    if (!_isAndroidNative) return const [];
    try {
      final rawList = await _channel.invokeListMethod<dynamic>(
        'consumePendingActions',
      );
      if (rawList == null || rawList.isEmpty) return const [];
      final out = <NativeAlarmAction>[];
      for (final entry in rawList) {
        if (entry is Map) {
          final id = (entry['id'] ?? '').toString();
          if (id.isEmpty) continue;
          out.add(
            NativeAlarmAction(
              action: (entry['action'] ?? 'dismiss').toString(),
              id: id,
              title: (entry['title'] ?? '').toString(),
              taskId: entry['taskId']?.toString(),
              snoozeAtMs: (entry['snoozeAtMs'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
