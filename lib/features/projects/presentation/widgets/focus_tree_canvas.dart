import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme_extension.dart';
import '../../../../shared/utils/arabic_formatters.dart';
import '../../domain/focus_session.dart';

/// Describes the user's current tree growth stage and completed grove metrics.
class FocusTreeProgress {
  const FocusTreeProgress({
    required this.completedTrees,
    required this.stageIndex,
    required this.visualGrowth,
    required this.stageProgress,
    required this.blossomCount,
    required this.todayMinutes,
    required this.totalMinutes,
  });

  final int completedTrees;
  final int stageIndex; // 0..4
  final double visualGrowth; // 0.06..1.0
  final double stageProgress; // 0.0..1.0 progress toward next stage
  final int blossomCount;
  final int todayMinutes;
  final int totalMinutes;

  static const int maxStageIndex = 4;

  static FocusTreeProgress compute({
    required List<FocusSession> sessions,
    double activeSessionFraction = 0.0,
    bool justCompleted = false,
  }) {
    final completedList = sessions.where((s) => s.completed).toList();
    final completedTrees = completedList.length;
    final totalMinutes = sessions.fold<int>(0, (sum, s) => sum + s.elapsedMinutes);

    final now = DateTime.now();
    final todayMinutes = sessions
        .where((s) =>
            s.endedAt.year == now.year &&
            s.endedAt.month == now.month &&
            s.endedAt.day == now.day)
        .fold<int>(0, (sum, s) => sum + s.elapsedMinutes);

    final clampedLive = activeSessionFraction.clamp(0.0, 1.0);
    final stageIndex = completedTrees.clamp(0, maxStageIndex);

    final double baseGrowth = switch (stageIndex) {
      0 => 0.08,
      1 => 0.32,
      2 => 0.56,
      3 => 0.78,
      _ => 1.0,
    };

    final double spanToNext = switch (stageIndex) {
      0 => 0.22,
      1 => 0.22,
      2 => 0.20,
      3 => 0.20,
      _ => 0.0,
    };

    final visualGrowth = justCompleted && completedTrees >= 1
        ? (stageIndex >= maxStageIndex ? 1.0 : (baseGrowth + spanToNext * 0.65))
            .clamp(0.08, 1.0)
        : (baseGrowth + clampedLive * spanToNext).clamp(0.08, 1.0);

    final stageProgress = stageIndex >= maxStageIndex
        ? 1.0
        : (justCompleted ? 1.0 : clampedLive.clamp(0.08, 1.0));

    final blossomCount =
        completedTrees <= 3 ? (stageIndex == 3 ? 3 : 0) : (completedTrees - 2).clamp(3, 14);

    return FocusTreeProgress(
      completedTrees: completedTrees,
      stageIndex: stageIndex,
      visualGrowth: visualGrowth,
      stageProgress: stageProgress,
      blossomCount: blossomCount,
      todayMinutes: todayMinutes,
      totalMinutes: totalMinutes,
    );
  }

  String stageTitle({required bool isEn}) {
    return switch (stageIndex) {
      0 => isEn ? 'Planted Seed' : 'بذرة جديدة',
      1 => isEn ? 'Young Sprout' : 'نبتة صغيرة',
      2 => isEn ? 'Growing Sapling' : 'شجرة بتكبر',
      3 => isEn ? 'Thriving Tree' : 'شجرة كبيرة',
      _ => isEn ? 'Blooming Tree' : 'شجرة كاملة ومورّدة',
    };
  }

  String stageShortLabel({required bool isEn, required int index}) {
    return switch (index) {
      0 => isEn ? 'Seed' : 'بذرة',
      1 => isEn ? 'Sprout' : 'نبتة',
      2 => isEn ? 'Growing' : 'بتكبر',
      3 => isEn ? 'Big' : 'كبيرة',
      _ => isEn ? 'Full' : 'كاملة',
    };
  }

