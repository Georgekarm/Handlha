import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// سياقات التحميل المختلفة
enum LoadingContext {
  general,
  accountCreation,
  login,
  logout,
  accountDeletion,
  sync,
  voiceAnalysis,
  aiProposal,
}

/// واجهة تحميل وتجهيز راقية بهوية Calm Intelligent Productivity
/// تحتوي على نبض هادئ دائري مع رسالة تفاعلية تعطي إحساسًا بالاحترافية.
class AppLoadingView extends StatefulWidget {
  final String? message;
  final String? subMessage;
  final bool showLogo;
  final LoadingContext context;

  const AppLoadingView({
    super.key,
    this.message,
    this.subMessage,
    this.showLogo = true,
    this.context = LoadingContext.general,
  });

  @override
  State<AppLoadingView> createState() => _AppLoadingViewState();
}

class _AppLoadingViewState extends State<AppLoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  String _getMessage() {
    if (widget.message != null) return widget.message!;
    switch (widget.context) {
      case LoadingContext.accountCreation:
        return 'بنجهز مساحتك';
      case LoadingContext.login:
        return 'نرجعك لمكانك';
      case LoadingContext.logout:
        return 'نشكر تواجدك';
      case LoadingContext.accountDeletion:
        return 'بننفذ طلبك';
      case LoadingContext.sync:
        return 'بنزامن تغييراتك';
      case LoadingContext.voiceAnalysis:
        return 'بنحوّل كلامك لخطوات';
      case LoadingContext.aiProposal:
        return 'بنجهز اقتراحات مناسبة';
      case LoadingContext.general:
      default:
        return 'جاري التحضير...';
    }
  }

  String _getSubMessage() {
    if (widget.subMessage != null) return widget.subMessage!;
    switch (widget.context) {
      case LoadingContext.accountCreation:
        return 'ثواني ونبدأ بأول خطوة.';
      case LoadingContext.login:
        return 'لحظات وستعود للمساحة الخاصة بك.';
      case LoadingContext.logout:
        return 'نتمنى لك يومًا هادئًا ومثمرًا.';
      case LoadingContext.accountDeletion:
        return 'العملية ممكن تاخد لحظات. ما تقفلش التطبيق دلوقتي.';
      case LoadingContext.sync:
        return 'تقدر تكمل استخدام التطبيق عادي.';
      case LoadingContext.voiceAnalysis:
        return 'راجع النتيجة قبل ما نحفظ أي حاجة.';
      case LoadingContext.aiProposal:
        return 'بنحلل الوضع الحالي ونقترح أفضل الخيارات.';
      case LoadingContext.general:
      default:
        return 'لحظات ونبدأ معًا';
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated breathing rings
          SizedBox(
            width: 100,
            height: 100,
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, child) {
                return CustomPaint(
                  painter: _PulseRingsPainter(
                    progress: _animCtrl.value,
                    isDark: isDark,
                  ),
                  child: widget.showLogo
                      ? Center(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [
                                        AppColors.darkPrimary,
                                        AppColors.darkPrimarySoft,
                                      ]
                                    : [
                                        AppColors.primary,
                                        AppColors.primaryStrong,
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDark
                                          ? AppColors.darkPrimary
                                          : AppColors.primary)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.spa_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          Text(
            _getMessage(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),

          Text(
            _getSubMessage(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PulseRingsPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _PulseRingsPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    for (int i = 0; i < 2; i++) {
      final ringProgress = (progress + (i * 0.5)) % 1.0;
      final radius = 28 + (maxRadius - 28) * ringProgress;
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0) * 0.35;

      final paint = Paint()
        ..color = primaryColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulseRingsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}
