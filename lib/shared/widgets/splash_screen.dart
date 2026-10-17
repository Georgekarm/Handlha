import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../features/authentication/presentation/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStart() {
    final user = ref.read(authNotifierProvider).value;
    if (user != null) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final ringColor = isDark ? const Color(0xFF1B2E29) : const Color(0xFFE2EBE6);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Concentric circles with "هندلها" in center
                Center(
                  child: Container(
                    width: 310,
                    height: 310,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ringColor, width: 1.2),
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ringColor, width: 1.2),
                        color: isDark ? const Color(0xFF13201D) : const Color(0xFFEFF5F2),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'هندلها',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: primaryColor,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'مساحة أهدى للي في بالك',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                Text(
                  '.خطوة صغيرة. يوم أخف',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: textSecColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // Primary Button: "نبدأ بهدوء ←"
                ElevatedButton(
                  onPressed: _onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'نبدأ بهدوء',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkBackground : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: isDark ? AppColors.darkBackground : Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Footer
                Text(
                  'هندلها • رفيق يومك',
                  style: TextStyle(
                    fontSize: 12,
                    color: textMutedColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
