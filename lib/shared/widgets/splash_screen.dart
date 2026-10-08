import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'splash_logo_painter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? AppColors.darkTextPrimary : AppColors.primaryStrong; // "هندلها" text is teal in PDF
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Stack(
        children: [
          // Splash blobs
          Positioned.fill(
            child: CustomPaint(
              painter: _SplashBackgroundPainter(isDark: isDark),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    // Stones logo
                    Center(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: SplashLogoPainter(dark: isDark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Logo text
                    Text(
                      'هندلها',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      'من الزحمة للخطوة الجاية',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: secondary,
                      ),
                    ),
                    const Spacer(),
                    // Progress bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          backgroundColor: isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? AppColors.darkPrimary : AppColors.primaryStrong,
                          ),
                          value: 0.6, // Visual representation of loading
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'بنرتّب مساحتك....',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: secondary,
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackgroundPainter extends CustomPainter {
  final bool isDark;

  _SplashBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final mintColor = isDark 
        ? AppColors.darkPrimarySoft.withValues(alpha: 0.3)
        : AppColors.primarySoft;

    final blobPaint = Paint()
      ..color = mintColor
      ..style = PaintingStyle.fill;

    // Top Right blob (simple large circle cut off)
    canvas.drawCircle(Offset(w * 0.9, h * 0.1), w * 0.45, blobPaint);

    // Bottom Left blob with leaves
    canvas.drawCircle(Offset(w * 0.1, h * 0.9), w * 0.4, blobPaint);

    // Subtle leaves in bottom left
    final leafPaint = Paint()
      ..color = isDark ? AppColors.darkPrimary : AppColors.primary
      ..style = PaintingStyle.fill;
      
    final leafPath = Path();
    // Simplified leaf shape
    leafPath.moveTo(0, h * 0.85);
    leafPath.quadraticBezierTo(w * 0.1, h * 0.80, w * 0.15, h * 0.85);
    leafPath.quadraticBezierTo(w * 0.05, h * 0.9, 0, h * 0.9);
    
    leafPath.moveTo(0, h * 0.78);
    leafPath.quadraticBezierTo(w * 0.15, h * 0.70, w * 0.25, h * 0.78);
    leafPath.quadraticBezierTo(w * 0.1, h * 0.85, 0, h * 0.82);
    
    leafPath.moveTo(w * 0.15, h * 0.95);
    leafPath.quadraticBezierTo(w * 0.25, h * 0.88, w * 0.35, h * 0.92);
    leafPath.quadraticBezierTo(w * 0.2, h * 0.98, w * 0.15, h * 1.0);
    
    canvas.drawPath(leafPath, leafPaint);
  }

  @override
  bool shouldRepaint(covariant _SplashBackgroundPainter oldDelegate) => 
      oldDelegate.isDark != isDark;
}
