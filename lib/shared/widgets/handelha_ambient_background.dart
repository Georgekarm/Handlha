import 'package:flutter/material.dart';

import '../../app/theme/app_theme_extension.dart';

/// خلفية التطبيق الهادئة المتطابقة مع المرجع (توهّج ناعم + أقواس دائرية + شبكة نقاط).
class HandelhaAmbientBackground extends StatelessWidget {
  final Widget child;
  final bool showDecorations;

  const HandelhaAmbientBackground({
    super.key,
    required this.child,
    this.showDecorations = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Cached GPU layer for the ambient glows, arcs, and dot matrix so
        // scrolling and tab switches never trigger background repaints or lag.
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: _AmbientBackdropLayer(
                backgroundColor: c.background,
                glowTopRight: c.glowTopRight,
                glowBottomLeft: c.glowBottomLeft,
                primaryColor: c.primary,
                isDark: isDark,
                showDecorations: showDecorations,
              ),
            ),
          ),
        ),

        child,
      ],
    );
  }
}

class _AmbientBackdropLayer extends StatelessWidget {
  final Color backgroundColor;
  final Color glowTopRight;
  final Color glowBottomLeft;
  final Color primaryColor;
  final bool isDark;
  final bool showDecorations;

  const _AmbientBackdropLayer({
    required this.backgroundColor,
    required this.glowTopRight,
    required this.glowBottomLeft,
    required this.primaryColor,
    required this.isDark,
    required this.showDecorations,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: backgroundColor),

        // Top-right soft teal radial glow
        Positioned(
          top: -110,
          right: -110,
          width: 420,
          height: 420,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  glowTopRight.withValues(alpha: isDark ? 0.85 : 0.90),
                  glowTopRight.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.72],
              ),
            ),
          ),
        ),

        // Bottom-left soft lavender radial glow
        Positioned(
          bottom: -130,
          left: -120,
          width: 440,
          height: 440,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  glowBottomLeft.withValues(alpha: isDark ? 0.88 : 0.85),
                  glowBottomLeft.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.74],
              ),
            ),
          ),
        ),

        if (showDecorations)
          Positioned.fill(
            child: CustomPaint(
              isComplex: true,
              willChange: false,
              painter: _AmbientPatternPainter(
                arcColor: (isDark ? Colors.white : primaryColor)
                    .withValues(alpha: isDark ? 0.045 : 0.055),
                dotColor: (isDark ? Colors.white : primaryColor)
                    .withValues(alpha: isDark ? 0.065 : 0.085),
              ),
            ),
          ),
      ],
    );
  }
}

class _AmbientPatternPainter extends CustomPainter {
  final Color arcColor;
  final Color dotColor;

  const _AmbientPatternPainter({
    required this.arcColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Subtle concentric circles anchored near upper-left
    const center = Offset(-18, 180);
    for (final radius in const [96.0, 148.0, 200.0, 252.0]) {
      canvas.drawCircle(center, radius, arcPaint);
    }

    // Subtle 5x6 dot matrix in upper-left corner
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    const startX = 24.0;
    const startY = 72.0;
    const step = 12.0;
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 5; col++) {
        canvas.drawCircle(
          Offset(startX + col * step, startY + row * step),
          1.25,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPatternPainter oldDelegate) =>
      oldDelegate.arcColor != arcColor || oldDelegate.dotColor != dotColor;
}

