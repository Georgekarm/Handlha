import 'package:flutter/material.dart';

import '../../app/theme/app_theme_extension.dart';

/// نبرة الرسالة المنبثقة داخل تطبيق «هندلها».
enum HandelhaMessageTone { success, celebration, info, warning, error }

/// نظام رسائل ونوافذ تأكيد موحّد وحديث لتطبيق «هندلها» بدلاً من رسائل النظام التقليدية.
class HandelhaFeedback {
  HandelhaFeedback._();

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    HandelhaMessageTone tone = HandelhaMessageTone.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: duration,
          content: _HandelhaToastBanner(
            title: title,
            message: message,
            tone: tone,
            icon: icon,
            actionLabel: actionLabel,
            onAction: onAction,
            onDismiss: () => messenger.hideCurrentSnackBar(),
          ),
        ),
      );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      title: title,
      message: message,
      tone: HandelhaMessageTone.success,
      duration: duration,
    );
  }

  static void showCelebration(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      title: title,
      message: message,
      tone: HandelhaMessageTone.celebration,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      title: title,
      message: message,
      tone: HandelhaMessageTone.info,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      title: title,
      message: message,
      tone: HandelhaMessageTone.warning,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      title: title,
      message: message,
      tone: HandelhaMessageTone.error,
      duration: duration,
    );
  }
}

class _HandelhaToastBanner extends StatelessWidget {
  final String? title;
  final String message;
  final HandelhaMessageTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _HandelhaToastBanner({
    this.title,
    required this.message,
    required this.tone,
    this.icon,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  (Color, IconData, String) _resolveMeta(
    AppThemeExtension c,
    bool isEn,
  ) {
    return switch (tone) {
      HandelhaMessageTone.success => (
          c.success,
          icon ?? Icons.check_circle_rounded,
          isEn ? 'Done' : 'تم بنجاح',
        ),
      HandelhaMessageTone.celebration => (
          c.warning,
          icon ?? Icons.auto_awesome_rounded,
          isEn ? 'Awesome' : 'عاش!',
        ),
      HandelhaMessageTone.info => (
          c.primary,
          icon ?? Icons.info_outline_rounded,
          isEn ? 'Note' : 'تنبيه',
        ),
      HandelhaMessageTone.warning => (
          c.warning,
          icon ?? Icons.notifications_active_outlined,
          isEn ? 'Heads up' : 'تذكير',
        ),
      HandelhaMessageTone.error => (
          c.danger,
          icon ?? Icons.error_outline_rounded,
          isEn ? 'Oops' : 'خلي بالك',
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final (accent, resolvedIcon, fallbackTitle) = _resolveMeta(c, isEn);

    final bgColor = isDark
        ? Color.alphaBlend(accent.withValues(alpha: 0.14), c.surfaceSoft)
        : Color.alphaBlend(accent.withValues(alpha: 0.06), c.surface);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.42 : 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.11),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.14 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 11),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(resolvedIcon, color: accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null && title!.trim().isNotEmpty) ...[
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                ] else if (tone == HandelhaMessageTone.celebration) ...[
                  Text(
                    fallbackTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 1),
                ],
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                onDismiss();
                onAction!();
              },
              style: TextButton.styleFrom(
                backgroundColor: accent.withValues(alpha: 0.14),
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 17,
                color: c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// نوافذ حوار وتأكيد عصرية متوافقة مع هوية «هندلها».
class HandelhaDialog {
  HandelhaDialog._();

  static Future<T?> showCustom<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.48),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, animation, secondaryAnimation) => builder(ctx),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.93, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    IconData icon = Icons.help_outline_rounded,
    bool isDanger = false,
    Color? accentColor,
  }) {
    return showCustom<bool>(
      context,
      builder: (ctx) {
        final c = ctx.appColors;
        final isDark = ctx.isDark;
        final badgeColor =
            isDanger ? c.danger : (accentColor ?? c.primary);

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? c.border : c.border.withValues(alpha: 0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(icon, color: badgeColor, size: 28),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textSecondary,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: c.surfaceSoft,
                            foregroundColor: c.textPrimary,
                            side: BorderSide(color: c.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            cancelLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: badgeColor,
                            foregroundColor:
                                isDanger ? Colors.white : c.textOnPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            confirmLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isDanger ? Colors.white : c.textOnPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> showCelebration(
    BuildContext context, {
    required String badgeTitle,
    required String message,
    required String buttonLabel,
    IconData icon = Icons.emoji_events_rounded,
  }) {
    return showCustom<void>(
      context,
      builder: (ctx) {
        final c = ctx.appColors;
        final isDark = ctx.isDark;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: c.warning.withValues(alpha: 0.4),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          c.warning.withValues(alpha: 0.25),
                          c.primary.withValues(alpha: 0.16),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: c.warning.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Icon(icon, color: c.warning, size: 34),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  badgeTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surfaceSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.border),
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.6,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: c.textOnPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      buttonLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.textOnPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
