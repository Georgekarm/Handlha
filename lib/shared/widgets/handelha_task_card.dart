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
  final VoidCallback? onMorePressed;
  final bool showEndStripe;
  final bool compactTag;
  final String? subtitleOverride;

  const HandelhaTaskCard({
    super.key,
    required this.task,
    this.projectName,
    this.stripeColor,
    required this.onToggleComplete,
    this.onTap,
    this.onLongPress,
    this.onMorePressed,
    this.showEndStripe = true,
    this.compactTag = false,
    this.subtitleOverride,
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

  ({String label, Color bg, Color fg, Color? border}) _resolveTagBadge(
    AppThemeExtension c,
    bool isDark,
    bool isEn,
  ) {
    if (task.isCompleted) {
      return (
        label: isEn ? 'Completed' : 'مكتملة',
        bg: isDark ? const Color(0xFF15342C) : const Color(0xFFE7F2EE),
        fg: isDark ? const Color(0xFF9ED5C6) : c.primary,
        border: (isDark ? const Color(0xFF2B5C4E) : c.primary)
            .withValues(alpha: 0.35),
      );
    }

    if (task.priority == TaskPriority.urgent ||
        task.priority == TaskPriority.high) {
      final label = compactTag
          ? (isEn ? 'High' : 'عالية')
          : (isEn ? 'High priority' : 'أولوية عالية');
      return (
        label: label,
        bg: isDark ? const Color(0xFF272645) : const Color(0xFFECEAF8),
        fg: isDark ? const Color(0xFFC8C4F3) : c.secondary,
        border: null,
      );
    }

    if (projectName != null && projectName!.trim().isNotEmpty) {
      return (
        label: ArabicFormatters.trData(projectName!.trim()),
        bg: isDark ? const Color(0xFF1B342D) : const Color(0xFFE7EFEC),
        fg: isDark ? const Color(0xFFBED8D0) : c.textSecondary,
        border: null,
      );
    }

    final defaultLabel = task.priority == TaskPriority.medium
        ? (isEn ? 'Work' : 'شغل')
        : (isEn ? 'Personal' : 'شخصي');
    return (
      label: defaultLabel,
      bg: isDark ? const Color(0xFF1A312B) : const Color(0xFFE8F0ED),
      fg: isDark ? const Color(0xFFBED8D0) : c.textSecondary,
      border: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final done = task.isCompleted;
    final accentStripe = _resolveStripeColor(c);
    final displayTitle = ArabicFormatters.trData(task.title);
    final tag = _resolveTagBadge(c, isDark, isEn);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
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
                  borderRadius: BorderRadius.circular(8),
                  onTap: onToggleComplete,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: done ? context.ctaBackground : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: done ? context.ctaBackground : c.border,
                        width: 1.5,
                      ),
                    ),
                    child: done
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: context.ctaForeground,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: done ? c.textSecondary : c.textPrimary,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: c.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleOverride ?? _subtitleText(isEn),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: tag.bg,
                        borderRadius: BorderRadius.circular(999),
                        border: tag.border != null
                            ? Border.all(color: tag.border!, width: 1)
                            : null,
                      ),
                      child: Text(
                        tag.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tag.fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onMorePressed != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onMorePressed,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: c.textMuted,
                    ),
                  ),
                ),
              ],
              if (showEndStripe) ...[
                const SizedBox(width: 8),
                Container(
                  width: 3.5,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accentStripe,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
