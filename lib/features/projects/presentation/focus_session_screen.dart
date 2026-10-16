import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_theme_extension.dart';

class FocusSessionScreen extends StatefulWidget {
  final String taskTitle;

  const FocusSessionScreen({
    super.key,
    required this.taskTitle,
  });

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> {
  Timer? _timer;
  int _secondsLeft = 25 * 60; // 25 دقيقة تركيز
  bool _isRunning = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_isRunning && _secondsLeft > 0) {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;

    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: ext.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: ext.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ext.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.timer_rounded,
                  color: ext.accent,
                  size: 64,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'جلسة تركيز هادئة',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ext.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.taskTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: ext.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Text(
                '$minutes:$seconds',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: ext.accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  fontSize: 72,
                ),
              ),
              const SizedBox(height: 64),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.stop_rounded, size: 20),
                    label: const Text('إنهاء الجلسة'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isRunning = !_isRunning),
                    icon: Icon(
                      _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 20,
                    ),
                    label: Text(_isRunning ? 'إيقاف مؤقت' : 'استئناف'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ext.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
