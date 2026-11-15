import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/audio/handelha_sound_engine.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/handelha_brand.dart';

/// Modern Handelha-branded dark emerald alarm screen used for non-Android
/// targets, notification previews, and widget test environments.
/// On real Android devices, ringing alarms launch [AlarmActivity] externally.
class HandelhaAlarmRingingDialog extends StatefulWidget {
  const HandelhaAlarmRingingDialog({
    super.key,
    required this.title,
    this.taskId,
    this.scheduledTimeLabel,
    this.isNotificationMode = false,
    this.onSnoozeMinutes,
    this.onDismissed,
  });

  final String title;
  final String? taskId;
  final String? scheduledTimeLabel;
  final bool isNotificationMode;
  final FutureOr<void> Function(int minutes)? onSnoozeMinutes;
  final FutureOr<void> Function()? onDismissed;

  static bool _isShowing = false;
  static bool get isShowing => _isShowing;

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? taskId,
    String? scheduledTimeLabel,
    bool isNotificationMode = false,
    FutureOr<void> Function(int minutes)? onSnoozeMinutes,
    FutureOr<void> Function()? onDismissed,
  }) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'HandelhaAlarm',
        barrierColor: const Color(0xFF091C17),
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (dialogCtx, _, _) => HandelhaAlarmRingingDialog(
          title: title,
          taskId: taskId,
          scheduledTimeLabel: scheduledTimeLabel,
          isNotificationMode: isNotificationMode,
          onSnoozeMinutes: onSnoozeMinutes,
          onDismissed: onDismissed,
        ),
        transitionBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      );
    } finally {
      _isShowing = false;
      HandelhaSoundEngine.instance.stopAlarmChime();
    }
  }

  @override
  State<HandelhaAlarmRingingDialog> createState() =>
      _HandelhaAlarmRingingDialogState();
}

