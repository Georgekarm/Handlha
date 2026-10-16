import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class SplashLogoPainter extends CustomPainter {
  final bool dark;

  SplashLogoPainter({this.dark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Colors
    final coral = dark ? AppColors.darkAccent : AppColors.accent;
    final purple = dark ? AppColors.darkSecondary : AppColors.secondary;
    final mint = dark ? AppColors.darkPrimarySoft : AppColors.primarySoft;
    final teal = dark ? AppColors.darkPrimary : AppColors.primaryStrong;

    // Helper to draw a rounded stone
    void drawStone(double yCenter, double width, double height, Color color) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, yCenter), width: width, height: height),
        Radius.circular(height / 2),
      );
      canvas.drawRRect(rect, Paint()..color = color);
    }

    // Stones from bottom to top
    // Baseline is near bottom
    drawStone(h * 0.82, w * 0.8, h * 0.18, coral);
    drawStone(h * 0.62, w * 0.6, h * 0.16, purple);
    drawStone(h * 0.45, w * 0.45, h * 0.15, mint);
    
    // Checkmark above the stones
    final checkPaint = Paint()
      ..color = teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
      
    final checkPath = Path();
    checkPath.moveTo(w * 0.35, h * 0.18);
    checkPath.lineTo(w * 0.48, h * 0.28);
    checkPath.lineTo(w * 0.70, h * 0.05);
    
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant SplashLogoPainter oldDelegate) => oldDelegate.dark != dark;
}
