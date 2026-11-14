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
        // Base background
        ColoredBox(color: c.background),

        // Top-right soft teal radial glow
        Positioned(
          top: -110,
          right: -110,
          width: 420,
          height: 420,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c.glowTopRight.withValues(alpha: isDark ? 0.85 : 0.90),
                    c.glowTopRight.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.72],
                ),
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
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c.glowBottomLeft.withValues(alpha: isDark ? 0.88 : 0.85),
                    c.glowBottomLeft.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.74],
                ),
              ),
            ),
          ),
        ),

        if (showDecorations)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AmbientPatternPainter(
                  arcColor: (isDark ? Colors.white : c.primary)
                      .withValues(alpha: isDark ? 0.045 : 0.055),
                  dotColor: (isDark ? Colors.white : c.primary)
                      .withValues(alpha: isDark ? 0.065 : 0.085),
                ),
              ),
            ),
          ),

        child,
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

