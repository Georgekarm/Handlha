import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/cloud/cloud_sync_engine.dart';
import '../../assistant/presentation/assistant_providers.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../alarm_reminder_store.dart';
import '../local_notification_service.dart';
import '../native_alarm_bridge.dart';
import 'alarm_ringing_dialog.dart';

/// Bridges native external Android alarm actions and notification taps with app
/// state and focus navigation. On Android, alarms open [AlarmActivity] outside
/// the app rather than interrupting with an in-app modal.
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
    NativeAlarmBridge.instance.setNativeActionListener(
      _syncPendingNativeActions,
      onSharedText: _handleSharedText,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await LocalNotificationService.instance.initialize(
        requestPermission: false,
      );
      if (!mounted) return;
      await _syncPendingNativeActions();
      if (!mounted) return;
      final shared = await NativeAlarmBridge.instance.consumeSharedText();
      if (shared != null && shared.isNotEmpty) {
        _handleSharedText(shared);
      }
      final launchPayload =
          LocalNotificationService.instance.takePendingLaunchPayload();
      if (launchPayload != null) {
        _openPayload(launchPayload);
      }
      _checkDueForegroundAlarms();
    });

    _startDueTimer();
  }

  void _startDueTimer() {
    _dueTimer?.cancel();
    _dueTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkDueForegroundAlarms(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startDueTimer();
      ref.read(alarmReminderProvider.notifier).refreshPermissions();
      _syncPendingNativeActions();
      _checkDueForegroundAlarms();
      final userId = ref.read(authNotifierProvider).value?.id;
      if (userId != null && !userId.startsWith('local_')) {
        CloudSyncEngine.instance.scheduleAutoSync(
          userId,
          delay: const Duration(milliseconds: 500),
        );
      }
      NativeAlarmBridge.instance.consumeSharedText().then((shared) {
        if (shared != null && shared.isNotEmpty && mounted) {
          _handleSharedText(shared);
        }
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _dueTimer?.cancel();
      _dueTimer = null;
    }
  }

  void _handleSharedText(String sharedText) {
    final cleaned = sharedText.trim();
    if (cleaned.isEmpty || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = rootNavigatorKey.currentContext;
      if (navContext != null && navContext.mounted) {
        GoRouter.maybeOf(navContext)?.go('/chat');
        ref.read(chatSessionProvider).send(cleaned);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NativeAlarmBridge.instance.setNativeActionListener(null);
    _tapSub?.cancel();
    _dueTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncPendingNativeActions() async {
    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState.isLoading) return;

    final actions = await NativeAlarmBridge.instance.consumePendingActions();
    if (!mounted || actions.isEmpty) return;

    final notifier = ref.read(alarmReminderProvider.notifier);
    for (final act in actions) {
      switch (act.action) {
        case 'dismiss':
          await notifier.markAlarmDismissed(act.id);
          break;
        case 'snooze':
          if (act.snoozeAtMs > 0) {
            final snoozedAt =
                DateTime.fromMillisecondsSinceEpoch(act.snoozeAtMs);
            await notifier.addOrUpdateAlarm(
              id: act.id,
              title: act.title.isEmpty ? 'تذكير مهمة' : act.title,
              scheduledAt: snoozedAt,
              alertMode: 'alarm',
              taskId: act.taskId,
            );
          }
          break;
        case 'start_focus':
          await notifier.markAlarmDismissed(act.id);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navContext = rootNavigatorKey.currentContext;
            if (navContext != null && navContext.mounted) {
              GoRouter.maybeOf(navContext)?.push(
                '/focus-session',
                extra: <String, dynamic>{
                  'title': act.title,
                  if (act.taskId != null) 'id': act.taskId,
                },
              );
            }
          });
          break;
      }
    }
  }

  Future<void> _checkDueForegroundAlarms() async {
    if (!mounted || HandelhaAlarmRingingDialog.isShowing) return;
    final state = ref.read(alarmReminderProvider);
    final now = DateTime.now();
    // Allow 4s grace window so native Android AlarmReceiver doesn't collide
    // with the foreground poll loop at the exact trigger second.
    final triggerBoundary = now.subtract(const Duration(seconds: 4));
    final recentCutoff = now.subtract(const Duration(minutes: 2));

    for (final item in state.items) {
      if (!item.isEnabled || !item.isFullAlarm) continue;
      if (item.scheduledAt.isAfter(triggerBoundary)) continue;
      if (item.scheduledAt.isBefore(recentCutoff)) continue;

      final fireKey = '${item.id}_${item.scheduledAt.millisecondsSinceEpoch}';
      if (_firedKeys.contains(fireKey)) continue;
      _firedKeys.add(fireKey);

      final navContext = rootNavigatorKey.currentContext;
      final isEn = navContext != null &&
          navContext.mounted &&
          Directionality.of(navContext) == TextDirection.ltr;

      // Prefer external Android AlarmActivity so the alarm feels native even
      // while using the phone.
      final launchedExternal = await NativeAlarmBridge.instance.showExternalAlarm(
        id: item.id,
        title: item.title,
        taskId: item.taskId,
        isEn: isEn,
        isPreview: false,
      );
      if (launchedExternal) {
        break;
      }

      if (!mounted || navContext == null || !navContext.mounted) return;
      _showAlarmFallback(
        navContext,
        id: item.id,
        title: item.title,
        isAlarm: true,
        taskId: item.taskId,
      );
      break;
    }
  }

  Future<void> _openPayload(NotificationPayload payload) async {
    if (!mounted || HandelhaAlarmRingingDialog.isShowing) return;
    final navContext = rootNavigatorKey.currentContext;
    final isEn = navContext != null &&
        navContext.mounted &&
        Directionality.of(navContext) == TextDirection.ltr;

    if (payload.isAlarm) {
      final launchedExternal = await NativeAlarmBridge.instance.showExternalAlarm(
        id: payload.id,
        title: payload.title,
        taskId: payload.taskId,
        isEn: isEn,
        isPreview: false,
      );
      if (launchedExternal) return;
    }

    if (!mounted || navContext == null || !navContext.mounted) return;
    _showAlarmFallback(
      navContext,
      id: payload.id,
      title: payload.title,
      isAlarm: payload.isAlarm,
      taskId: payload.taskId,
    );
  }

  Future<void> _showAlarmFallback(
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
    ref.listen(authNotifierProvider, (prev, next) {
      if ((prev?.isLoading ?? true) && !next.isLoading) {
        _syncPendingNativeActions();
      }
    });
    return widget.child;
  }
}
