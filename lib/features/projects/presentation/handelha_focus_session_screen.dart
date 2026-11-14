import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_extension.dart';
import '../../../core/audio/handelha_sound_engine.dart';
import '../../../core/database/local_focus_session_database.dart';
import '../../../core/result/result.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../../shared/widgets/handelha_bottom_nav.dart';
import '../../../shared/widgets/handelha_feedback.dart';
import '../../../shared/widgets/handelha_header.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_providers.dart';
import '../domain/focus_session.dart';
import 'project_providers.dart';

enum _FocusPhase { active, paused, completed, onBreak }

enum _FocusViewTab { timer, progress }

/// شاشة جلسة التركيز المطورة:
/// - تعديل مرن للوقت والمدة (١٠ / ١٥ / ٢٥ / ٤٥ / ٦٠ / ٩٠ / ١٢٠ دقيقة + مؤشر مخصص)
/// - أصوات طبيعة هادئة للتركيز (أمواج البحر، هدوء الليل، مطر هادئ، نسيم الغابة، ضوضاء دافئة)
/// - صفحة متابعة وإنجاز خاصة بجلسات التركيز مربوطة ومسمّعة في كل شاشات البرنامج
class HandelhaFocusSessionScreen extends ConsumerStatefulWidget {
  final String taskTitle;
  final String? taskId;
  final int initialMinutes;

  const HandelhaFocusSessionScreen({
    super.key,
    required this.taskTitle,
    this.taskId,
    this.initialMinutes = 25,
  });

  @override
  ConsumerState<HandelhaFocusSessionScreen> createState() =>
      _HandelhaFocusSessionScreenState();
}

