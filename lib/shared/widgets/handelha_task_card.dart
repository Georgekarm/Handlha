import 'package:flutter/material.dart';

import '../../app/theme/app_theme_extension.dart';
import '../../features/tasks/domain/task.dart';
import '../utils/arabic_formatters.dart';

/// بطاقة المهمة القياسية.
class HandelhaTaskCard extends StatelessWidget {
  final Task task;
  final String? projectName;
  final Color? stripeColor;
  final VoidCallback onToggleComplete;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const HandelhaTaskCard({
    super.key,
    required this.task,
    this.projectName,
    this.stripeColor,
    required this.onToggleComplete,
    this.onTap,
    this.onLongPress,
  });

  Color _resolveStripeColor(AppThemeExtension c) {
    if (stripeColor != null) return stripeColor!;
    switch (task.priority) {
      case TaskPriority.urgent:
      case TaskPriority.high:
        return c.primary;
      case TaskPriority.medium:
        return c.lavenderAccent;
      case TaskPriority.low:
        return c.danger;
    }
  }

  String _subtitleText(bool isEn) {
    final parts = <String>[];
    if (projectName != null && projectName!.trim().isNotEmpty) {
      parts.add(ArabicFormatters.trData(projectName!.trim()));
    } else if (task.priority == TaskPriority.high ||
        task.priority == TaskPriority.urgent) {
      parts.add(isEn ? 'Work' : 'شغل');
    } else {
      parts.add(isEn ? 'Personal' : 'شخصي');
    }

    final when = task.scheduledStartAt ?? task.dueAt;
    if (task.isCompleted) {
      if (when != null) {
        parts.add(ArabicFormatters.timeOfDayAr(when));
      } else {
        parts.add(isEn ? 'Done' : 'خلصت');
      }
    } else if (when != null) {
      parts.add(ArabicFormatters.timeOfDayAr(when));
    }

    if (!task.isCompleted && (task.estimatedDurationMinutes ?? 0) > 0) {
      parts.add(
        ArabicFormatters.durationMinutesFull(task.estimatedDurationMinutes!),
      );
    }

    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final done = task.isCompleted;
    final accentStripe = _resolveStripeColor(c);
    final displayTitle = ArabicFormatters.trData(task.title);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border, width: 1),
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                checked: done,
                label: isEn
                    ? (done
                        ? 'Reopen task $displayTitle'
                        : 'Complete task $displayTitle')
                    : (done
                        ? 'إعادة فتح المهمة $displayTitle'
                        : 'إتمام المهمة $displayTitle'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onToggleComplete,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: done ? c.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: done ? c.primary : c.border,
                        width: 1.6,
                      ),
                    ),
                    child: done
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: c.textOnPrimary,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: done ? c.textSecondary : c.textPrimary,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: c.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitleText(isEn),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 3.5,
                height: 32,
                decoration: BoxDecoration(
                  color: accentStripe,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
