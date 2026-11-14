import 'package:flutter/material.dart';

import '../../app/theme/app_theme_extension.dart';

/// مفتاح تبديل مقسم داخل مسار كبسولة موحّد وأنيق.
class HandelhaSegmentedSwitch<T> extends StatelessWidget {
  final List<HandelhaSegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry? margin;

  const HandelhaSegmentedSwitch({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? c.surfaceSoft : c.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _SegmentTile(
                label: options[i].label,
                icon: options[i].icon,
                isSelected: options[i].value == selected,
                selectedBg: isDark
                    ? c.primary.withValues(alpha: 0.22)
                    : c.primarySoft,
                selectedFg: c.primary,
                unselectedFg: c.textSecondary,
                selectedBorderColor: c.primary.withValues(
                  alpha: isDark ? 0.45 : 0.25,
                ),
                onTap: () => onChanged(options[i].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HandelhaSegmentOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const HandelhaSegmentOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

class _SegmentTile extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final Color selectedBg;
  final Color selectedFg;
  final Color unselectedFg;
  final Color selectedBorderColor;
  final VoidCallback onTap;

  const _SegmentTile({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.selectedBg,
    required this.selectedFg,
    required this.unselectedFg,
    required this.selectedBorderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? selectedBg : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: selectedBorderColor, width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? selectedFg : unselectedFg,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? selectedFg : unselectedFg,
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
