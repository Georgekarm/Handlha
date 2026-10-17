import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/quick_add_bottom_sheet.dart';

class HandelhaAppShell extends StatelessWidget {
  const HandelhaAppShell({super.key, required this.child});
  final Widget child;

  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/tasks')) return 1;
    if (path.startsWith('/projects')) return 3;
    if (path.startsWith('/tracking')) return 4;
    return 0; // home
  }

  void _navigate(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    const paths = ['/home', '/tasks', '', '/projects', '/tracking'];
    if (index == 2) {
      QuickAddBottomSheet.show(context);
      return;
    }
    context.go(paths[index]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedIndex = _selectedIndex(context);
    final currentPath = GoRouterState.of(context).uri.path;
    final showAssistantFab = !currentPath.startsWith('/chat');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Stack(
        children: [
          child,
          // Floating Assistant Pill Button ("المساعد") above the bottom navigation bar
          if (showAssistantFab)
            PositionedDirectional(
              bottom: 16,
              end: 16,
              child: SafeArea(
                child: Semantics(
                  button: true,
                  label: 'المساعد',
                  child: Material(
                    color: AppColors.assistantPurple,
                    elevation: 4,
                    shadowColor: Colors.black45,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/chat');
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'المساعد',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            border: Border(top: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.divider)),
          ),
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(
            children: [
              // 1. الرئيسية
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'الرئيسية',
                selected: selectedIndex == 0,
                onTap: () => _navigate(context, 0),
              ),
              // 2. المهام
              _NavItem(
                icon: Icons.check_circle_outline_rounded,
                activeIcon: Icons.check_circle_rounded,
                label: 'المهام',
                selected: selectedIndex == 1,
                onTap: () => _navigate(context, 1),
              ),
              // 3. إضافة (Central Prominent + Button)
              Expanded(
                child: InkWell(
                  onTap: () => _navigate(context, 2),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 24,
                            color: isDark ? AppColors.darkBackground : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'إضافة',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 4. المشاريع
              _NavItem(
                icon: Icons.folder_outlined,
                activeIcon: Icons.folder_rounded,
                label: 'المشاريع',
                selected: selectedIndex == 3,
                onTap: () => _navigate(context, 3),
              ),
              // 5. المتابعة
              _NavItem(
                icon: Icons.bar_chart_rounded,
                activeIcon: Icons.bar_chart_rounded,
                label: 'المتابعة',
                selected: selectedIndex == 4,
                onTap: () => _navigate(context, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
    final textSecondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
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
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    selected ? activeIcon : icon,
                    size: 22,
                    color: selected ? primaryStrongColor : textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? primaryStrongColor : textSecondaryColor,
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
