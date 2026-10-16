import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// علامة «هندلها» المتجهة: ورقتان صغيرتان تنموان من خطوة واحدة.
class HandelhaMark extends StatelessWidget {
  const HandelhaMark({super.key, this.size = 42, this.dark = false});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _HandelhaMarkPainter(dark: dark),
      );
}

class HandelhaLogo extends StatelessWidget {
  const HandelhaLogo({
    super.key,
    this.markSize = 36,
    this.fontSize = 22,
    this.dark = false,
    this.showWordmark = true,
  });

  final double markSize;
  final double fontSize;
  final bool dark;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HandelhaMark(size: markSize, dark: dark),
        if (showWordmark) ...[
          const SizedBox(width: 7),
          Text(
            'هندلها',
            style: TextStyle(
              color: foreground,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
        ],
      ],
    );
  }
}

class _HandelhaMarkPainter extends CustomPainter {
  const _HandelhaMarkPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final stemColor = dark ? AppColors.darkPrimary : AppColors.primaryStrong;
    final leftColor = dark ? AppColors.darkPrimary : AppColors.primary;
    final rightColor = dark ? AppColors.darkPrimaryStrong : AppColors.success;

    final stem = Paint()
      ..color = stemColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(50 * s, 83 * s), Offset(50 * s, 39 * s), stem);
    canvas.drawLine(Offset(50 * s, 64 * s), Offset(34 * s, 48 * s), stem);

    final leftLeaf = Path()
      ..moveTo(34 * s, 49 * s)
      ..cubicTo(14 * s, 47 * s, 13 * s, 29 * s, 17 * s, 18 * s)
      ..cubicTo(35 * s, 20 * s, 45 * s, 32 * s, 42 * s, 48 * s)
      ..cubicTo(39 * s, 51 * s, 36 * s, 51 * s, 34 * s, 49 * s)
      ..close();
    final rightLeaf = Path()
      ..moveTo(51 * s, 41 * s)
      ..cubicTo(52 * s, 20 * s, 68 * s, 10 * s, 84 * s, 12 * s)
      ..cubicTo(84 * s, 31 * s, 74 * s, 44 * s, 54 * s, 47 * s)
      ..cubicTo(52 * s, 46 * s, 51 * s, 44 * s, 51 * s, 41 * s)
      ..close();
    canvas.drawPath(leftLeaf, Paint()..color = leftColor);
    canvas.drawPath(rightLeaf, Paint()..color = rightColor);

    final vein = Paint()
      ..color = (dark ? AppColors.darkBackground : Colors.white).withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(21 * s, 23 * s), Offset(37 * s, 43 * s), vein);
    canvas.drawLine(Offset(79 * s, 17 * s), Offset(56 * s, 40 * s), vein);
  }

  @override
  bool shouldRepaint(covariant _HandelhaMarkPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
