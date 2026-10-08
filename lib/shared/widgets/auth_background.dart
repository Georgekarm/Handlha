import 'dart:math';
import 'package:flutter/material.dart';

/// خلفية Authentication بعمق بصري هادئ — Calm Depth Background
///
/// تتكون من:
/// - Base color من Theme
/// - Radial gradient خفيف
/// - Abstract blurred blobs (دوائر ناعمة)
/// - خطوط هندسية رفيعة بـOpacity منخفض
///
/// مبنية بـCustomPainter لأداء عالي بدون صور Stock.
class AuthBackgroundPainter extends CustomPainter {
  final bool isDark;

  AuthBackgroundPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base colors for light / dark
    final Color blob1Color;
    final Color blob2Color;
    final Color blob3Color;
    final Color lineColor;

    if (isDark) {
      blob1Color = const Color(0xFF78B9AC).withValues(alpha: 0.08);
      blob2Color = const Color(0xFFA4A2C7).withValues(alpha: 0.06);
      blob3Color = const Color(0xFFD29A84).withValues(alpha: 0.04);
      lineColor = const Color(0xFF78B9AC).withValues(alpha: 0.04);
    } else {
      blob1Color = const Color(0xFF386B67).withValues(alpha: 0.06);
      blob2Color = const Color(0xFF77749B).withValues(alpha: 0.05);
      blob3Color = const Color(0xFFC8836C).withValues(alpha: 0.04);
      lineColor = const Color(0xFF386B67).withValues(alpha: 0.04);
    }

    // --- Blob 1: Top-right teal blob ---
    final blob1Paint = Paint()
      ..shader = RadialGradient(
        colors: [blob1Color, blob1Color.withValues(alpha: 0)],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(center: Offset(w * 0.85, h * 0.12), radius: w * 0.5),
      );
    canvas.drawCircle(Offset(w * 0.85, h * 0.12), w * 0.5, blob1Paint);

    // --- Blob 2: Bottom-left iris blob ---
    final blob2Paint = Paint()
      ..shader = RadialGradient(
        colors: [blob2Color, blob2Color.withValues(alpha: 0)],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(center: Offset(w * 0.1, h * 0.75), radius: w * 0.45),
      );
    canvas.drawCircle(Offset(w * 0.1, h * 0.75), w * 0.45, blob2Paint);

    // --- Blob 3: Center-right warm accent ---
    final blob3Paint = Paint()
      ..shader = RadialGradient(
        colors: [blob3Color, blob3Color.withValues(alpha: 0)],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(center: Offset(w * 0.7, h * 0.55), radius: w * 0.35),
      );
    canvas.drawCircle(Offset(w * 0.7, h * 0.55), w * 0.35, blob3Paint);

    // --- Geometric lines: subtle arcs ---
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Arc 1
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.3, h * 0.2), width: w * 0.6, height: w * 0.6),
      -pi / 4,
      pi / 2,
      false,
      linePaint,
    );

    // Arc 2
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.75, h * 0.8), width: w * 0.5, height: w * 0.5),
      pi / 3,
      pi / 3,
      false,
      linePaint,
    );

    // Small circle accent
    canvas.drawCircle(
      Offset(w * 0.2, h * 0.4),
      w * 0.08,
      linePaint,
    );
  }

  @override
  bool shouldRepaint(AuthBackgroundPainter oldDelegate) =>
      isDark != oldDelegate.isDark;
}

/// Widget wrapper للخلفية — يسهل استخدامها في أي شاشة Auth
class AuthBackground extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const AuthBackground({
    super.key,
    required this.child,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = isDark || brightness == Brightness.dark;
    final bgColor = dark
        ? const Color(0xFF111A19)
        : const Color(0xFFF6F7F5);

    return ColoredBox(
      color: bgColor,
      child: CustomPaint(
        painter: AuthBackgroundPainter(isDark: dark),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}
