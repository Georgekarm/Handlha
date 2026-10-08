import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/handelha_brand.dart';

class HandelhaFocusSessionScreen extends StatefulWidget {
  const HandelhaFocusSessionScreen({super.key, required this.taskTitle});
  final String taskTitle;

  @override
  State<HandelhaFocusSessionScreen> createState() => _HandelhaFocusSessionScreenState();
}

class _HandelhaFocusSessionScreenState extends State<HandelhaFocusSessionScreen> {
  static const int _sessionLength = 25 * 60;
  Timer? _timer;
  int _secondsLeft = _sessionLength;
  bool _isRunning = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRunning || _secondsLeft <= 0) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft == 0) _showFinished();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _showFinished() async {
    _timer?.cancel();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.celebration_rounded, color: AppColors.primary, size: 34),
        title: const Text('خلصت جلستك!'),
        content: const Text('خطوة مهمة اتعملت. خد نفس واحتفل باللي أنجزته.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('تمام'))],
      ),
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    final progress = 1 - (_secondsLeft / _sessionLength);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(tooltip: 'إغلاق', onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded)),
        title: const Text('جلسة تركيز', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 34),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      const HandelhaLogo(markSize: 42, fontSize: 26),
                      const SizedBox(height: 32),
                      Text(widget.taskTitle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primaryStrong)),
                      const SizedBox(height: 8),
                      const Text('خطوة واحدة، من غير استعجال.', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: 286,
                        height: 286,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: 1,
                                strokeWidth: 9,
                                color: AppColors.primarySoft,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 9,
                                strokeCap: StrokeCap.round,
                                color: AppColors.accent,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$minutes:$seconds', style: const TextStyle(fontSize: 62, fontWeight: FontWeight.w800, color: AppColors.primaryStrong, letterSpacing: 1)),
                                const Text('٢٥ دقيقة', style: TextStyle(fontSize: 17, color: AppColors.textSecondary)),
                                const SizedBox(height: 14),
                                const HandelhaMark(size: 42),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      SizedBox(
                        width: 250,
                        height: 58,
                        child: FilledButton.icon(
                          onPressed: () => setState(() => _isRunning = !_isRunning),
                          icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 22),
                          label: Text(_isRunning ? 'إيقاف مؤقت' : 'استئناف'),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryStrong, foregroundColor: Colors.white, shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(onPressed: () => context.pop(), child: const Text('إنهاء الجلسة', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w600))),
                      const SizedBox(height: 18),
                      const Divider(indent: 100, endIndent: 100),
                      const SizedBox(height: 10),
                      const Text('أول ما تخلص، هنحفظ وقتك.', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
