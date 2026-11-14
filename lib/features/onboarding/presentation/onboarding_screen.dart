import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/locale/language_controller.dart';
import '../../../app/theme/app_theme_extension.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../authentication/presentation/auth_providers.dart';

/// شاشة الترحيب ذات الشريحتين.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (_submitting) return;
    if (_pageIndex == 0) {
      await _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final isLoggedIn = ref.read(authNotifierProvider).value != null;
      if (isLoggedIn) {
        await ref.read(authNotifierProvider.notifier).markOnboardingComplete();
        if (mounted) context.go('/home');
      } else {
        if (mounted) context.go('/login');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final appLang = ref.watch(appLanguageProvider);
    final isEn = appLang.isEnglish;

    return Scaffold(
      body: HandelhaAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        ref.read(appLanguageProvider.notifier).setLanguage(
                              isEn ? AppLanguage.arEg : AppLanguage.en,
                            );
                      },
                      icon: Icon(Icons.language_rounded, size: 18, color: c.primary),
                      label: Text(
                        isEn ? 'عربي' : 'English',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _pageIndex = index),
                  children: [
                    _OnboardingSlideOne(isEn: isEn),
                    _OnboardingSlideTwo(isEn: isEn),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: c.primarySoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isEn
                                ? '${_pageIndex + 1} of 2'
                                : '${ArabicFormatters.toArabicDigits(_pageIndex + 1)} من ${ArabicFormatters.toArabicDigits(2)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: c.primary,
                            ),
                          ),
                        ),
                        if (_pageIndex == 1)
                          TextButton(
                            onPressed: () => _pageController.animateToPage(
                              0,
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOut,
                            ),
                            child: Text(
                              isEn ? 'Back' : 'السابق',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _handleNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: c.textOnPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          _pageIndex == 0
                              ? (isEn ? "Let's Start" : 'يلا نبدأ')
                              : (isEn ? 'Start with Handelha' : 'ابدأ مع هندلها'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.textOnPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlideOne extends StatelessWidget {
  final bool isEn;
  const _OnboardingSlideOne({required this.isEn});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            decoration: BoxDecoration(
              color: c.primarySoft.withValues(alpha: isDark ? 0.55 : 0.72),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: c.primary.withValues(alpha: isDark ? 0.18 : 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn
                      ? 'Sized for your pace, never overwhelming'
                      : 'على قدّك، مش فوق طاقتك',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 22,
                        color: c.primary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEn ? 'Start with the first step' : 'ابدأ بأول خطوة',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEn
                                  ? 'And we will handle the rest together'
                                  : 'والباقي هنهندله سوا',
                              style: TextStyle(
                                fontSize: 13,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 20,
                          color: c.lavenderAccent,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isEn ? 'A quiet moment for yourself' : 'وقت صغير لنفسك',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            isEn
                ? 'Your day needs clarity,\nnot extra pressure.'
                : 'يومك محتاج ترتيب،\nمش ضغط زيادة.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: c.textPrimary,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isEn
                ? 'Your tasks, projects, and focus in one calm place.\nWith a companion reminding you: one step at a time.'
                : 'مهامك ومشروعاتك وتركيزك في مكان واحد.\nومعاك حد يقولك: واحدة واحدة، هتوصل.',
            style: TextStyle(
              fontSize: 14.5,
              color: c.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlideTwo extends StatelessWidget {
  final bool isEn;
  const _OnboardingSlideTwo({required this.isEn});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
            decoration: BoxDecoration(
              color: c.primarySoft.withValues(alpha: isDark ? 0.55 : 0.72),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: c.primary.withValues(alpha: isDark ? 0.18 : 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn
                      ? 'Big idea? Let us break it down.'
                      : 'فكرة كبيرة؟ نصغّرها سوا.',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.primary,
                  ),
                ),
                const SizedBox(height: 18),
                _StepPill(
                  label: isEn
                      ? '1 Pick your top priority'
                      : '${ArabicFormatters.toArabicDigits(1)} حدّد أولويتك',
                  highlighted: true,
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _StepPill(
                    label: isEn
                        ? '2 Start with 25 minutes'
                        : '${ArabicFormatters.toArabicDigits(2)} ابدأ بـ ${ArabicFormatters.toArabicDigits(25)} دقيقة',
                    highlighted: false,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _StepPill(
                    label: isEn
                        ? '3 Feel the difference'
                        : '${ArabicFormatters.toArabicDigits(3)} شوف الفرق',
                    highlighted: false,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            isEn
                ? 'Every small step\nmakes a difference.'
                : 'كل خطوة صغيرة\nبتفرق معاك.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: c.textPrimary,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isEn
                ? 'The assistant organizes your thoughts, and focus sessions\nhelp you begin without burning out.'
                : 'المساعد يرتّب أفكارك، وجلسات التركيز\nتساعدك تبدأ من غير ما تستنزف نفسك.',
            style: TextStyle(
              fontSize: 14.5,
              color: c.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final String label;
  final bool highlighted;

  const _StepPill({
    required this.label,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: highlighted ? c.heroTeal : c.surface,
        borderRadius: BorderRadius.circular(16),
        border: highlighted ? null : Border.all(color: c.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: highlighted ? Colors.white : c.primary,
        ),
      ),
    );
  }
}
