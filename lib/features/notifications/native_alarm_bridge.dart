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

  void setNativeActionListener(VoidCallback? onUpdated) {
    _onNativeUpdate = onUpdated;
    if (!_isAndroidNative || _handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPendingActionsUpdated') {
        _onNativeUpdate?.call();
      }
    });
  }

  Future<bool> scheduleAlarm({
    required String id,
    required String title,
    required int scheduledAtMs,
    required String alertMode,
    String? taskId,
  }) async {
    if (!_isAndroidNative) return false;
    try {
      final res = await _channel.invokeMethod<bool>('scheduleAlarm', {
        'id': id,
        'title': title,
        'scheduledAtMs': scheduledAtMs,
        'alertMode': alertMode,
        'taskId': ?taskId,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
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
