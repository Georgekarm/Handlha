import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';

class HandelhaFocusSessionScreen extends StatefulWidget {
  final String taskTitle;
  final String projectTitle;

  const HandelhaFocusSessionScreen({
    super.key,
    required this.taskTitle,
    this.projectTitle = 'إطلاق نسخة هندلها',
  });

  @override
  State<HandelhaFocusSessionScreen> createState() => _HandelhaFocusSessionScreenState();
}

class _HandelhaFocusSessionScreenState extends State<HandelhaFocusSessionScreen> {
  static const int _totalDuration = 25 * 60; // 25 minutes
  int _secondsLeft = 15 * 60; // starting at 15:00 as shown on Page 29
  Timer? _timer;
  bool _isPaused = false;
  bool _isFinished = false;
  bool _showPauseDialog = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isPaused || _isFinished) return;
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        setState(() => _isFinished = true);
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    // Progress calculation (15:00 left of 25:00 is 10/25 elapsed = 40% progress)
    final progress = (_totalDuration - _secondsLeft) / _totalDuration;
    final elapsedMinutes = (_totalDuration - _secondsLeft) ~/ 60;
    final remainingMinutes = (_secondsLeft / 60).ceil();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_outlined,
                      color: textSecColor,
                    ),
                    onPressed: () => setState(() => _isMuted = !_isMuted),
                  ),
                  Column(
                    children: [
                      Text(
                        _isFinished ? 'خطوة واتعملت' : 'مساحة تركيزك',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.projectTitle,
                        style: TextStyle(fontSize: 12, color: textSecColor),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded, color: textSecColor, size: 26),
                    onPressed: () => setState(() => _showPauseDialog = true),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Task Title
              Text(
                widget.taskTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const Spacer(),

              // Circular Countdown Timer Ring
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Ring
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(
                        value: _isFinished ? 1.0 : progress,
                        strokeWidth: 4.5,
                        backgroundColor: isDark ? AppColors.darkDivider : AppColors.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isFinished ? '00:00' : _formatTime(_secondsLeft),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isFinished
                              ? '٢٥ دقيقة تركيز اكتملت'
                              : (_isPaused
                                  ? 'متوقف مؤقتًا • $remainingMinutes دقيقة باقية'
                                  : 'باقي $remainingMinutes دقيقة من ٢٥'),
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Middle Note: "مش مطلوب منك غير الخطوة اللي قدامك."
              if (!_isFinished && !_showPauseDialog) ...[
                Text(
                  'مش مطلوب منك غير الخطوة اللي قدامك.',
                  style: TextStyle(fontSize: 14, color: textSecColor),
                ),
                const SizedBox(height: 24),
              ],

              // State 1: Finished Session (Page 30)
              if (_isFinished) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: primaryColor, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'كويس إنك خصصت وقت للخطوة دي. الجلسة خلصت. المهمة لسه مفتوحة لحد ما تأكد إنك خلصتها.',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 12.5, color: textSecColor, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('المهمة خلصت • علّمها مكتملة ✓', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isFinished = false;
                      _secondsLeft = 5 * 60;
                    });
                  },
                  icon: const Icon(Icons.coffee_outlined, size: 18),
                  label: const Text('راحة ٥ دقائق'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: borderColor),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text('لسه محتاجة وقت؟ ارجع للمهمة', style: TextStyle(color: textSecColor, fontSize: 13)),
                ),
              ]
              // State 2: Pause Confirmation Card (Page 31)
              else if (_showPauseDialog) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'نقف هنا دلوقتي؟',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'خلصت $elapsedMinutes دقائق. تقدر تنهي الجلسة من غير ما تعلّم المهمة كمكتملة، أو ترجع تكمل.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: textSecColor, height: 1.45),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showPauseDialog = false;
                            _isPaused = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('أرجع أكمّل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white)),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: borderColor),
                        ),
                        child: const Text('إنهاء الجلسة والخروج', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ]
              // State 3: Active Running Session (Page 29)
              else ...[
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isPaused = !_isPaused);
                  },
                  icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 20),
                  label: Text(_isPaused ? 'استئناف' : 'إيقاف مؤقت', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _showPauseDialog = true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: borderColor),
                        ),
                        child: const Text('أنهي الجلسة', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _secondsLeft = 5 * 60;
                            _isPaused = false;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: borderColor),
                        ),
                        child: const Text('راحة قصيرة', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'التقدم: $elapsedMinutes من ٢٥ دقيقة • المهمة لسه مفتوحة',
                  style: TextStyle(fontSize: 12, color: textMutedColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
