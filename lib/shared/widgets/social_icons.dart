import 'dart:math';
import 'package:flutter/material.dart';

/// Authentic vector-drawn Google 'G' logo icon with accurate Google brand colors.
/// Uses CustomPainter for crisp rendering on all DPIs without external asset dependencies.
class GoogleLogoIcon extends StatelessWidget {
  final double size;

  const GoogleLogoIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final strokeWidth = w * 0.25;
    final radius = w / 2 - strokeWidth / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Draw arc segments to form a 'G'
    // Red: Top arc (from left to top-right)
    canvas.drawArc(rect, -pi, pi * 0.75, false, redPaint);
    
    // Yellow: Bottom-left arc
    canvas.drawArc(rect, pi * 0.75, pi * 0.25, false, yellowPaint);
    
    // Green: Bottom arc
    canvas.drawArc(rect, pi * 0.25, pi * 0.5, false, greenPaint);
    
    // Blue: Right-bottom arc
    canvas.drawArc(rect, 0, pi * 0.25, false, bluePaint);

    // Blue horizontal bar in the middle
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final barRect = Rect.fromLTRB(
      w * 0.45,
      h * 0.5 - strokeWidth / 2,
      w,
      h * 0.5 + strokeWidth / 2,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
