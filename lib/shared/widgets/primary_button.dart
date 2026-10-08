import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// زر أساسي متكامل مع حالات التحميل والتعطيل بهوية Calm Productivity.
/// الارتفاع 52px لضمان Touch Targets مريحة وسهلة الضغط ومتوافق تمامًا مع Dark Mode.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final Widget? icon;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryBg = isDark ? AppColors.darkPrimary : AppColors.primary;
    final primaryFg = isDark ? const Color(0xFF111A19) : Colors.white;

    final secondaryBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final secondaryFg = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondaryBorder = isDark ? AppColors.darkBorder : AppColors.border;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? secondaryBg : primaryBg,
          foregroundColor: isSecondary ? secondaryFg : primaryFg,
          disabledBackgroundColor: isSecondary
              ? (isDark ? AppColors.darkSurface2 : AppColors.surfaceSecondary)
              : primaryBg.withValues(alpha: 0.5),
          elevation: 0,
          side: isSecondary
              ? BorderSide(color: secondaryBorder, width: 1.2)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
        ),
        onPressed: isDisabled ? null : onPressed,
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: isSecondary ? primaryBg : primaryFg,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSecondary ? secondaryFg : primaryFg,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