class _HandelhaFocusSessionScreenState
    extends ConsumerState<HandelhaFocusSessionScreen> {
  int _selectedFocusMinutes = 25;
  int _selectedBreakMinutes = 5;

  late int _focusSecondsTotal;
  late int _remainingSeconds;
  _FocusPhase _phase = _FocusPhase.active;
  _FocusViewTab _viewTab = _FocusViewTab.timer;
  Timer? _timer;
  DateTime? _startedAt;
  bool _sessionRecorded = false;
  int _lastCompletedMinutes = 25;

  AmbientSoundscape _ambient = AmbientSoundscape.silent;
  double _volume = 0.65;
  bool _usedAmbientSound = false;
  List<FocusSession> _history = const [];

  @override
  void initState() {
    super.initState();
    _selectedFocusMinutes = widget.initialMinutes;
    _focusSecondsTotal = _selectedFocusMinutes * 60;
    _remainingSeconds = _focusSecondsTotal;
    _startedAt = DateTime.now();
    _startTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFocusHistory());
  }

  @override
  void dispose() {
    _timer?.cancel();
    HandelhaSoundEngine.instance.stopAmbient();
    super.dispose();
  }

  Future<void> _loadFocusHistory() async {
    final userId = ref.read(authNotifierProvider).value?.id;
    if (userId == null) return;
    final res = await LocalFocusSessionDatabase.instance.forUser(userId);
    if (!mounted) return;
    if (res is Success<List<FocusSession>>) {
      setState(() {
        _history = res.data;
      });
    }
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_phase != _FocusPhase.active && _phase != _FocusPhase.onBreak) {
        return;
      }
      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        if (_phase == _FocusPhase.active) {
          _completeFocusSession(completed: true);
        } else {
          _exitScreen();
        }
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  void _setDurationPreset(int minutes) {
    setState(() {
      _selectedFocusMinutes = minutes;
      _focusSecondsTotal = minutes * 60;
      _remainingSeconds = _focusSecondsTotal;
      _sessionRecorded = false;
    });
  }

  void _adjustRemainingMinutes(int deltaMinutes) {
    final deltaSec = deltaMinutes * 60;
    setState(() {
      final nextRem = (_remainingSeconds + deltaSec).clamp(60, 180 * 60);
      _remainingSeconds = nextRem;
      if (_remainingSeconds > _focusSecondsTotal) {
        _focusSecondsTotal = _remainingSeconds;
      }
      _selectedFocusMinutes = (_focusSecondsTotal / 60).round();
    });
  }

  void _selectAmbient(AmbientSoundscape sound) {
    setState(() {
      _ambient = sound;
      if (sound != AmbientSoundscape.silent) {
        _usedAmbientSound = true;
      }
    });
    HandelhaSoundEngine.instance.playAmbient(sound, volume: _volume);
  }

  void _pause() {
    if (_phase != _FocusPhase.active) return;
    _timer?.cancel();
    setState(() => _phase = _FocusPhase.paused);
  }

  void _resume() {
    if (_phase != _FocusPhase.paused) return;
    setState(() => _phase = _FocusPhase.active);
    _startTicker();
  }

  Future<void> _recordSessionOnce({required bool completed}) async {
    if (_sessionRecorded) return;
    _sessionRecorded = true;
    final userId = ref.read(authNotifierProvider).value?.id;
    if (userId == null) return;

    final elapsedSec =
        (_focusSecondsTotal - _remainingSeconds).clamp(0, _focusSecondsTotal);
    final elapsedMin = completed
        ? _selectedFocusMinutes
        : (elapsedSec / 60).round().clamp(1, _selectedFocusMinutes);
    _lastCompletedMinutes =
        elapsedMin > 0 ? elapsedMin : _selectedFocusMinutes;

    await ref.read(focusSessionsProvider.notifier).recordSession(
      taskId: widget.taskId,
      taskTitle: widget.taskTitle,
      startedAt: _startedAt ?? DateTime.now(),
      endedAt: DateTime.now(),
      elapsedMinutes: _lastCompletedMinutes,
      completed: completed,
    );

    // Accumulate focus time onto the linked task if present.
    if (widget.taskId != null) {
      final allTasks = ref.read(allTasksProvider).value ?? const <Task>[];
      final linked = allTasks.where((t) => t.id == widget.taskId).firstOrNull;
      if (linked != null) {
        final nextActual =
            (linked.actualDurationMinutes ?? 0) + _lastCompletedMinutes;
        await ref.read(allTasksProvider.notifier).updateTask(
              linked.copyWith(actualDurationMinutes: nextActual),
            );
      }
    }

    // Sync across all app screens (Dashboard, Tasks, Projects, Tracking)
    ref.invalidate(todayTasksProvider);
    ref.invalidate(allTasksProvider);
    ref.invalidate(projectsProvider);
    ref.invalidate(focusSessionsProvider);
    await _loadFocusHistory();
  }

  Future<void> _completeFocusSession({required bool completed}) async {
    _timer?.cancel();
    HandelhaSoundEngine.instance.stopAmbient();
    await _recordSessionOnce(completed: completed);
    if (!mounted) return;
    setState(() {
      _remainingSeconds = 0;
      _phase = _FocusPhase.completed;
    });
  }

  Future<void> _endSessionManually() async {
    _timer?.cancel();
    HandelhaSoundEngine.instance.stopAmbient();
    await _recordSessionOnce(completed: true);
    if (!mounted) return;
    setState(() {
      _phase = _FocusPhase.completed;
    });
  }

  void _startBreak([int? customBreakMinutes]) {
    _timer?.cancel();
    if (customBreakMinutes != null) {
      _selectedBreakMinutes = customBreakMinutes;
    }
    setState(() {
      _phase = _FocusPhase.onBreak;
      _remainingSeconds = _selectedBreakMinutes * 60;
      _viewTab = _FocusViewTab.timer;
    });
    _startTicker();
  }

  void _restartFocusFromBreak() {
    _timer?.cancel();
    setState(() {
      _phase = _FocusPhase.active;
      _remainingSeconds = _focusSecondsTotal;
      _startedAt = DateTime.now();
      _sessionRecorded = false;
    });
    _startTicker();
  }

  void _exitScreen() {
    _timer?.cancel();
    HandelhaSoundEngine.instance.stopAmbient();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/home');
      }
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<bool> _confirmExitIfRunning() async {
    if (_phase == _FocusPhase.completed) return true;
    if (_phase == _FocusPhase.onBreak) return true;
    final elapsed = _focusSecondsTotal - _remainingSeconds;
    if (elapsed < 5) return true;

    final isEn = Directionality.of(context) == TextDirection.ltr;
    final shouldLeave = await HandelhaDialog.confirm(
      context,
      icon: Icons.timer_off_outlined,
      title: isEn ? 'End Focus Session?' : 'إنهاء جلسة التركيز؟',
      message: isEn
          ? 'Your session is still running. Leave and come back later?'
          : 'الجلسة لسه شغالة. تحب تخرج وترجع لاحقًا؟',
      confirmLabel: isEn ? 'Leave' : 'خروج',
      cancelLabel: isEn ? 'Keep Focusing' : 'كمّل تركيز',
    );
    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final user = ref.watch(authNotifierProvider).value;
    final cleanTitle = ArabicFormatters.trData(widget.taskTitle);
    final breakSecondsTotal = _selectedBreakMinutes * 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final allow = await _confirmExitIfRunning();
        if (allow && mounted) {
          _exitScreen();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: HandelhaAmbientBackground(
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 114),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_phase == _FocusPhase.completed)
                    _buildCompletedView(
                      context,
                      c: c,
                      firstName: ArabicFormatters.trData(
                        user?.firstName ?? (isEn ? 'Friend' : 'صديقي'),
                      ),
                    )
                  else ...[
                    switch (_phase) {
                      _FocusPhase.active => _buildTimerView(
                          context,
                          c: c,
                          isEn: isEn,
                          headerTitle:
                              isEn ? 'Focus Session' : 'جلسة التركيز',
                          headline: isEn
                              ? 'One thing. Your full focus on it.'
                              : 'حاجة واحدة. تركيزك كله ليها.',
                          badgeText: cleanTitle,
                          badgeFill: c.surface,
                          badgeTextColor: c.textSecondary,
                          ringColor: c.primary,
                          timerSub: isEn
                              ? 'minutes for you and your task'
                              : 'دقيقة لنفسك ولمهمتك',
                          caption: isEn
                              ? 'Turn off distractions, and leave the rest to us.'
                              : 'اقفل المشتتات، وسيب الباقي علينا.',
                          primaryLabel: isEn ? 'Pause' : 'إيقاف مؤقت',
                          onPrimary: _pause,
                          secondaryLabel:
                              isEn ? 'End Session' : 'إنهاء الجلسة',
                          onSecondary: _endSessionManually,
                          progress: _focusSecondsTotal == 0
                              ? 1
                              : _remainingSeconds / _focusSecondsTotal,
                        ),
                      _FocusPhase.paused => _buildTimerView(
                          context,
                          c: c,
                          isEn: isEn,
                          headerTitle:
                              isEn ? 'Focus Paused' : 'التركيز متوقف',
                          headline: isEn
                              ? 'Take your time, no rush.'
                              : 'خد وقتك، مفيش استعجال.',
                          badgeText: cleanTitle,
                          badgeFill: c.surface,
                          badgeTextColor: c.textSecondary,
                          ringColor: c.lavenderAccent,
                          timerSub: isEn
                              ? 'minutes for you and your task'
                              : 'دقيقة لنفسك ولمهمتك',
                          caption: isEn
                              ? 'Your progress is saved. Resume whenever you are ready.'
                              : 'كل اللي عملته محفوظ. نكمّل لما تحب.',
                          primaryLabel:
                              isEn ? 'Resume Session' : 'كمّل الجلسة',
                          onPrimary: _resume,
                          secondaryLabel:
                              isEn ? 'End Session' : 'إنهاء الجلسة',
                          onSecondary: _endSessionManually,
                          progress: _focusSecondsTotal == 0
                              ? 1
                              : _remainingSeconds / _focusSecondsTotal,
                        ),
                      _FocusPhase.onBreak => _buildTimerView(
                          context,
                          c: c,
                          isEn: isEn,
                          headerTitle: isEn ? 'Break Time' : 'وقت الاستراحة',
                          headline: isEn
                              ? 'A short break makes a big difference.'
                              : 'استراحة صغيرة، تفرق كتير.',
                          badgeText:
                              isEn ? 'Time for yourself' : 'وقت لنفسك',
                          badgeFill: c.primarySoft,
                          badgeTextColor: c.primary,
                          ringColor: c.primary,
                          timerSub: isEn
                              ? 'Drink water and take a breath'
                              : 'اشرب ميّه وخد نفس',
                          caption: isEn
                              ? 'Stretch your back, work can wait.'
                              : 'قوم افرد ضهرك، الشغل هيستناك.',
                          primaryLabel:
                              isEn ? 'Back to Focus' : 'رجوع للتركيز',
                          onPrimary: _restartFocusFromBreak,
                          secondaryLabel:
                              isEn ? 'End Break' : 'إنهاء الاستراحة',
                          onSecondary: _exitScreen,
                          progress: breakSecondsTotal == 0
                              ? 1
                              : _remainingSeconds / breakSecondsTotal,
                        ),
                      _FocusPhase.completed => const SizedBox.shrink(),
                    },
                  ],
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: const HandelhaBottomNav(currentIndex: 0),
      ),
    );
  }

  Widget _buildTimerView(
    BuildContext context, {
    required AppThemeExtension c,
    required bool isEn,
    required String headerTitle,
    required String headline,
    required String badgeText,
    required Color badgeFill,
    required Color badgeTextColor,
    required Color ringColor,
    required String timerSub,
    required String caption,
    required String primaryLabel,
    required VoidCallback onPrimary,
    required String secondaryLabel,
    required VoidCallback onSecondary,
    required double progress,
  }) {
    return Column(
      children: [
        HandelhaHeader(
          title: headerTitle,
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
          onBack: () async {
            final allow = await _confirmExitIfRunning();
            if (allow && mounted) _exitScreen();
          },
        ),

        // View Tab Switcher: المؤقت والأصوات | متابعة وإنجاز التركيز
        (() {
          final syncedHistory =
              ref.watch(focusSessionsProvider).value ?? _history;
          return Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: c.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _FocusTabPill(
                  label: isEn ? 'Timer & Sounds' : 'المؤقت والأصوات',
                  selected: _viewTab == _FocusViewTab.timer,
                  onTap: () => setState(() => _viewTab = _FocusViewTab.timer),
                ),
              ),
              Expanded(
                child: _FocusTabPill(
                  label: isEn
                      ? 'Focus Progress (${syncedHistory.length})'
                      : 'إنجاز التركيز (${ArabicFormatters.toArabicDigits(syncedHistory.length)})',
                  selected: _viewTab == _FocusViewTab.progress,
                  onTap: () {
                    ref.read(focusSessionsProvider.notifier).refresh();
                    _loadFocusHistory();
                    setState(() => _viewTab = _FocusViewTab.progress);
                  },
                ),
              ),
            ],
          ),
        );
        })(),

        if (_viewTab == _FocusViewTab.progress) ...[
          _buildFocusProgressAndAchievementsView(context, c, isEn),
          const SizedBox(height: 16),
        ],

        Text(
          headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: badgeFill,
            borderRadius: BorderRadius.circular(999),
            border: badgeFill == c.surface ? Border.all(color: c.border) : null,
          ),
          child: Text(
            badgeText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: badgeTextColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 7.5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: ringColor.withValues(alpha: 0.16),
                  color: ringColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ArabicFormatters.toArabicDigits(
                          ArabicFormatters.timerMmSs(_remainingSeconds),
                        ),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: ringColor,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timerSub,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Time Adjustment & Duration Presets Card
        if (_phase != _FocusPhase.onBreak) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: c.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isEn
                            ? 'Customize Focus Duration & Break'
                            : 'تعديل وقت ومدة الجلسة والاستراحة',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      isEn
                          ? '$_selectedFocusMinutes min'
                          : '${ArabicFormatters.toArabicDigits(_selectedFocusMinutes)} د',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: c.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final mins in const [10, 15, 25, 45, 60, 90, 120])
                      _DurationChip(
                        label: isEn
                            ? '${mins}m'
                            : '${ArabicFormatters.toArabicDigits(mins)} د',
                        selected: _selectedFocusMinutes == mins,
                        onTap: () => _setDurationPreset(mins),
                      ),
                    _DurationChip(
                      label: isEn ? '-5m' : '-٥ د',
                      selected: false,
                      onTap: () => _adjustRemainingMinutes(-5),
                    ),
                    _DurationChip(
                      label: isEn ? '+5m' : '+٥ د',
                      selected: false,
                      onTap: () => _adjustRemainingMinutes(5),
                    ),
                    _DurationChip(
                      label: isEn ? '+10m' : '+١٠ د',
                      selected: false,
                      onTap: () => _adjustRemainingMinutes(10),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                  ),
                  child: Slider(
                    value: _selectedFocusMinutes.toDouble().clamp(5, 120),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    activeColor: c.primary,
                    label: isEn
                        ? '$_selectedFocusMinutes min'
                        : '${ArabicFormatters.toArabicDigits(_selectedFocusMinutes)} د',
                    onChanged: (v) => _setDurationPreset(v.round()),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      isEn ? 'Break:' : 'مدة الاستراحة:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final bMin in const [5, 10, 15])
                            _DurationChip(
                              label: isEn
                                  ? '${bMin}m'
                                  : '${ArabicFormatters.toArabicDigits(bMin)} د',
                              selected: _selectedBreakMinutes == bMin,
                              onTap: () =>
                                  setState(() => _selectedBreakMinutes = bMin),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ] else ...[
          // Break duration customization
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final bMin in const [5, 10, 15])
                _DurationChip(
                  label: isEn
                      ? 'Break ${bMin}m'
                      : 'استراحة ${ArabicFormatters.toArabicDigits(bMin)} د',
                  selected: _selectedBreakMinutes == bMin,
                  onTap: () => _startBreak(bMin),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Calm Ambient Soundscape Card (البحر، الليل، المطر، الغابة)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.waves_rounded, size: 17, color: c.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isEn
                          ? 'Calm Ambient Soundscapes'
                          : 'أصوات هادئة للتركيز (البحر والليل والمطر)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final sc in AmbientSoundscape.values)
                    _DurationChip(
                      icon: _soundscapeIcon(sc),
                      label: isEn ? sc.labelEn : sc.labelAr,
                      selected: _ambient == sc,
                      onTap: () => _selectAmbient(sc),
                    ),
                ],
              ),
              if (_ambient != AmbientSoundscape.silent) ...[
                const SizedBox(height: 8),
                Text(
                  isEn ? _ambient.subtitleEn : _ambient.subtitleAr,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.primary,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.volume_down_rounded,
                      size: 16,
                      color: c.textSecondary,
                    ),
                    Expanded(
                      child: Slider(
                        value: _volume,
                        min: 0.05,
                        max: 1.0,
                        activeColor: c.primary,
                        onChanged: (v) {
                          setState(() => _volume = v);
                          HandelhaSoundEngine.instance.setAmbientVolume(v);
                        },
                      ),
                    ),
                    Icon(
                      Icons.volume_up_rounded,
                      size: 16,
                      color: c.primary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        Text(
          caption,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: onPrimary,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.textOnPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              primaryLabel,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: c.textOnPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: onSecondary,
            style: FilledButton.styleFrom(
              backgroundColor: c.primarySoft,
              foregroundColor: c.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              secondaryLabel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFocusProgressAndAchievementsView(
    BuildContext context,
    AppThemeExtension c,
    bool isEn,
  ) {
    final sessions = ref.watch(focusSessionsProvider).value ?? _history;
    final totalMinutes =
        sessions.fold<int>(0, (sum, item) => sum + item.elapsedMinutes);
    final totalSessions = sessions.length;
    final todayNow = DateTime.now();
    final todayMinutes = sessions
        .where((s) =>
            s.endedAt.year == todayNow.year &&
            s.endedAt.month == todayNow.month &&
            s.endedAt.day == todayNow.day)
        .fold<int>(0, (sum, s) => sum + s.elapsedMinutes);
    const dailyGoalMinutes = 90;
    final goalProgress = (todayMinutes / dailyGoalMinutes).clamp(0.0, 1.0);

    final badges = <({String title, String sub, IconData icon, bool unlocked})>[
      (
        title: isEn ? 'Focus Diver' : 'بداية التركيز',
        sub: isEn ? 'Complete 1st focus session' : 'أول جلسة تركيز مكتملة',
        icon: Icons.waves_rounded,
        unlocked: totalSessions >= 1,
      ),
      (
        title: isEn ? 'Steady Momentum' : 'شعلة الانتباه',
        sub: isEn ? '3+ sessions or 75+ min' : '٣ جلسات أو ٧٥+ دقيقة تركيز',
        icon: Icons.local_fire_department_rounded,
        unlocked: totalSessions >= 3 || totalMinutes >= 75,
      ),
      (
        title: isEn ? 'Deep Focus Master' : 'سيد التركيز العميق',
        sub: isEn ? '150+ total focus minutes' : '١٥٠+ دقيقة تركيز إجمالية',
        icon: Icons.emoji_events_rounded,
        unlocked: totalMinutes >= 150,
      ),
      (
        title: isEn ? 'Calm Atmosphere' : 'هدوء وسكون',
        sub: isEn
            ? 'Focus with Ocean or Night sounds'
            : 'التركيز مع أصوات البحر أو الليل',
        icon: Icons.nights_stay_rounded,
        unlocked: _usedAmbientSound || _ambient != AmbientSoundscape.silent,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.insights_rounded, color: c.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEn
                      ? 'Focus Sessions Progress & Achievements'
                      : 'لوحة متابعة وإنجازات جلسات التركيز',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // KPI summary row
          Row(
            children: [
              Expanded(
                child: _FocusKpiBox(
                  label: isEn ? 'Total Focus' : 'إجمالي التركيز',
                  value: isEn
                      ? '$totalMinutes min'
                      : '${ArabicFormatters.toArabicDigits(totalMinutes)} د',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FocusKpiBox(
                  label: isEn ? 'Sessions Done' : 'الجلسات المكتملة',
                  value: isEn
                      ? '$totalSessions'
                      : ArabicFormatters.toArabicDigits(totalSessions),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FocusKpiBox(
                  label: isEn ? 'Today' : 'تركيز النهارده',
                  value: isEn
                      ? '$todayMinutes min'
                      : '${ArabicFormatters.toArabicDigits(todayMinutes)} د',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Daily focus goal progress bar
          Text(
            isEn
                ? 'Daily Focus Goal: $todayMinutes / $dailyGoalMinutes min'
                : 'هدف التركيز اليومي: ${ArabicFormatters.toArabicDigits(todayMinutes)} من ${ArabicFormatters.toArabicDigits(dailyGoalMinutes)} دقيقة',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: goalProgress,
              minHeight: 8,
              backgroundColor: c.surfaceSoft,
              color: c.primary,
            ),
          ),
          const SizedBox(height: 14),

          Text(
            isEn ? 'Focus Badges Unlocked' : 'أوسمة التركيز الخاصة بيك',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in badges)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: b.unlocked ? c.primarySoft : c.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: b.unlocked
                          ? c.primary.withValues(alpha: 0.45)
                          : c.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        b.unlocked ? b.icon : Icons.lock_outline_rounded,
                        size: 15,
                        color: b.unlocked ? c.primary : c.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${b.title} (${b.sub})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                b.unlocked ? c.textPrimary : c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (sessions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              isEn ? 'Recent Focus Sessions' : 'آخر جلسات التركيز المسجلة',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            for (final s in sessions.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: c.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ArabicFormatters.trData(s.taskTitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isEn
                            ? '${s.elapsedMinutes}m'
                            : '${ArabicFormatters.toArabicDigits(s.elapsedMinutes)} د',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: c.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => GoRouter.maybeOf(context)?.go('/tracking'),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.primary,
              side: BorderSide(color: c.primary.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.bar_chart_rounded, size: 17),
            label: Text(
              isEn
                  ? 'Open Full App Progress & Badges'
                  : 'فتح صفحة «إنجازك» والأوسمة الكاملة في البرنامج',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedView(
    BuildContext context, {
    required AppThemeExtension c,
    required String firstName,
  }) {
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final mins = _lastCompletedMinutes > 0
        ? _lastCompletedMinutes
        : _selectedFocusMinutes;
    final cleanTitle = ArabicFormatters.trData(widget.taskTitle);

    return Column(
      children: [
        HandelhaHeader(
          title: isEn ? 'Well Done' : 'أحسنت',
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          onBack: _exitScreen,
        ),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 46,
            color: c.primary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          isEn ? 'Way to go, $firstName!' : 'عاش يا $firstName!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: c.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isEn
              ? '${ArabicFormatters.durationMinutesFull(mins)} of focus. A real step forward.'
              : '${ArabicFormatters.durationMinutesFull(mins)} تركيز. خطوة حقيقية لقدّام.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isEn
              ? 'Every time you start, you win.\nTake a short break or continue with another step?'
              : 'كل مرة بتبدأ فيها، إنت بتكسب.\nنرتاح شوية ولا نكمّل خطوة كمان؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: c.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border),
          ),
          child: Text(
            '$cleanTitle • ${ArabicFormatters.durationMinutesFull(mins)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Embedded Focus Achievements & App-Wide Sync Summary
        _buildFocusProgressAndAchievementsView(context, c, isEn),
        const SizedBox(height: 12),

        if (widget.taskId != null) ...[
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref
                    .read(allTasksProvider.notifier)
                    .completeTask(widget.taskId!);
                ref.invalidate(todayTasksProvider);
                ref.invalidate(projectsProvider);
                if (!context.mounted) return;
                HandelhaFeedback.showCelebration(
                  context,
                  isEn
                      ? 'Task marked completed across the app!'
                      : 'تم تعليم المهمة كمكتملة وتحديث إنجازك في البرنامج!',
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primary,
                side: BorderSide(color: c.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.task_alt_rounded, size: 18),
              label: Text(
                isEn
                    ? 'Mark Task Completed in Schedule'
                    : 'علّم المهمة كمكتملة في جدولك',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _startBreak,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.textOnPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              isEn ? 'Take a Break' : 'خد استراحة',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: c.textOnPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _exitScreen,
          child: Text(
            isEn ? 'Back to Home' : 'ارجع للرئيسية',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: c.primary,
            ),
          ),
        ),
      ],
    );
  }
  IconData _soundscapeIcon(AmbientSoundscape sc) => switch (sc) {
        AmbientSoundscape.silent => Icons.volume_off_rounded,
        AmbientSoundscape.ocean => Icons.waves_rounded,
        AmbientSoundscape.night => Icons.nights_stay_rounded,
        AmbientSoundscape.rain => Icons.grain_rounded,
        AmbientSoundscape.forest => Icons.park_outlined,
        AmbientSoundscape.warmNoise => Icons.graphic_eq_rounded,
      };
}

class _FocusTabPill extends StatelessWidget {
  const _FocusTabPill({
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
        duration: const Duration(milliseconds: 180),
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? c.primary : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? c.primary : c.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? c.textOnPrimary : c.primary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected ? c.textOnPrimary : c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusKpiBox extends StatelessWidget {
  const _FocusKpiBox({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: c.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
