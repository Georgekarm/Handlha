import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme_extension.dart';

/// ترويسة الشاشات القياسية وفق مرجع التصميم:
/// زر رجوع (يتغير اتجاهه تلقائيًا بين RTL و LTR) + عنوان عريض + وصف + أزرار اختيارية.
class HandelhaHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  const HandelhaHeader({
    super.key,
    required this.title,
    this.subtitle = 'خدها خطوة خطوة',
    this.showBack = true,
    this.onBack,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 8),
  });

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/home');
      }
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final displaySubtitle =
        (isEn && subtitle == 'خدها خطوة خطوة') ? 'Step by step' : subtitle;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBack) ...[
            Semantics(
              button: true,
              label: isEn ? 'Back' : 'رجوع',
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _handleBack(context),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    isEn
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 28,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    height: 1.2,
                  ),
                ),
                if (displaySubtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    displaySubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

/// زر أيقونة دائري/مربع ناعم متكرر في شريط الترويسة (إشعارات، ثيم، سجل، بحث).
class HandelhaHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool showBadge;
  final Color? badgeColor;
  final Color? iconColor;
  final Color? backgroundColor;

  const HandelhaHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showBadge = false,
    this.badgeColor,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor ?? c.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: backgroundColor == Colors.transparent
                  ? null
                  : Border.all(color: c.border, width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: iconColor ?? c.textPrimary,
                ),
                if (showBadge)
                  PositionedDirectional(
                    top: 9,
                    end: 9,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: badgeColor ?? c.danger,
                        shape: BoxShape.circle,
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