  String stageSubtitle({required bool isEn}) {
    if (stageIndex >= maxStageIndex) {
      return isEn
          ? 'Your tree is in full bloom! Every new session adds more blossoms to your grove.'
          : 'عاش! شجرتك كبرت وكملت وطلّعت ورد، وكل جلسة زيادة بتنوّر جنينتك بورد أكتر.';
    }
    final remainingSessions = maxStageIndex - stageIndex;
    return isEn
        ? 'Complete $remainingSessions more focus session(s) to reach full bloom.'
        : 'باقي ${ArabicFormatters.toArabicDigits(remainingSessions)} جلسات تركيز عشان شجرتك تكبر وتكمل للآخر.';
  }
}

/// Interactive botanical stage card showing the animated growing focus tree.
class FocusTreeStageCard extends StatelessWidget {
  const FocusTreeStageCard({
    super.key,
    required this.progress,
    required this.isEn,
    this.compact = false,
  });

  final FocusTreeProgress progress;
  final bool isEn;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: isDark ? 0.14 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
            child: SizedBox(
              height: compact ? 120 : 228,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedFocusTreeCanvas(
                      growth: progress.visualGrowth,
                      blossomCount: progress.blossomCount,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: _OverlayPill(
                            label: progress.stageTitle(isEn: isEn),
                            c: c,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _OverlayPill(
                          label: isEn
                              ? 'Stage ${progress.stageIndex + 1}/5'
                              : 'المرحلة ${ArabicFormatters.toArabicDigits(progress.stageIndex + 1)}/٥',
                          c: c,
                          isDark: isDark,
                          accent: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: compact
                ? const EdgeInsets.fromLTRB(14, 10, 14, 12)
                : const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  progress.stageSubtitle(isEn: isEn),
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: compact ? 8 : 12),
                Row(
                  children: List.generate(5, (idx) {
                    final reached = idx <= progress.stageIndex;
                    final isCurrent = idx == progress.stageIndex;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: idx == 4 ? 0 : 6,
                        ),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: reached
                                    ? (isCurrent
                                        ? c.primary
                                        : c.primary.withValues(alpha: 0.7))
                                    : c.surfaceSoft,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              progress.stageShortLabel(isEn: isEn, index: idx),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isCurrent
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isCurrent
                                    ? c.primary
                                    : (reached ? c.textPrimary : c.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({
    required this.label,
    required this.c,
    required this.isDark,
    this.accent = false,
  });

  final String label;
  final AppThemeExtension c;
  final bool isDark;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isDark ? c.surface : Colors.white).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? c.primary.withValues(alpha: 0.32)
              : c.border.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accent ? c.warning : c.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Continuously animated canvas that smoothly renders the tree at [growth] (0..1).
class AnimatedFocusTreeCanvas extends StatefulWidget {
  const AnimatedFocusTreeCanvas({
    super.key,
    required this.growth,
    required this.blossomCount,
  });

  final double growth;
  final int blossomCount;

  @override
  State<AnimatedFocusTreeCanvas> createState() =>
      _AnimatedFocusTreeCanvasState();
}

class _AnimatedFocusTreeCanvasState extends State<AnimatedFocusTreeCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.08, end: widget.growth.clamp(0.05, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedGrowth, _) {
        return AnimatedBuilder(
          animation: _ambientController,
          builder: (context, _) {
            return CustomPaint(
              painter: _FocusTreePainter(
                growth: animatedGrowth,
                blossomCount: widget.blossomCount,
                phase: _ambientController.value,
                primary: c.primary,
                accent: c.accent,
                warning: c.warning,
                isDark: isDark,
              ),
              child: const SizedBox.expand(),
            );
          },
        );
      },
    );
  }
}

class _FocusTreePainter extends CustomPainter {
  const _FocusTreePainter({
    required this.growth,
    required this.blossomCount,
    required this.phase,
    required this.primary,
    required this.accent,
    required this.warning,
    required this.isDark,
  });

  final double growth;
  final int blossomCount;
  final double phase;
  final Color primary;
  final Color accent;
  final Color warning;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // 1. Calm Sky Backdrop
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? const [Color(0xFF0E2924), Color(0xFF153831), Color(0xFF1A423A)]
          : const [Color(0xFFE1F3ED), Color(0xFFEEF7F3), Color(0xFFF6FAF8)],
    );
    canvas.drawRect(rect, Paint()..shader = skyGradient.createShader(rect));

    // 2. Soft Sun / Moon Halo
    final sunCenter = Offset(w * 0.80, h * 0.25);
    final pulse = 1.0 + 0.08 * math.sin(phase * 2 * math.pi);
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDark ? const Color(0xFF8BE2CF) : const Color(0xFFFFE6A7))
              .withValues(alpha: isDark ? 0.28 : 0.72),
          (isDark ? const Color(0xFF51C7B5) : const Color(0xFFFFD166))
              .withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 46 * pulse));
    canvas.drawCircle(sunCenter, 46 * pulse, haloPaint);
    canvas.drawCircle(
      sunCenter,
      14,
      Paint()
        ..color = (isDark ? const Color(0xFFB5F2E4) : const Color(0xFFFFF1C7))
            .withValues(alpha: 0.85),
    );

    // 3. Drifting Ambient Fireflies / Light Motes
    final motePaint = Paint()
      ..color = (isDark ? const Color(0xFF9DF0DE) : warning)
          .withValues(alpha: 0.35);
    for (int i = 0; i < 6; i++) {
      final t = (phase + i * 0.17) % 1.0;
      final mx = w * (0.15 + 0.72 * ((i * 0.37) % 1.0)) +
          math.sin(t * 2 * math.pi + i) * 10;
      final my = h * (0.72 - t * 0.52);
      final r = 1.8 + (i % 3) * 0.8;
      canvas.drawCircle(
        Offset(mx, my),
        r,
        motePaint..color = motePaint.color.withValues(alpha: 0.38 * math.sin(t * math.pi)),
      );
    }

    // 4. Layered Rolling Hills & Rich Soil Bed
    final groundY = h * 0.82;
    final backHill = Path()
      ..moveTo(0, groundY + 4)
      ..quadraticBezierTo(w * 0.28, groundY - 22, w * 0.60, groundY - 4)
      ..quadraticBezierTo(w * 0.84, groundY + 8, w, groundY - 12)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      backHill,
      Paint()
        ..color = isDark ? const Color(0xFF1A463B) : const Color(0xFFC5E5DA),
    );

    final frontHill = Path()
      ..moveTo(0, groundY + 10)
      ..quadraticBezierTo(w * 0.50, groundY - 14, w, groundY + 12)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      frontHill,
      Paint()
        ..color = isDark ? const Color(0xFF205245) : const Color(0xFF9CD4C2),
    );

    final cx = w * 0.50;
    final baseY = groundY + 4;

    // Warm soil mound directly beneath the tree
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, baseY + 3), width: 64, height: 14),
      Paint()
        ..color = isDark ? const Color(0xFF3E3026) : const Color(0xFF7B5E49),
    );

    final sway = math.sin(phase * 2 * math.pi) * (2.5 + 3.5 * growth);

    // 5. Stage 0: Seed + Emerging Shoot
    if (growth < 0.22) {
      final seedProgress = ((growth - 0.05) / 0.17).clamp(0.0, 1.0);
      _drawSeedAndMicroShoot(canvas, cx, baseY, seedProgress, sway);
      return;
    }

    // 6. Trunk & Branches scaling smoothly with growth
    final treeScale = ((growth - 0.15) / 0.85).clamp(0.15, 1.0);
    final trunkHeight = (h * 0.42) * treeScale;
    final topY = baseY - trunkHeight;
    final trunkWidthBottom = 7.0 + 13.0 * treeScale;
    final trunkWidthTop = 2.5 + 4.5 * treeScale;

    final barkColor =
        isDark ? const Color(0xFF8A654D) : const Color(0xFF6F4E37);
    final barkShadow =
        isDark ? const Color(0xFF6B4D3A) : const Color(0xFF563B29);

    final trunkPath = Path()
      ..moveTo(cx - trunkWidthBottom * 0.65, baseY + 2)
      ..quadraticBezierTo(
        cx - trunkWidthBottom * 0.28,
        baseY - trunkHeight * 0.35,
        cx - trunkWidthTop * 0.5 + sway * 0.35,
        topY,
      )
      ..lineTo(cx + trunkWidthTop * 0.5 + sway * 0.35, topY)
      ..quadraticBezierTo(
        cx + trunkWidthBottom * 0.28,
        baseY - trunkHeight * 0.35,
        cx + trunkWidthBottom * 0.65,
        baseY + 2,
      )
      ..close();

    canvas.drawPath(
      trunkPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [barkShadow, barkColor],
        ).createShader(Rect.fromLTWH(cx - 20, topY, 40, trunkHeight)),
    );

    // Secondary Branches (appear cleanly from Sapling stage onward)
    if (treeScale > 0.32) {
      final branchAlpha = ((treeScale - 0.32) / 0.35).clamp(0.0, 1.0);
      final branchPaint = Paint()
        ..color = barkColor.withValues(alpha: branchAlpha)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.5 + 3.5 * treeScale;

      final leftBranch = Path()
        ..moveTo(cx + sway * 0.2, baseY - trunkHeight * 0.56)
        ..quadraticBezierTo(
          cx - 18 * treeScale,
          baseY - trunkHeight * 0.66,
          cx - 32 * treeScale + sway * 0.6,
          baseY - trunkHeight * 0.80,
        );
      canvas.drawPath(leftBranch, branchPaint);

      final rightBranch = Path()
        ..moveTo(cx + sway * 0.2, baseY - trunkHeight * 0.48)
        ..quadraticBezierTo(
          cx + 18 * treeScale,
          baseY - trunkHeight * 0.58,
          cx + 30 * treeScale + sway * 0.6,
          baseY - trunkHeight * 0.72,
        );
      canvas.drawPath(rightBranch, branchPaint);
    }

    // 7. Layered Organic Foliage Canopy
    final deepLeaf =
        isDark ? const Color(0xFF1F7A68) : const Color(0xFF186A5C);
    final midLeaf =
        isDark ? const Color(0xFF33A18B) : const Color(0xFF288E7E);
    final brightLeaf =
        isDark ? const Color(0xFF5AD0B9) : const Color(0xFF53B8A4);

    if (treeScale < 0.36) {
      // Young Sprout Twin Leaves
      _drawLeafPair(
        canvas,
        Offset(cx + sway * 0.4, topY),
        leafScale: 0.7 + treeScale,
        leafColor: midLeaf,
        highlightColor: brightLeaf,
      );
      return;
    }

    final canopyCenter = Offset(cx + sway * 0.75, topY - 4 * treeScale);
    final rBase = 24.0 + 36.0 * treeScale;

    final puffs = <({Offset offset, double radius, Color color})>[
      (
        offset: Offset(-rBase * 0.72, rBase * 0.18),
        radius: rBase * 0.68,
        color: deepLeaf,
      ),
      (
        offset: Offset(rBase * 0.72, rBase * 0.20),
        radius: rBase * 0.64,
        color: deepLeaf,
      ),
      (
        offset: Offset(0, -rBase * 0.32),
        radius: rBase * 0.78,
        color: midLeaf,
      ),
      (
        offset: Offset(-rBase * 0.36, -rBase * 0.04),
        radius: rBase * 0.66,
        color: midLeaf,
      ),
      (
        offset: Offset(rBase * 0.38, 0),
        radius: rBase * 0.64,
        color: midLeaf,
      ),
      (
        offset: Offset(-rBase * 0.14, -rBase * 0.42),
        radius: rBase * 0.50,
        color: brightLeaf.withValues(alpha: 0.85),
      ),
      (
        offset: Offset(rBase * 0.24, -rBase * 0.22),
        radius: rBase * 0.42,
        color: brightLeaf.withValues(alpha: 0.78),
      ),
    ];

    for (final p in puffs) {
      canvas.drawCircle(
        canopyCenter + p.offset,
        p.radius,
        Paint()..color = p.color,
      );
    }

    // 8. Blossoms & Fruits for Thriving / Complete Tree
    if (growth >= 0.72 && blossomCount > 0) {
      final bloomScale = ((growth - 0.72) / 0.28).clamp(0.0, 1.0);
      final spots = <Offset>[
        Offset(-rBase * 0.52, -rBase * 0.05),
        Offset(rBase * 0.45, -rBase * 0.14),
        Offset(-rBase * 0.08, -rBase * 0.55),
        Offset(rBase * 0.18, rBase * 0.18),
        Offset(-rBase * 0.68, rBase * 0.24),
        Offset(rBase * 0.68, rBase * 0.22),
        Offset(-rBase * 0.26, -rBase * 0.28),
        Offset(rBase * 0.32, -rBase * 0.42),
        Offset(0, rBase * 0.04),
        Offset(-rBase * 0.42, rBase * 0.28),
        Offset(rBase * 0.48, rBase * 0.06),
        Offset(rBase * 0.04, -rBase * 0.22),
      ];
      final count = blossomCount.clamp(0, spots.length);
      for (int i = 0; i < count; i++) {
        final pos = canopyCenter + spots[i];
        final isWarmFruit = i.isEven;
        final dotColor = isWarmFruit ? accent : const Color(0xFFFFF4D2);
        final r = (3.4 + (i % 2) * 1.1) * bloomScale;
        canvas.drawCircle(
          pos,
          r + 1.5,
          Paint()..color = dotColor.withValues(alpha: 0.25),
        );
        canvas.drawCircle(pos, r, Paint()..color = dotColor);
      }
    }
  }

  void _drawSeedAndMicroShoot(
    Canvas canvas,
    double cx,
    double baseY,
    double progress,
    double sway,
  ) {
    // Seed body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, baseY - 2), width: 14, height: 10),
      Paint()
        ..color = isDark ? const Color(0xFFB58963) : const Color(0xFF8C6239),
    );
    // Tiny green sprout tip emerging with progress
    final shootH = 12.0 + 18.0 * progress;
    final stemPaint = Paint()
      ..color = primary
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(cx, baseY - 5)
      ..quadraticBezierTo(cx + sway * 0.2, baseY - shootH * 0.6, cx + sway * 0.35, baseY - shootH);
    canvas.drawPath(path, stemPaint);

    if (progress > 0.25) {
      _drawLeafPair(
        canvas,
        Offset(cx + sway * 0.35, baseY - shootH),
        leafScale: 0.45 + 0.45 * progress,
        leafColor: primary,
        highlightColor: const Color(0xFF53B8A4),
      );
    }
  }

  void _drawLeafPair(
    Canvas canvas,
    Offset tip, {
    required double leafScale,
    required Color leafColor,
    required Color highlightColor,
  }) {
    final len = 18.0 * leafScale;
    final wid = 8.5 * leafScale;

    for (final dir in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(tip.dx, tip.dy);
      canvas.rotate(dir * 0.62);
      final leafPath = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(dir * len * 0.55, -wid, dir * len, -len * 0.28)
        ..quadraticBezierTo(dir * len * 0.45, wid * 0.55, 0, 0)
        ..close();
      canvas.drawPath(
        leafPath,
        Paint()..color = dir < 0 ? leafColor : highlightColor,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FocusTreePainter oldDelegate) {
    return oldDelegate.growth != growth ||
        oldDelegate.blossomCount != blossomCount ||
        oldDelegate.phase != phase ||
        oldDelegate.isDark != isDark ||
        oldDelegate.primary != primary;
  }
}
