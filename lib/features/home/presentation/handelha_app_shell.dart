import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';

class HandelhaAppShell extends StatelessWidget {
  const HandelhaAppShell({super.key, required this.child});
  final Widget child;

  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/tasks')) return 1;
    if (path.startsWith('/projects')) return 2;
    if (path.startsWith('/chat')) return 3;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    const paths = ['/home', '/tasks', '/projects', '/chat'];
    context.go(paths[index]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedIndex = _selectedIndex(context);
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            border: Border(top: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.divider)),
          ),
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 4),
          child: Row(
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'الرئيسية', selected: selectedIndex == 0, onTap: () => _navigate(context, 0)),
              _NavItem(icon: Icons.check_circle_outline_rounded, activeIcon: Icons.check_circle_rounded, label: 'المهام', selected: selectedIndex == 1, onTap: () => _navigate(context, 1)),
              _NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'المساعد', selected: selectedIndex == 3, onTap: () => _navigate(context, 3)),
              _NavItem(icon: Icons.folder_outlined, activeIcon: Icons.folder_rounded, label: 'المشاريع', selected: selectedIndex == 2, onTap: () => _navigate(context, 2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final primarySoftColor = isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft;
    final primaryStrongColor = isDark ? AppColors.darkPrimary : AppColors.primaryStrong;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final textSecondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? primarySoftColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(selected ? activeIcon : icon, size: 22, color: selected ? primaryStrongColor : textSecondaryColor),
                ),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 11, height: 1.15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? primaryStrongColor : textSecondaryColor)),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 34 : 0,
                  height: 3,
                  decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
