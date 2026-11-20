import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_extension.dart';
import '../alarm_reminder_store.dart';

/// Requests OS notification (and optionally exact alarm + overlay) permissions
/// with a friendly Handelha explanation sheet first, only when not yet granted.
Future<bool> ensureHandelhaNotificationPermission(
  BuildContext context,
  WidgetRef ref, {
  bool includeExactAlarm = true,
  String? reasonAr,
  String? reasonEn,
}) async {
  final notifier = ref.read(alarmReminderProvider.notifier);
  await notifier.refreshPermissions();
  final state = ref.read(alarmReminderProvider);
  final needsNotification = !state.permissionGranted;

  if (!needsNotification) {
    return true;
  }
  if (!context.mounted) return false;

  final granted = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _HandelhaPermissionSheet(
      includeExactAlarm: includeExactAlarm,
      needsNotification: needsNotification,
      needsExactAlarm: includeExactAlarm && !state.exactAlarmGranted,
      needsOverlay: false,
      reasonAr: reasonAr,
      reasonEn: reasonEn,
    ),
  );
  return granted ?? false;
}

class _HandelhaPermissionSheet extends ConsumerStatefulWidget {
  const _HandelhaPermissionSheet({
    required this.includeExactAlarm,
    required this.needsNotification,
    required this.needsExactAlarm,
    required this.needsOverlay,
    this.reasonAr,
    this.reasonEn,
  });

  final bool includeExactAlarm;
  final bool needsNotification;
  final bool needsExactAlarm;
  final bool needsOverlay;
  final String? reasonAr;
  final String? reasonEn;

  @override
  ConsumerState<_HandelhaPermissionSheet> createState() =>
      _HandelhaPermissionSheetState();
}

class _HandelhaPermissionSheetState
    extends ConsumerState<_HandelhaPermissionSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final cardBg = isDark ? c.surface : Colors.white;
    final overlayOnly =
        !widget.needsNotification && !widget.needsExactAlarm && widget.needsOverlay;

    final title = overlayOnly
        ? (isEn ? 'Allow Display Over Apps' : 'السماح بالظهور فوق التطبيقات')
        : (isEn ? 'Enable Reminders & Alarms' : 'تفعيل إذن الإشعارات والمنبه');

    final subtitle = overlayOnly
        ? (isEn
            ? 'Allow notifications so your ringing alarm alerts you right on time.'
            : 'فعّل إذن الإشعارات عشان لما تختار منبه يرن، يوصلك التنبيه في ميعاده.')
        : isEn
            ? (widget.reasonEn ??
                'Allow notifications so Handelha can alert you right on time for study sessions and exams.')
            : (widget.reasonAr ??
                'اسمح لهندلها بالإشعارات والمنبه عشان يرن في ميعاده بالضبط وينبّهك لمواعيدك المهمة.');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: c.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      widget.includeExactAlarm
                          ? Icons.alarm_on_rounded
                          : Icons.notifications_active_rounded,
                      size: 34,
                      color: c.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: c.textMuted,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    children: [
                      if (widget.needsNotification)
                        _PermissionItemRow(
                          icon: Icons.notifications_none_rounded,
                          color: c.primary,
                          title: isEn
                              ? 'Notification messages'
                              : 'رسائل الإشعارات الهادئة',
                          subtitle: isEn
                              ? 'Timely banners for upcoming tasks and reviews.'
                              : 'تنبيهات مريحة في شريط الإشعارات لمهامك اليومية.',
                        ),
                      if (widget.needsNotification &&
                          (widget.needsExactAlarm || widget.needsOverlay))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: c.border),
                        ),
                      if (widget.needsExactAlarm)
                        _PermissionItemRow(
                          icon: Icons.alarm_rounded,
                          color: const Color(0xFFB45309),
                          title: isEn
                              ? 'Exact ringing alarms'
                              : 'منبه يرن في الميعاد بالثانية',
                          subtitle: isEn
                              ? 'Full-screen ringtone & vibration when you choose an alarm.'
                              : 'شاشة منبه كاملة بصوت واهتزاز للامتحانات والمواعيد المهمة.',
                        ),
                      if (widget.needsExactAlarm && widget.needsOverlay)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: c.border),
                        ),
                      if (widget.needsOverlay)
                        _PermissionItemRow(
                          icon: Icons.layers_outlined,
                          color: c.primary,
                          title: isEn
                              ? 'Display over other apps'
                              : 'الظهور فوق التطبيقات للمنبه الخارجي',
                          subtitle: isEn
                              ? 'Lets the alarm open above any active app, just like an external clock alarm.'
                              : 'يخلي شاشة المنبه الخارجي تفتح فوق أي تطبيق تاني زي أي منبه خارجي.',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            var ok = true;
                            if (widget.needsNotification ||
                                widget.needsExactAlarm) {
                              ok = await ref
                                  .read(alarmReminderProvider.notifier)
                                  .requestPermission(
                                    includeExactAlarm: false,
                                  );
                            }
                            if (!context.mounted) return;
                            Navigator.of(context, rootNavigator: true).pop(ok);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded,
                            size: 20),
                    label: Text(
                      overlayOnly
                          ? (isEn
                              ? 'Allow Over Other Apps'
                              : 'السماح بالظهور فوق التطبيقات')
                          : (isEn
                              ? 'Allow Notifications'
                              : 'السماح وتفعيل التنبيهات'),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () =>
                          Navigator.of(context, rootNavigator: true).pop(false),
                  child: Text(
                    isEn ? 'Not now' : 'تخطي الآن',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: c.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionItemRow extends StatelessWidget {
  const _PermissionItemRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
