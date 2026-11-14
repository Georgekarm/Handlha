import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/locale/language_controller.dart';
import '../../app/theme/app_theme_extension.dart';

/// شريط التنقل السفلي العائم بتصميم الكبسولة المطابق لمرجع التصميم (٥ تبويبات).
class HandelhaBottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const HandelhaBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  static const List<HandelhaNavTab> tabs = [
    HandelhaNavTab(
      route: '/home',
      label: 'الرئيسية',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    HandelhaNavTab(
      route: '/tasks',
      label: 'المهام',
      icon: Icons.checklist_rounded,
      activeIcon: Icons.checklist_rounded,
    ),
    HandelhaNavTab(
      route: '/projects',
      label: 'مشروعات',
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder_rounded,
    ),
    HandelhaNavTab(
      route: '/chat',
      label: 'المساعد',
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
    ),
    HandelhaNavTab(
      route: '/tracking',
      label: 'إنجازك',
      icon: Icons.bar_chart_rounded,
      activeIcon: Icons.bar_chart_rounded,
    ),
  ];

  static int indexForLocation(String location) {
    if (location.startsWith('/tasks')) return 1;
    if (location.startsWith('/projects') ||
        location.startsWith('/project-workspace') ||
        location.startsWith('/project-settings')) {
      return 2;
    }
    if (location.startsWith('/chat')) return 3;
    if (location.startsWith('/tracking')) return 4;
    if (location.startsWith('/home') || location.startsWith('/focus-session')) {
      return 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final isDark = context.isDark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? c.surface : c.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? c.border : c.border.withValues(alpha: 0.7),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final selected = i == currentIndex;
              final appLang = ref.watch(appLanguageProvider);
              final localizedLabel = _localizedTabLabel(tab, appLang);
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: localizedLabel,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (onTap != null) {
                        onTap!(i);
                      } else {
                        GoRouter.maybeOf(context)?.go(tab.route);
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          width: 48,
                          height: 30,
                          decoration: BoxDecoration(
                            color: selected ? c.primarySoft : Colors.transparent,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            selected ? tab.activeIcon : tab.icon,
                            size: 21,
                            color: selected ? c.primary : c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          localizedLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? c.primary : c.textSecondary,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  String _localizedTabLabel(HandelhaNavTab tab, AppLanguage lang) {
    if (!lang.isEnglish) return tab.label;
    return switch (tab.route) {
      '/home' => 'Home',
      '/tasks' => 'Tasks',
      '/projects' => 'Projects',
      '/chat' => 'Assistant',
      '/tracking' => 'Insights',
      _ => tab.label,
    };
  }
}

class HandelhaNavTab {
  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const HandelhaNavTab({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
