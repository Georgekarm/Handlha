import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

enum PasswordStrength {
  none(0, '', Colors.transparent),
  weak(1, 'ضعيفة', AppColors.danger),
  fair(2, 'متوسطة', AppColors.warning),
  good(3, 'جيدة', AppColors.info),
  strong(4, 'قوية ومحمية', AppColors.success);

  final int level;
  final String label;
  final Color color;

  const PasswordStrength(this.level, this.label, this.color);

  static PasswordStrength calculate(String password) {
    if (password.isEmpty) return PasswordStrength.none;

    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[a-z]')) && password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) score++;

    switch (score) {
      case 0:
      case 1:
        return PasswordStrength.weak;
      case 2:
        return PasswordStrength.fair;
      case 3:
        return PasswordStrength.good;
      case 4:
      default:
        return PasswordStrength.strong;
    }
  }
}

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = PasswordStrength.calculate(password);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (index) {
              final isFilled = index < strength.level;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: 4,
                  margin: EdgeInsetsDirectional.only(end: index < 3 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: isFilled
                        ? strength.color
                        : (isDark ? AppColors.darkBorder : AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'قوة كلمة المرور: ${strength.label}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: strength.color,
                ),
              ),
              if (strength.level < 4)
                Text(
                  strength.level <= 1
                      ? 'استخدم 8 أحرف وأرقام ورموز'
                      : (strength.level == 2 ? 'أضف رموز وحروف كبيرة' : 'ممتاز! يمكنك تقويتها برمز'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
