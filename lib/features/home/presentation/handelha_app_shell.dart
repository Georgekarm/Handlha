import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../../shared/widgets/handelha_bottom_nav.dart';

/// الغلاف الرئيسي للتطبيق مع شريط التنقل السفلي العائم ذي الخمسة تبويبات
/// وخلفية ثابتة مخزّنة في طبقة GPU واحدة لتبديل فوري بلا أي وميض أو تأخير.
class HandelhaAppShell extends StatelessWidget {
  final Widget? child;
  final String? currentLocation;
  final StatefulNavigationShell? navigationShell;

  const HandelhaAppShell({
    super.key,
    required Widget this.child,
    required String this.currentLocation,
  }) : navigationShell = null;

  const HandelhaAppShell.fromShell({
    super.key,
    required StatefulNavigationShell this.navigationShell,
  }) : child = null,
       currentLocation = null;

  @override
  Widget build(BuildContext context) {
    final shell = navigationShell;
    final currentIndex = shell != null
        ? shell.currentIndex
        : HandelhaBottomNav.indexForLocation(currentLocation ?? '/home');
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    void switchToTab(int index) {
      if (shell != null) {
        shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        );
        return;
      }
      final target = HandelhaBottomNav.tabs[index].route;
      if (!(currentLocation ?? '').startsWith(target)) {
        context.go(target);
      }
    }

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && currentIndex != 0) {
          switchToTab(0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: !keyboardOpen,
        body: HandelhaAmbientBackground(
          child: shell ?? child!,
        ),
        bottomNavigationBar: keyboardOpen
            ? null
            : HandelhaBottomNav(
                currentIndex: currentIndex,
                onTap: switchToTab,
              ),
      ),
    );
  }
}
