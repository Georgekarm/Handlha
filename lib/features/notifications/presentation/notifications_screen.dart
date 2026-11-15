import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_extension.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/app_loading_view.dart';
import '../../../shared/widgets/feature_empty_state.dart';
import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../../shared/widgets/handelha_bottom_nav.dart';
import '../../../shared/widgets/handelha_header.dart';
import '../../../shared/widgets/handelha_segmented_switch.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_providers.dart';
import '../alarm_reminder_store.dart';
import '../native_alarm_bridge.dart';
import '../notification_inbox_store.dart';
import '../notification_preferences.dart';
import 'alarm_ringing_dialog.dart';

enum _NotifFilter { all, unread }

class _NotifItem {
  final String id;
  final String title;
  final String body;
  final String timeLabel;
  final IconData icon;
  final Color? stripeColor;
  final bool unread;
  final Task? task;

  const _NotifItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.icon,
    this.stripeColor,
    required this.unread,
    this.task,
  });
}

/// شاشة الإشعارات.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _NotifFilter _filter = _NotifFilter.all;
  Set<String> _readIds = const {};
  NotificationPreferences _prefs = const NotificationPreferences();
  bool _loadingMeta = true;
  String? _loadedUserId;

  Future<void> _previewAlert({
    required String id,
    required String title,
    required bool isNotificationMode,
    String? taskId,
  }) async {
    final isEn = Directionality.of(context) == TextDirection.ltr;
    if (!isNotificationMode) {
      final launchedExternal = await NativeAlarmBridge.instance.showExternalAlarm(
        id: id,
        title: title,
        taskId: taskId,
        isEn: isEn,
        isPreview: true,
      );
      if (launchedExternal) return;
    }
    if (!mounted) return;
    await HandelhaAlarmRingingDialog.show(
      context,
      title: title,
      isNotificationMode: isNotificationMode,
      taskId: taskId,
      onSnoozeMinutes: (mins) => ref
          .read(alarmReminderProvider.notifier)
          .snoozeAlarm(
            id,
            fallbackTitle: title,
            taskId: taskId,
            minutes: mins,
          ),
    );
  }

  Future<void> _loadMeta(String userId) async {
    if (_loadedUserId == userId && !_loadingMeta) return;
    final readIds = await NotificationInboxStore.loadReadIds(userId);
    final prefs = await LocalNotificationPreferences.load(userId);
    if (!mounted) return;
    setState(() {
      _readIds = readIds;
      _prefs = prefs;
      _loadedUserId = userId;
      _loadingMeta = false;
    });
  }

  Future<void> _markRead(String userId, String id) async {
    if (_readIds.contains(id)) return;
    setState(() => _readIds = {..._readIds, id});
    await NotificationInboxStore.markAsRead(userId, id);
  }

  List<_NotifItem> _buildItems(
    List<Task> tasks,
    AppThemeExtension c,
    bool isEn,
  ) {
    final items = <_NotifItem>[];
    final openDue = tasks
        .where((t) => !t.isCompleted && !t.isCancelled && t.dueAt != null)
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    for (final t in openDue.take(5)) {
      final mins = t.estimatedDurationMinutes ?? 25;
      final isOverdue = t.dueAt!.isBefore(DateTime.now());
      final cleanTitle = ArabicFormatters.trData(t.title);
      items.add(
        _NotifItem(
          id: t.id,
          title: isOverdue
              ? (isEn ? 'Time for your next step' : 'وقت خطوتك الجاية')
              : cleanTitle,
          body: isOverdue
              ? (isEn
                  ? '"$cleanTitle" is waiting for you. Give it ${ArabicFormatters.durationMinutesFull(mins)}?'
                  : '«${t.title}» مستنياك. نديها ${ArabicFormatters.durationMinutesFull(mins)}؟')
              : (isEn
                  ? 'Scheduled for ${ArabicFormatters.timeOfDayAr(t.dueAt!)} • ${ArabicFormatters.durationMinutesFull(mins)}'
                  : 'ميعادها ${ArabicFormatters.timeOfDayAr(t.dueAt!)} • ${ArabicFormatters.durationMinutesFull(mins)}'),
          timeLabel: ArabicFormatters.timeOfDayAr(t.dueAt!),
          icon: Icons.schedule_rounded,
          stripeColor: isOverdue ? c.primary : c.danger,
          unread: !_readIds.contains(t.id),
          task: t,
        ),
      );
    }

    final completedToday = tasks.where((t) => t.isCompleted).length;
    if (completedToday > 0) {
      const doneId = 'notif-summary-completed';
      items.add(
        _NotifItem(
          id: doneId,
          title: isEn
              ? 'Great job on what you finished'
              : 'عاش على اللي خلّصته',
          body: isEn
              ? '$completedToday tasks completed. Even a small step makes a difference.'
              : '${ArabicFormatters.toArabicDigits(completedToday)} مهام خلصوا. حتى الخطوة الصغيرة بتفرق.',
          timeLabel: isEn ? '1h ago' : 'من ساعة',
          icon: Icons.check_rounded,
          stripeColor: c.lavenderAccent,
          unread: !_readIds.contains(doneId),
        ),
      );
    }

    if (items.isNotEmpty) {
      const breathId = 'notif-breather-tip';
      items.add(
        _NotifItem(
          id: breathId,
          title: isEn ? 'Take a breath & keep going' : 'خد نفس وكمّل',
          body: isEn
              ? 'You have been focused for a while. You deserve a short break.'
              : 'بقالك شوية مركز. استراحة صغيرة تستاهلها.',
          timeLabel: isEn ? '2h ago' : 'من ساعتين',
          icon: Icons.auto_awesome_outlined,
          stripeColor: c.primary,
          unread: !_readIds.contains(breathId),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final user = ref.watch(authNotifierProvider).value;
    final tasksAsync = ref.watch(allTasksProvider);

    if (user != null && _loadedUserId != user.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeta(user.id));
    }

    if ((_loadingMeta && user != null) ||
        (tasksAsync.isLoading && tasksAsync.value == null)) {
      return AppLoadingView(
        title: isEn ? 'Notifications' : 'الإشعارات',
        standalone: true,
      );
    }

    final tasks = tasksAsync.value ?? const <Task>[];
    final allItems = _buildItems(tasks, c, isEn);
    final unreadCount = allItems.where((i) => i.unread).length;
    final shown = _filter == _NotifFilter.all
        ? allItems
        : allItems.where((i) => i.unread).toList();

    return Scaffold(
      extendBody: true,
      body: HandelhaAmbientBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 114),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HandelhaHeader(
                  title: isEn ? 'Notifications' : 'الإشعارات',
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
                  actions: [
                    if (user != null && unreadCount > 0)
                      TextButton(
                        onPressed: () async {
                          final ids = allItems.map((e) => e.id).toList();
                          setState(() => _readIds = {..._readIds, ...ids});
                          await NotificationInboxStore.markAllAsRead(
                            user.id,
                            ids,
                          );
                        },
                        child: Text(
                          isEn ? 'Mark all read' : 'قراءة الكل',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.primary,
                          ),
                        ),
                      ),
                  ],
                ),

                (() {
                  final alarmState = ref.watch(alarmReminderProvider);
                  if (alarmState.items.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          isEn
                              ? 'Scheduled Alarms & Reminders'
                              : 'المنبهات والتذكيرات المجدولة',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      for (final alarmItem in alarmState.items) ...[
                        _ScheduledAlarmCard(
                          item: alarmItem,
                          isEn: isEn,
                          onToggleMode: () => ref
                              .read(alarmReminderProvider.notifier)
                              .toggleItemAlertMode(alarmItem.id),
                          onToggleEnabled: () => ref
                              .read(alarmReminderProvider.notifier)
                              .toggleItemEnabled(alarmItem.id),
                          onPreview: () => _previewAlert(
                            id: alarmItem.id,
                            title: alarmItem.title,
                            isNotificationMode: !alarmItem.isFullAlarm,
                            taskId: alarmItem.taskId,
                          ),
                          onDelete: () => ref
                              .read(alarmReminderProvider.notifier)
                              .removeAlarm(alarmItem.id),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 6),
                    ],
                  );
                })(),
                if (!_prefs.enabled)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 40,
                          color: c.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isEn
                              ? 'Notifications are currently paused'
                              : 'التنبيهات متوقفة حاليًا',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isEn
                              ? 'You can enable them or adjust quiet hours in Settings.'
                              : 'تقدر تفعّلها أو تعدّل أوقات الهدوء من الإعدادات.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  HandelhaSegmentedSwitch<_NotifFilter>(
                    selected: _filter,
                    onChanged: (v) => setState(() => _filter = v),
                    options: [
                      HandelhaSegmentOption(
                        value: _NotifFilter.all,
                        label: isEn ? 'All' : 'الكل',
                      ),
                      HandelhaSegmentOption(
                        value: _NotifFilter.unread,
                        label: isEn
                            ? 'Unread $unreadCount'
                            : 'غير المقروءة ${ArabicFormatters.toArabicDigits(unreadCount)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (shown.isEmpty)
                    FeatureEmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: isEn
                          ? 'All caught up!'
                          : 'كل إشعاراتك مقروءة',
                      subtitle: isEn
                          ? 'No new alerts right now. Take your time and continue your day calmly.'
                          : 'مفيش تنبيهات جديدة دلوقتي. خد وقتك وكمل يومك بهدوء.',
                      primaryCtaLabel:
                          isEn ? 'Add Scheduled Task' : 'أضف مهمة بموعد',
                      onPrimaryCta: () => context.push('/tasks/add'),
                    )
                  else ...[
                    Text(
                      isEn ? 'Today' : 'النهارده',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _NotifCard(
                        item: shown[i],
                        onTap: () async {
                          final router = GoRouter.of(context);
                          if (user != null) {
                            await _markRead(user.id, shown[i].id);
                          }
                          if (!mounted) return;
                          if (shown[i].task != null) {
                            router.push('/tasks/add', extra: shown[i].task);
                          }
                        },
                      ),
                    ],
                  ],
                ],

                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => context.push('/settings'),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.primarySoft,
                      foregroundColor: c.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      isEn ? 'Adjust Reminders' : 'ظبّط تذكيراتك',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: c.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const HandelhaBottomNav(currentIndex: 0),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final _NotifItem item;
  final VoidCallback onTap;

  const _NotifCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final stripe = item.stripeColor ?? c.primary;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.icon,
                size: 22,
                color: stripe == c.lavenderAccent ? c.lavenderAccent : c.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: c.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        item.timeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  if (item.unread)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: c.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(height: 15),
                  Container(
                    width: 3.5,
                    height: 36,
                    decoration: BoxDecoration(
                      color: stripe,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduledAlarmCard extends StatelessWidget {
  const _ScheduledAlarmCard({
    required this.item,
    required this.isEn,
    required this.onToggleMode,
    required this.onToggleEnabled,
    required this.onPreview,
    required this.onDelete,
  });

  final AlarmReminderItem item;
  final bool isEn;
  final VoidCallback onToggleMode;
  final VoidCallback onToggleEnabled;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final local = item.scheduledAt.toLocal();
    final timeStr = ArabicFormatters.timeOfDayAr(local);
    final dateStr = ArabicFormatters.dateShort(local);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isEnabled
              ? c.primary.withValues(alpha: 0.35)
              : c.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.isFullAlarm
                      ? const Color(0xFFB45309).withValues(alpha: 0.14)
                      : c.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.isFullAlarm
                      ? Icons.alarm_on_rounded
                      : Icons.notifications_active_outlined,
                  size: 20,
                  color: item.isFullAlarm
                      ? const Color(0xFFB45309)
                      : c.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: item.isEnabled
                            ? c.textPrimary
                            : c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateStr • $timeStr',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: item.isEnabled,
                onChanged: (_) => onToggleEnabled(),
                activeThumbColor: c.primary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              InkWell(
                onTap: onToggleMode,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isFullAlarm
                            ? Icons.alarm_rounded
                            : Icons.notifications_none_rounded,
                        size: 15,
                        color: c.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.isFullAlarm
                            ? (isEn ? 'Mode: Ringing Alarm' : 'النوع: منبه يرن')
                            : (isEn ? 'Mode: Notification' : 'النوع: رسالة إشعار'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 14,
                        color: c.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: onPreview,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 15, color: c.primary),
                      const SizedBox(width: 4),
                      Text(
                        isEn ? 'Ring Test' : 'تجربة',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: c.danger,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
