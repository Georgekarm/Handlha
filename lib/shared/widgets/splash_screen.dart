import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_extension.dart';
import '../../features/authentication/presentation/auth_providers.dart';
import 'handelha_ambient_background.dart';

/// شاشة البداية.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _progressAnim = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _redirectIfReady(AsyncValue<dynamic> authState) {
    if (authState.isLoading) return;
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final r = GoRouter.maybeOf(context);
      if (r == null) return;
      final user = authState.value;
      if (user != null) {
        r.go(user.onboardingComplete == true ? '/home' : '/onboarding');
      } else {
        r.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;
    final isEn = Directionality.of(context) == TextDirection.ltr;

    if (GoRouter.maybeOf(context) != null) {
      final authState = ref.watch(authNotifierProvider);
      _redirectIfReady(authState);
    }

    return Scaffold(
      body: HandelhaAmbientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 18),
                      SizedBox(
                        width: 310,
                        height: 270,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (final size in const [256.0, 206.0])
                              Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: c.primary.withValues(
                                      alpha: isDark ? 0.16 : 0.12,
                                    ),
                                    width: 1.1,
                                  ),
                                ),
                              ),
                            Container(
                              width: 158,
                              height: 158,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.primarySoft.withValues(
                                  alpha: isDark ? 0.65 : 0.72,
                                ),
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 108,
                                  height: 108,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 8,
                              child: _FloatingPillChip(
                                label: isEn ? 'Idea' : 'فكرة',
                                icon: Icons.auto_awesome_outlined,
                                iconColor: c.lavenderAccent,
                              ),
                            ),
                            Positioned(
                              bottom: 48,
                              left: 4,
                              child: _FloatingPillChip(
                                label: isEn ? 'Step' : 'خطوة',
                                icon: Icons.schedule_rounded,
                                iconColor: c.primary,
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              right: 6,
                              child: _FloatingPillChip(
                                label: isEn ? 'Progress' : 'إنجاز',
                                icon: Icons.check_rounded,
                                iconColor: c.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            isEn ? 'Handelha' : 'هندلها',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: c.primary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isEn
                                ? 'Your day made simpler, step by step.'
                                : 'يومك أبسط، خطوة بخطوة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: c.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: c.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.2 : 0.04,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEn
                                      ? 'Preparing your space...'
                                      : 'بنجهّز مساحتك...',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isEn
                                      ? 'Your tasks, ideas, and time for yourself.'
                                      : 'مهامك، أفكارك، ووقت لنفسك.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: c.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                AnimatedBuilder(
                                  animation: _progressAnim,
                                  builder: (context, _) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: _progressAnim.value,
                                        minHeight: 5,
                                        backgroundColor: c.primarySoft,
                                        color: c.primary,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            isEn ? 'Take it step by step' : 'خدها خطوة خطوة',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FloatingPillChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;

  const _FloatingPillChip({
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: isDark ? 0.94 : 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