class _HandelhaAlarmRingingDialogState extends State<HandelhaAlarmRingingDialog>
    with SingleTickerProviderStateMixin {
  static const Color _bgTop = Color(0xFF091C17);
  static const Color _bgMid = Color(0xFF0E2922);
  static const Color _bgBottom = Color(0xFF071612);
  static const Color _cardBg = Color(0xEB132D26);
  static const Color _cardBorder = Color(0xFF235246);
  static const Color _limeAccent = Color(0xFFC8F383);
  static const Color _limeInk = Color(0xFF0C211C);
  static const Color _mintBright = Color(0xFF6CD6C6);
  static const Color _coralDot = Color(0xFFE2856E);

  late final AnimationController _dialController;
  Timer? _clockTimer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _dialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    )..repeat();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
    HandelhaSoundEngine.instance.playAlarmChime(
      loop: !widget.isNotificationMode,
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _dialController.dispose();
    HandelhaSoundEngine.instance.stopAlarmChime();
    super.dispose();
  }

  Future<void> _dismiss() async {
    HandelhaSoundEngine.instance.stopAlarmChime();
    await widget.onDismissed?.call();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _snooze(int minutes) async {
    HandelhaSoundEngine.instance.stopAlarmChime();
    await widget.onSnoozeMinutes?.call(minutes);
    if (!mounted) return;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          isEn
              ? 'Snoozed for $minutes minutes'
              : 'تم تأجيل المنبه ${ArabicFormatters.toArabicDigits(minutes)} دقائق',
        ),
      ),
    );
  }

  Future<void> _startFocus() async {
    HandelhaSoundEngine.instance.stopAlarmChime();
    await widget.onDismissed?.call();
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    Navigator.of(context, rootNavigator: true).pop();
    router?.push(
      '/focus-session',
      extra: <String, dynamic>{
        'title': widget.title,
        if (widget.taskId != null) 'id': widget.taskId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final cleanTitle = ArabicFormatters.trData(widget.title);

    final hour12 = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final minStr = _now.minute.toString().padLeft(2, '0');
    final rawTime = '$hour12:$minStr';
    final displayTime = isEn ? rawTime : ArabicFormatters.toArabicDigits(rawTime);
    final period = _now.hour >= 12
        ? (isEn ? 'PM' : 'م')
        : (isEn ? 'AM' : 'ص');
    final dateLabel = isEn
        ? '${ArabicFormatters.weekdayShort(_now)}, ${ArabicFormatters.dateShort(_now)}'
        : '${ArabicFormatters.weekdayShort(_now)}، ${ArabicFormatters.dateShort(_now)}';

    final eyebrow = widget.isNotificationMode
        ? (isEn ? 'Handelha  •  Reminder' : 'هندلها  •  تذكير مهمة')
        : (isEn ? 'Handelha  •  Scheduled Alarm' : 'هندلها  •  منبه المواعيد');

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.48, 1.0],
            colors: [_bgTop, _bgMid, _bgBottom],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _AlarmAmbientBackdropPainter()),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final shortestSide = math.min(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final dialSize = math.min(236.0, shortestSide * 0.56);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(0, constraints.maxHeight - 38),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xE613312A),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFF245549),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE4F3EF),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: const HandelhaMark(
                                        size: 18,
                                        dark: false,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      eyebrow,
                                      style: TextStyle(
                                        fontFamily: AppTextStyles.fontFamily,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: isEn ? 0.3 : 0.0,
                                        color: const Color(0xFFE6F4F0),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: _limeAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            Center(
                              child: SizedBox(
                                width: dialSize,
                                height: dialSize,
                                child: AnimatedBuilder(
                                  animation: _dialController,
                                  builder: (context, child) => CustomPaint(
                                    painter: _HandelhaAlarmDialPainter(
                                      progress: _dialController.value,
                                    ),
                                    child: child,
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              widget.isNotificationMode
                                                  ? (isEn
                                                      ? 'REMINDER'
                                                      : 'تذكير الآن')
                                                  : (isEn
                                                      ? 'ALARM ACTIVE'
                                                      : 'حان الموعد'),
                                              style: TextStyle(
                                                fontFamily:
                                                    AppTextStyles.fontFamily,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: isEn ? 0.9 : 0.0,
                                                color: _mintBright,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Directionality(
                                              textDirection: TextDirection.ltr,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    displayTime,
                                                    style: TextStyle(
                                                      fontFamily: AppTextStyles
                                                          .fontFamily,
                                                      fontSize: 52,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: const Color(
                                                        0xFFF5FAF8,
                                                      ),
                                                      height: 1.0,
                                                      fontFeatures: const [
                                                        FontFeature
                                                            .tabularFigures(),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 7),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      bottom: 7,
                                                    ),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF1D483D,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(999),
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFF2B6858,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        period,
                                                        style: TextStyle(
                                                          fontFamily:
                                                              AppTextStyles
                                                                  .fontFamily,
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: _limeAccent,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              dateLabel,
                                              style: TextStyle(
                                                fontFamily:
                                                    AppTextStyles.fontFamily,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF9EC2B7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                18,
                                20,
                                18,
                              ),
                              decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: _cardBorder,
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1B3E35),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6.5,
                                          height: 6.5,
                                          decoration: const BoxDecoration(
                                            color: _coralDot,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isEn
                                              ? 'Scheduled Task'
                                              : 'مهمة مجدولة',
                                          style: TextStyle(
                                            fontFamily:
                                                AppTextStyles.fontFamily,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFD7ECE6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    cleanTitle,
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppTextStyles.fontFamily,
                                      fontSize: 21.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.isNotificationMode
                                        ? (isEn
                                            ? 'Gentle reminder for your planned step'
                                            : 'تذكير هادئ بميعاد خطوتك')
                                        : (isEn
                                            ? 'It is time for your scheduled task'
                                            : 'جه ميعاد مهمتك دلوقتي'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppTextStyles.fontFamily,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF9EBDB4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 58,
                              child: ElevatedButton.icon(
                                onPressed: _dismiss,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _limeAccent,
                                  foregroundColor: _limeInk,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                icon: Icon(
                                  widget.isNotificationMode
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.alarm_off_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  isEn ? 'Dismiss Alarm' : 'إيقاف المنبه',
                                  style: TextStyle(
                                    fontFamily: AppTextStyles.fontFamily,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _EmeraldGlassPill(
                                    label: isEn ? 'Snooze 5 min' : 'غفوة ٥ د',
                                    onTap: () => _snooze(5),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _EmeraldGlassPill(
                                    label: isEn ? 'Snooze 10 min' : 'غفوة ١٠ د',
                                    onTap: () => _snooze(10),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _startFocus,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFF102B24),
                                  foregroundColor: _mintBright,
                                  side: const BorderSide(
                                    color: Color(0xFF255E50),
                                    width: 1.1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.play_circle_outline_rounded,
                                  size: 19,
                                ),
                                label: Text(
                                  isEn
                                      ? 'Open Task & Start Focus Now'
                                      : 'فتح المهمة وبدء التركيز الآن',
                                  style: TextStyle(
                                    fontFamily: AppTextStyles.fontFamily,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmeraldGlassPill extends StatelessWidget {
  const _EmeraldGlassPill({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF143029),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF26574A),
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE8F5F1),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlarmAmbientBackdropPainter extends CustomPainter {
  const _AlarmAmbientBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final topRightCenter = Offset(size.width * 0.92, size.height * 0.08);
    final topRightR = size.width * 0.85;
    canvas.drawCircle(
      topRightCenter,
      topRightR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.37),
            AppColors.darkPrimary.withValues(alpha: 0.15),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(
          Rect.fromCircle(center: topRightCenter, radius: topRightR),
        ),
    );

    final bottomLeftCenter = Offset(size.width * 0.06, size.height * 0.90);
    final bottomLeftR = size.width * 0.82;
    canvas.drawCircle(
      bottomLeftCenter,
      bottomLeftR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF272644).withValues(alpha: 0.35),
            AppColors.secondary.withValues(alpha: 0.13),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(
          Rect.fromCircle(center: bottomLeftCenter, radius: bottomLeftR),
        ),
    );

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.darkPrimary.withValues(alpha: 0.10);
    const startX = 22.0;
    const startY = 84.0;
    const step = 12.0;
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 5; col++) {
        canvas.drawCircle(
          Offset(startX + col * step, startY + row * step),
          1.3,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AlarmAmbientBackdropPainter oldDelegate) =>
      false;
}

class _HandelhaAlarmDialPainter extends CustomPainter {
  const _HandelhaAlarmDialPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(size.width, size.height) / 2 - 8;
    final discR = outerR - 6;
    final ringR = outerR - 4;
    final breath = (-math.cos(progress * math.pi * 4) * 0.5) + 0.5;

    final auraR = outerR + 4 + breath * 7;
    canvas.drawCircle(
      center,
      auraR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.darkPrimary.withValues(alpha: 0.14 + breath * 0.07),
            const Color(0xFFC8F383).withValues(alpha: 0.04 + breath * 0.03),
            Colors.transparent,
          ],
          stops: const [0.45, 0.78, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: auraR)),
    );

    canvas.drawCircle(
      center,
      discR,
      Paint()..color = const Color(0xE8102822),
    );
    canvas.drawCircle(
      center,
      discR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = const Color(0xFF245649),
    );

    final tickOuter = discR - 9;
    final majorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6
      ..color = AppColors.darkPrimary.withValues(alpha: 0.47);
    final minorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0
      ..color = const Color(0x48265649);

    for (var i = 0; i < 60; i++) {
      final isMajor = i % 5 == 0;
      final angle = -math.pi / 2 + (i / 60) * 2 * math.pi;
      final len = isMajor ? 5.5 : 2.8;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      canvas.drawLine(
        Offset(center.dx + cosA * tickOuter, center.dy + sinA * tickOuter),
        Offset(
          center.dx + cosA * (tickOuter - len),
          center.dy + sinA * (tickOuter - len),
        ),
        isMajor ? majorPaint : minorPaint,
      );
    }

    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..color = AppColors.darkPrimary.withValues(alpha: 0.18),
    );

    final arcRect = Rect.fromCircle(center: center, radius: ringR);
    final startAngle = -math.pi / 2 + progress * 2 * math.pi;
    const sweepAngle = 135 * math.pi / 180;
    const sweepRatio = 135 / 360;

    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          AppColors.darkPrimary.withValues(alpha: 0.18),
          AppColors.darkPrimary,
          const Color(0xFFC8F383),
          AppColors.darkPrimary.withValues(alpha: 0.18),
        ],
        stops: const [0.0, 0.24, sweepRatio, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);

    final tipAngle = startAngle + sweepAngle;
    final tipPos = Offset(
      center.dx + math.cos(tipAngle) * ringR,
      center.dy + math.sin(tipAngle) * ringR,
    );
    canvas.drawCircle(
      tipPos,
      6.5 + breath * 2.0,
      Paint()..color = const Color(0x78C8F383),
    );
    canvas.drawCircle(
      tipPos,
      3.6,
      Paint()..color = const Color(0xFFC8F383),
    );
  }

  @override
  bool shouldRepaint(covariant _HandelhaAlarmDialPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
