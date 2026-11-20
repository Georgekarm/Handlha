import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../../shared/widgets/handelha_bottom_nav.dart';

/// الغلاف الرئيسي للتطبيق مع شريط التنقل السفلي العائم ذي الخمسة تبويبات.
class HandelhaAppShell extends StatelessWidget {
  final Widget child;
  final String currentLocation;

  const HandelhaAppShell({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final currentIndex = HandelhaBottomNav.indexForLocation(currentLocation);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      extendBody: !keyboardOpen,
      body: HandelhaAmbientBackground(
        child: child,
      ),
      bottomNavigationBar: keyboardOpen
          ? null
          : HandelhaBottomNav(
              currentIndex: currentIndex,
              onTap: (index) {
                final target = HandelhaBottomNav.tabs[index].route;
                if (!currentLocation.startsWith(target)) {
                  context.go(target);
                }
              },
            ),
    );
  }
}
