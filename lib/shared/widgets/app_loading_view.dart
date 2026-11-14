import 'package:flutter/material.dart';

import '../../app/theme/app_theme_extension.dart';
import 'handelha_ambient_background.dart';
import 'handelha_header.dart';
import 'handelha_segmented_switch.dart';

enum LoadingCategory { tasks, projects, focus }

/// شاشة التحميل الهادئة.
class AppLoadingView extends StatefulWidget {
  final String title;
  final String headline;
  final String message;
  final String footerNote;
  final bool showHeader;
  final bool standalone;

  const AppLoadingView({
    super.key,
    this.title = 'جاري التحميل',
    this.headline = 'بنرتّب يومك...',
    this.message = 'ثواني ونكون معاك، خد نفس صغير.',
    this.footerNote = 'كل حاجة بتاخد وقتها. وإنت كمان.',
    this.showHeader = true,
    this.standalone = false,
  });

  @override
  State<AppLoadingView> createState() => _AppLoadingViewState();
}

class _AppLoadingViewState extends State<AppLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  LoadingCategory _category = LoadingCategory.tasks;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;

    final effectiveTitle =
        (isEn && widget.title == 'جاري التحميل') ? 'Loading' : widget.title;
    final effectiveHeadline = (isEn && widget.headline == 'بنرتّب يومك...')
        ? 'Organizing your day...'
        : widget.headline;
    final effectiveMessage =
        (isEn && widget.message == 'ثواني ونكون معاك، خد نفس صغير.')
            ? 'Just a moment, take a deep breath.'
            : widget.message;
    final effectiveFooter =
        (isEn && widget.footerNote == 'كل حاجة بتاخد وقتها. وإنت كمان.')
            ? 'Everything takes its time. And so do you.'
            : widget.footerNote;

    final content = SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 108),
        child: Column(
          children: [
            if (widget.showHeader)
              HandelhaHeader(
                title: effectiveTitle,
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.border, width: 1),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 82,
                    height: 82,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    effectiveHeadline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    effectiveMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            HandelhaSegmentedSwitch<LoadingCategory>(
              selected: _category,
              onChanged: (val) => setState(() => _category = val),
              options: [
                HandelhaSegmentOption(
                  value: LoadingCategory.tasks,
                  label: isEn ? 'Your Tasks' : 'مهامك',
                ),
                HandelhaSegmentOption(
                  value: LoadingCategory.projects,
                  label: isEn ? 'Your Projects' : 'مشروعاتك',
                ),
                HandelhaSegmentOption(
                  value: LoadingCategory.focus,
                  label: isEn ? 'Your Focus' : 'تركيزك',
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final alpha = 0.45 + (_controller.value * 0.35);
                return Opacity(
                  opacity: alpha,
                  child: Column(
                    children: [
                      _SkeletonCard(c: c),
                      const SizedBox(height: 12),
                      _SkeletonCard(c: c),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 5,
                backgroundColor: c.primarySoft,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              effectiveFooter,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );

    if (!widget.standalone) return content;

    return Scaffold(
      body: HandelhaAmbientBackground(child: content),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final AppThemeExtension c;

  const _SkeletonCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                FractionallySizedBox(
                  widthFactor: 0.68,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.surfaceSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
