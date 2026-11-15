import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme_extension.dart';
import '../../../../core/audio/handelha_sound_engine.dart';
import '../../../../shared/utils/arabic_formatters.dart';

/// Sleek sliding segmented tab bar switching between Timer & Sounds and Your Tree.
class FocusTabSwitcher extends StatelessWidget {
  const FocusTabSwitcher({
    super.key,
    required this.isTreeTab,
    required this.completedTreesCount,
    required this.isEn,
    required this.onSelectTimer,
    required this.onSelectTree,
  });

  final bool isTreeTab;
  final int completedTreesCount;
  final bool isEn;
  final VoidCallback onSelectTimer;
  final VoidCallback onSelectTree;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: isTreeTab
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Container(
                  width: tabWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.25 : 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: isEn ? 'Timer & Sounds' : 'المؤقت والأصوات',
                      selected: !isTreeTab,
                      onTap: onSelectTimer,
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      label: isEn ? 'Your Tree' : 'شجرتك',
                      badge: completedTreesCount > 0
                          ? (isEn
                              ? '$completedTreesCount'
                              : ArabicFormatters.toArabicDigits(
                                  completedTreesCount,
                                ))
                          : null,
                      selected: isTreeTab,
                      onTap: onSelectTree,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? c.primary : c.textSecondary,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: selected ? c.primarySoft : c.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected ? c.primary : c.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern animated focus dial with breathing aura, tick ring, and glowing tip.
class ModernFocusDial extends StatefulWidget {
  const ModernFocusDial({
    super.key,
    required this.remainingSeconds,
    required this.progress,
    required this.ringColor,
    required this.phaseLabel,
    required this.subLabel,
    required this.isRunning,
    this.treeProgressPercent,
    this.isEn = false,
  });

  final int remainingSeconds;
  final double progress;
  final Color ringColor;
  final String phaseLabel;
  final String subLabel;
  final bool isRunning;
  final int? treeProgressPercent;
  final bool isEn;

  @override
  State<ModernFocusDial> createState() => _ModernFocusDialState();
}

class _ModernFocusDialState extends State<ModernFocusDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    if (widget.isRunning) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ModernFocusDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRunning && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;
    final timeText = ArabicFormatters.toArabicDigits(
      ArabicFormatters.timerMmSs(widget.remainingSeconds),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final dialSize = math.min(224.0, math.max(176.0, constraints.maxWidth * 0.62));
        return Center(
          child: SizedBox(
            width: dialSize,
            height: dialSize,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: widget.progress.clamp(0.0, 1.0),
                end: widget.progress.clamp(0.0, 1.0),
              ),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, smoothProgress, _) {
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _FocusDialPainter(
                        progress: smoothProgress,
                        pulse: widget.isRunning ? _pulseController.value : 0.25,
                        ringColor: widget.ringColor,
                        trackColor: widget.ringColor.withValues(alpha: 0.14),
                        tickColor: c.border,
                        surfaceColor: c.surface,
                        isDark: isDark,
                      ),
                      child: child,
                    );
                  },
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.ringColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: widget.ringColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    widget.phaseLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: widget.ringColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              timeText,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                color: c.textPrimary,
                                height: 1.0,
                                letterSpacing: 1.0,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.subLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: c.textSecondary,
                              ),
                            ),
                            if (widget.treeProgressPercent != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                widget.isEn
                                    ? 'Tree ${widget.treeProgressPercent}%'
                                    : 'نمو شجرتك ${ArabicFormatters.toArabicDigits(widget.treeProgressPercent!)}٪',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _FocusDialPainter extends CustomPainter {
  const _FocusDialPainter({
    required this.progress,
    required this.pulse,
    required this.ringColor,
    required this.trackColor,
    required this.tickColor,
    required this.surfaceColor,
    required this.isDark,
  });

  final double progress;
  final double pulse;
  final Color ringColor;
  final Color trackColor;
  final Color tickColor;
  final Color surfaceColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;

    // 1. Breathing ambient aura
    final haloRadius = outerRadius + 10 + (pulse * 8);
    canvas.drawCircle(
      center,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            ringColor.withValues(alpha: 0.14 + pulse * 0.08),
            ringColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
    );

    // 2. Inner crisp dial surface
    final discRadius = outerRadius - 6;
    canvas.drawCircle(
      center,
      discRadius,
      Paint()..color = surfaceColor,
    );
    canvas.drawCircle(
      center,
      discRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.25 : 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 3. Subtle 60 radial ticks inside the ring
    final tickOuter = discRadius - 14;
    for (int i = 0; i < 60; i++) {
      final isMajor = i % 5 == 0;
      final angle = -math.pi / 2 + (i / 60) * 2 * math.pi;
      final len = isMajor ? 6.0 : 3.0;
      final p1 = Offset(
        center.dx + math.cos(angle) * tickOuter,
        center.dy + math.sin(angle) * tickOuter,
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * (tickOuter - len),
        center.dy + math.sin(angle) * (tickOuter - len),
      );
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = (isMajor ? ringColor.withValues(alpha: 0.35) : tickColor)
          ..strokeWidth = isMajor ? 1.5 : 1.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // 4. Recessed track arc
    final ringRadius = discRadius - 4;
    final arcRect = Rect.fromCircle(center: center, radius: ringRadius);
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );

    // 5. Smooth gradient active progress arc
    if (progress > 0.005) {
      final sweep = 2 * math.pi * progress;
      final lightAccent = Color.lerp(ringColor, Colors.white, 0.28)!;
      final arcPaint = Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: [ringColor, lightAccent, ringColor],
          stops: const [0.0, 0.65, 1.0],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(arcRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9.5
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(arcRect, -math.pi / 2, sweep, false, arcPaint);

      // Glowing tip dot
      final tipAngle = -math.pi / 2 + sweep;
      final tipPos = Offset(
        center.dx + math.cos(tipAngle) * ringRadius,
        center.dy + math.sin(tipAngle) * ringRadius,
      );
      canvas.drawCircle(
        tipPos,
        7.5,
        Paint()..color = ringColor.withValues(alpha: 0.25),
      );
      canvas.drawCircle(
        tipPos,
        4.2,
        Paint()..color = surfaceColor,
      );
      canvas.drawCircle(
        tipPos,
        2.5,
        Paint()..color = ringColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FocusDialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.isDark != isDark;
  }
}

/// Interactive modern ruler scrubbing bar + presets for focus & break durations.
class FocusDurationRulerBar extends StatelessWidget {
  const FocusDurationRulerBar({
    super.key,
    required this.selectedMinutes,
    required this.selectedBreakMinutes,
    required this.isEn,
    required this.onSelectMinutes,
    required this.onSelectBreakMinutes,
  });

  final int selectedMinutes;
  final int selectedBreakMinutes;
  final bool isEn;
  final ValueChanged<int> onSelectMinutes;
  final ValueChanged<int> onSelectBreakMinutes;

  static const int minMinutes = 5;
  static const int maxMinutes = 120;
  static const int stepMinutes = 5;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final clamped = selectedMinutes.clamp(minMinutes, maxMinutes);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isEn ? 'Session Duration' : 'مدة الجلسة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Container(
                  key: ValueKey<int>(clamped),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isEn
                        ? '$clamped min'
                        : '${ArabicFormatters.toArabicDigits(clamped)} دقيقة',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: c.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Modern Interactive Scrubbing Ruler Bar
          _RulerScrubberTrack(
            minutes: clamped,
            isRtl: isRtl,
            isEn: isEn,
            onMinutesChanged: onSelectMinutes,
          ),

          const SizedBox(height: 10),

          // Clean single-row quick presets
          Row(
            children: [
              for (final mins in const [15, 25, 45, 60, 90])
                Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: mins == 90 ? 0 : 6,
                    ),
                    child: _PresetPill(
                      label: isEn
                          ? '${mins}m'
                          : '${ArabicFormatters.toArabicDigits(mins)} د',
                      selected: clamped == mins,
                      onTap: () => onSelectMinutes(mins),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: c.divider),
          const SizedBox(height: 10),

          // Compact segmented Break Duration control (overflow-safe)
          Row(
            children: [
              Expanded(
                child: Text(
                  isEn ? 'Break' : 'الاستراحة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: c.surfaceSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final bMin in const [5, 10, 15])
                            GestureDetector(
                              onTap: () => onSelectBreakMinutes(bMin),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedBreakMinutes == bMin
                                      ? c.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  isEn
                                      ? '${bMin}m'
                                      : '${ArabicFormatters.toArabicDigits(bMin)} د',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: selectedBreakMinutes == bMin
                                        ? c.textOnPrimary
                                        : c.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RulerScrubberTrack extends StatelessWidget {
  const _RulerScrubberTrack({
    required this.minutes,
    required this.isRtl,
    required this.isEn,
    required this.onMinutesChanged,
  });

  final int minutes;
  final bool isRtl;
  final bool isEn;
  final ValueChanged<int> onMinutesChanged;

  void _updateFromLocalDx(double localDx, double width) {
    if (width <= 0) return;
    final rawRatio = (localDx / width).clamp(0.0, 1.0);
    final ratio = isRtl ? (1.0 - rawRatio) : rawRatio;
    const range =
        FocusDurationRulerBar.maxMinutes - FocusDurationRulerBar.minMinutes;
    final rawMinutes = FocusDurationRulerBar.minMinutes + ratio * range;
    final snapped = ((rawMinutes / FocusDurationRulerBar.stepMinutes).round() *
            FocusDurationRulerBar.stepMinutes)
        .clamp(
      FocusDurationRulerBar.minMinutes,
      FocusDurationRulerBar.maxMinutes,
    );
    if (snapped != minutes) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
      onMinutesChanged(snapped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;
    final targetRatio = (minutes - FocusDurationRulerBar.minMinutes) /
        (FocusDurationRulerBar.maxMinutes - FocusDurationRulerBar.minMinutes);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _updateFromLocalDx(d.localPosition.dx, width),
          onHorizontalDragStart: (d) =>
              _updateFromLocalDx(d.localPosition.dx, width),
          onHorizontalDragUpdate: (d) =>
              _updateFromLocalDx(d.localPosition.dx, width),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: targetRatio, end: targetRatio),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, animRatio, _) {
              return Container(
                height: 60,
                decoration: BoxDecoration(
                  color: c.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: CustomPaint(
                    painter: _DurationRulerPainter(
                      ratio: animRatio,
                      isRtl: isRtl,
                      isEn: isEn,
                      primary: c.primary,
                      surfaceColor: c.surface,
                      tickMuted: c.textMuted.withValues(alpha: 0.45),
                      labelColor: c.textSecondary,
                      isDark: isDark,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DurationRulerPainter extends CustomPainter {
  const _DurationRulerPainter({
    required this.ratio,
    required this.isRtl,
    required this.isEn,
    required this.primary,
    required this.surfaceColor,
    required this.tickMuted,
    required this.labelColor,
    required this.isDark,
  });

  final double ratio;
  final bool isRtl;
  final bool isEn;
  final Color primary;
  final Color surfaceColor;
  final Color tickMuted;
  final Color labelColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    const padX = 14.0;
    final usableW = (size.width - padX * 2).clamp(1.0, size.width);
    final thumbX = isRtl
        ? (size.width - padX - ratio * usableW)
        : (padX + ratio * usableW);

    // 1. Filled gradient highlight zone
    final fillRect = isRtl
        ? Rect.fromLTRB(thumbX, 0, size.width, size.height)
        : Rect.fromLTRB(0, 0, thumbX, size.height);
    canvas.drawRect(
      fillRect,
      Paint()
        ..shader = LinearGradient(
          begin: isRtl ? Alignment.centerRight : Alignment.centerLeft,
          end: isRtl ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            primary.withValues(alpha: isDark ? 0.14 : 0.08),
            primary.withValues(alpha: isDark ? 0.34 : 0.24),
          ],
        ).createShader(fillRect),
    );

    // 2. Precision tick marks across 5..120 (24 intervals of 5 min)
    const totalSteps = 23; // (120 - 5) / 5 = 23 intervals
    for (int i = 0; i <= totalSteps; i++) {
      final stepMinutes = 5 + i * 5;
      final stepRatio = i / totalSteps;
      final x = isRtl
          ? (size.width - padX - stepRatio * usableW)
          : (padX + stepRatio * usableW);

      final isMajor = stepMinutes == 5 ||
          stepMinutes == 30 ||
          stepMinutes == 60 ||
          stepMinutes == 90 ||
          stepMinutes == 120;
      final isPassed = stepRatio <= ratio + 0.001;
      final tickH = isMajor ? 18.0 : (stepMinutes % 15 == 0 ? 12.0 : 8.0);
      final topY = 10.0;

      canvas.drawLine(
        Offset(x, topY),
        Offset(x, topY + tickH),
        Paint()
          ..color = isPassed ? primary.withValues(alpha: 0.72) : tickMuted
          ..strokeWidth = isMajor ? 2.0 : 1.3
          ..strokeCap = StrokeCap.round,
      );

      if (isMajor) {
        final label = isEn
            ? '$stepMinutes'
            : ArabicFormatters.toArabicDigits(stepMinutes);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: isPassed ? primary : labelColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, size.height - tp.height - 6));
      }
    }

    // 3. Glowing vertical thumb indicator pill
    final handleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(thumbX, size.height * 0.44),
        width: 10,
        height: 36,
      ),
      const Radius.circular(999),
    );
    canvas.drawRRect(
      handleRect.inflate(3),
      Paint()..color = primary.withValues(alpha: 0.20),
    );
    canvas.drawRRect(handleRect, Paint()..color = primary);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(thumbX, size.height * 0.44),
          width: 3,
          height: 16,
        ),
        const Radius.circular(999),
      ),
      Paint()..color = surfaceColor,
    );
  }

  @override
  bool shouldRepaint(covariant _DurationRulerPainter oldDelegate) {
    return oldDelegate.ratio != ratio ||
        oldDelegate.isRtl != isRtl ||
        oldDelegate.isEn != isEn ||
        oldDelegate.primary != primary ||
        oldDelegate.isDark != isDark;
  }
}

class _PresetPill extends StatelessWidget {
  const _PresetPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? c.primary : c.border,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: selected ? c.textOnPrimary : c.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Modern 2-column ambient soundscape selector with animated sound bars & no volume slider.
class FocusSoundscapeSection extends StatelessWidget {
  const FocusSoundscapeSection({
    super.key,
    required this.selected,
    required this.isEn,
    required this.onSelect,
  });

  final AmbientSoundscape selected;
  final bool isEn;
  final ValueChanged<AmbientSoundscape> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final hasActiveSound = selected != AmbientSoundscape.silent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isEn ? 'Calm Focus Soundscapes' : 'أصوات هادئة للتركيز',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (hasActiveSound) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AnimatedSoundBars(color: c.primary),
                      const SizedBox(width: 5),
                      Text(
                        isEn ? 'Playing' : 'يعمل الآن',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: c.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final itemWidth = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final sc in AmbientSoundscape.values)
                    SizedBox(
                      width: itemWidth,
                      child: _SoundscapeCard(
                        sound: sc,
                        selected: selected == sc,
                        isEn: isEn,
                        onTap: () => onSelect(sc),
                      ),
                    ),
                ],
              );
            },
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: hasActiveSound
                ? Padding(
                    key: ValueKey<AmbientSoundscape>(selected),
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: c.primarySoft.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isEn ? selected.subtitleEn : selected.subtitleAr,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: c.primaryStrong,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SoundscapeCard extends StatelessWidget {
  const _SoundscapeCard({
    required this.sound,
    required this.selected,
    required this.isEn,
    required this.onTap,
  });

  final AmbientSoundscape sound;
  final bool selected;
  final bool isEn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final accent = _tintForSound(sound, c);
    final icon = _iconForSound(sound);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.14)
                : c.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : c.border,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? accent
                      : accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? (ThemeData.estimateBrightnessForColor(accent) ==
                              Brightness.light
                          ? const Color(0xFF0A241F)
                          : Colors.white)
                      : accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEn ? sound.labelEn : sound.labelAr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (selected && sound != AmbientSoundscape.silent) ...[
                const SizedBox(width: 4),
                _AnimatedSoundBars(color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForSound(AmbientSoundscape sc) => switch (sc) {
        AmbientSoundscape.silent => Icons.volume_off_rounded,
        AmbientSoundscape.ocean => Icons.waves_rounded,
        AmbientSoundscape.night => Icons.nights_stay_rounded,
        AmbientSoundscape.rain => Icons.grain_rounded,
        AmbientSoundscape.forest => Icons.park_rounded,
        AmbientSoundscape.warmNoise => Icons.graphic_eq_rounded,
      };

  Color _tintForSound(AmbientSoundscape sc, AppThemeExtension c) =>
      switch (sc) {
        AmbientSoundscape.silent => c.textSecondary,
        AmbientSoundscape.ocean => c.primary,
        AmbientSoundscape.night => c.secondary,
        AmbientSoundscape.rain => c.info,
        AmbientSoundscape.forest => c.success,
        AmbientSoundscape.warmNoise => c.accent,
      };
}

class _AnimatedSoundBars extends StatefulWidget {
  const _AnimatedSoundBars({required this.color});

  final Color color;

  @override
  State<_AnimatedSoundBars> createState() => _AnimatedSoundBarsState();
}

class _AnimatedSoundBarsState extends State<_AnimatedSoundBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final v = _controller.value;
        final heights = [
          5.0 + 7.0 * ((v + 0.1) % 1.0),
          6.0 + 8.0 * (1.0 - v),
          4.0 + 8.0 * ((v + 0.5) % 1.0),
        ];
        return SizedBox(
          width: 14,
          height: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final h in heights)
                Container(
                  width: 3,
                  height: h,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
