import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_extension.dart';
import '../../../core/audio/handelha_sound_engine.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/handelha_feedback.dart';

/// Full-screen / modal Alarm Ringing experience that plays the melodic alarm
/// chime and lets the user start a Focus Session immediately, snooze 5 minutes,
/// or dismiss the alarm.
class HandelhaAlarmRingingDialog extends StatefulWidget {
  const HandelhaAlarmRingingDialog({
    super.key,
    required this.title,
    this.scheduledTimeLabel,
    this.isNotificationMode = false,
    this.taskId,
    this.onSnooze,
    this.onSnoozeMinutes,
    this.onDismissed,
  });

  final String title;
  final String? scheduledTimeLabel;
  final bool isNotificationMode;
  final String? taskId;
  final VoidCallback? onSnooze;
  final Future<void> Function(int minutes)? onSnoozeMinutes;
  final VoidCallback? onDismissed;

  static bool _isShowing = false;
  static bool get isShowing => _isShowing;

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? scheduledTimeLabel,
    bool isNotificationMode = false,
    String? taskId,
    VoidCallback? onSnooze,
    Future<void> Function(int minutes)? onSnoozeMinutes,
    VoidCallback? onDismissed,
  }) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => HandelhaAlarmRingingDialog(
          title: title,
          scheduledTimeLabel: scheduledTimeLabel,
          isNotificationMode: isNotificationMode,
          taskId: taskId,
          onSnooze: onSnooze,
          onSnoozeMinutes: onSnoozeMinutes,
          onDismissed: onDismissed,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<HandelhaAlarmRingingDialog> createState() =>
      _HandelhaAlarmRingingDialogState();
}

class _HandelhaAlarmRingingDialogState extends State<HandelhaAlarmRingingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    HandelhaSoundEngine.instance.playAlarmChime(
      loop: !widget.isNotificationMode,
    );
  }

  @override
  void dispose() {
    HandelhaSoundEngine.instance.stopAlarmChime();
    _pulseController.dispose();
    super.dispose();
  }

  void _stopAndClose() {
    HandelhaSoundEngine.instance.stopAlarmChime();
    widget.onDismissed?.call();
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final now = DateTime.now();
    final timeStr = isEn
        ? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'
        : ArabicFormatters.timeOfDayAr(now);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.heroTeal,
              const Color(0xFF0A332C),
            ],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isNotificationMode
                          ? Icons.notifications_active_rounded
                          : Icons.alarm_on_rounded,
                      color: const Color(0xFFFFD166),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.isNotificationMode
                            ? (isEn
                                ? 'Smart Reminder Message'
                                : 'رسالة تذكير من هندلها')
                            : (isEn
                                ? 'Handelha Alarm Ringing'
                                : 'منبه هندلها يرن الآن'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Pulsing Alarm Ring Icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.12);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFD166).withValues(alpha: 0.22),
                        border: Border.all(
                          color: const Color(0xFFFFD166),
                          width: 2.5,
                        ),
                      ),
                      child: Icon(
                        widget.isNotificationMode
                            ? Icons.notifications_active_rounded
                            : Icons.alarm_rounded,
                        size: 46,
                        color: const Color(0xFFFFD166),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Big Digital Clock Display
              Text(
                widget.scheduledTimeLabel ?? timeStr,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),

              // Task / Exam Title
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      isEn ? 'Time for your scheduled goal:' : 'جه ميعاد مهمتك الآن:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Primary CTA: Stop Alarm & Start Focus Session
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HandelhaSoundEngine.instance.stopAlarmChime();
                    widget.onDismissed?.call();
                    final navContext = context;
                    Navigator.of(navContext, rootNavigator: true).pop();
                    GoRouter.maybeOf(navContext)?.push(
                      '/focus-session',
                      extra: {
                        if (widget.taskId != null) 'id': widget.taskId,
                        'title': widget.title,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD166),
                    foregroundColor: const Color(0xFF082420),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 19),
                  label: Text(
                    isEn
                        ? 'Stop Alarm & Start Focus Now'
                        : 'إيقاف المنبه وابدأ جلسة تركيز الآن',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Snooze options + Dismiss button
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        HandelhaSoundEngine.instance.stopAlarmChime();
                        final navContext = context;
                        HandelhaFeedback.showInfo(
                          navContext,
                          isEn
                              ? 'Alarm snoozed for 5 minutes.'
                              : 'تم تأجيل المنبه ٥ دقائق.',
                        );
                        Navigator.of(navContext, rootNavigator: true).pop();
                        if (widget.onSnoozeMinutes != null) {
                          await widget.onSnoozeMinutes!(5);
                        } else {
                          widget.onSnooze?.call();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.snooze_rounded, size: 17),
                      label: Text(
                        isEn ? '5m Snooze' : 'غفوة ٥ د',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        HandelhaSoundEngine.instance.stopAlarmChime();
                        final navContext = context;
                        HandelhaFeedback.showInfo(
                          navContext,
                          isEn
                              ? 'Alarm snoozed for 10 minutes.'
                              : 'تم تأجيل المنبه ١٠ دقائق.',
                        );
                        Navigator.of(navContext, rootNavigator: true).pop();
                        if (widget.onSnoozeMinutes != null) {
                          await widget.onSnoozeMinutes!(10);
                        } else {
                          widget.onSnooze?.call();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.more_time_rounded, size: 17),
                      label: Text(
                        isEn ? '10m Snooze' : 'غفوة ١٠ د',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _stopAndClose,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.9),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(
                    isEn ? 'Dismiss Alarm' : 'إيقاف المنبه الآن',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
