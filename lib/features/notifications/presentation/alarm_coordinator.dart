import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../alarm_reminder_store.dart';
import '../local_notification_service.dart';
import 'alarm_ringing_dialog.dart';

/// Bridges OS notification taps/launches and in-app due alarms directly to
/// [HandelhaAlarmRingingDialog] above any route.
class HandelhaAlarmCoordinator extends ConsumerStatefulWidget {
  const HandelhaAlarmCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HandelhaAlarmCoordinator> createState() =>
      _HandelhaAlarmCoordinatorState();
}

class _HandelhaAlarmCoordinatorState
    extends ConsumerState<HandelhaAlarmCoordinator> with WidgetsBindingObserver {
  StreamSubscription<NotificationPayload>? _tapSub;
  Timer? _dueTimer;
  final Set<String> _firedKeys = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tapSub =
        LocalNotificationService.instance.onNotificationTap.listen(_openPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await LocalNotificationService.instance.initialize(
        requestPermission: false,
      );
      if (!mounted) return;
      final launchPayload =
          LocalNotificationService.instance.takePendingLaunchPayload();
      if (launchPayload != null) {
        _openPayload(launchPayload);
      }
      _checkDueForegroundAlarms();
    });
    _dueTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkDueForegroundAlarms(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(alarmReminderProvider.notifier).refreshPermissions();
      _checkDueForegroundAlarms();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapSub?.cancel();
    _dueTimer?.cancel();
    super.dispose();
  }

  void _checkDueForegroundAlarms() {
    if (!mounted || HandelhaAlarmRingingDialog.isShowing) return;
    final state = ref.read(alarmReminderProvider);
    final now = DateTime.now();
    final recentCutoff = now.subtract(const Duration(minutes: 2));

    for (final item in state.items) {
      if (!item.isEnabled || !item.isFullAlarm) continue;
      if (item.scheduledAt.isAfter(now)) continue;
      if (item.scheduledAt.isBefore(recentCutoff)) continue;

      final fireKey = '${item.id}_${item.scheduledAt.millisecondsSinceEpoch}';
      if (_firedKeys.contains(fireKey)) continue;

      final navContext = rootNavigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;
      _firedKeys.add(fireKey);
      _showAlarmDialog(
        navContext,
        id: item.id,
        title: item.title,
        isAlarm: true,
        taskId: item.taskId,
      );
      break;
    }
  }

  void _openPayload(NotificationPayload payload) {
    if (!mounted || HandelhaAlarmRingingDialog.isShowing) return;
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    _showAlarmDialog(
      navContext,
      id: payload.id,
      title: payload.title,
      isAlarm: payload.isAlarm,
      taskId: payload.taskId,
    );
  }

  Future<void> _showAlarmDialog(
    BuildContext navContext, {
    required String id,
    required String title,
    required bool isAlarm,
    String? taskId,
  }) {
    return HandelhaAlarmRingingDialog.show(
      navContext,
      title: title,
      isNotificationMode: !isAlarm,
      taskId: taskId,
      onSnoozeMinutes: (minutes) =>
          ref.read(alarmReminderProvider.notifier).snoozeAlarm(
                id,
                fallbackTitle: title,
                taskId: taskId,
                minutes: minutes,
              ),
      onDismissed: () =>
          ref.read(alarmReminderProvider.notifier).markAlarmDismissed(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(alarmReminderProvider);
    return widget.child;
  }
}
