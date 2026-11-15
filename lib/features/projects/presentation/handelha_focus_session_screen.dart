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
import 'widgets/focus_timer_widgets.dart';
import 'widgets/focus_tree_canvas.dart';

enum _FocusPhase { active, paused, completed, onBreak }

enum _FocusViewTab { timer, tree }

/// شاشة جلسة التركيز المطوّرة:
/// - مؤقت حديث بحركة سلسة وشريط تفاعلي لاختيار المدة (٥ - ١٢٠ دقيقة)
/// - أصوات طبيعة هادئة للتركيز بتصميم عصري بدون تعقيد
/// - صفحة «شجرتك» التي تنمو وتكتمل وتُزهر مع كل جلسة تركيز منجزة
class HandelhaFocusSessionScreen extends ConsumerStatefulWidget {
  final String taskTitle;
  final String? taskId;
  final int initialMinutes;
  final bool openTreeTab;

  const HandelhaFocusSessionScreen({
    super.key,
    required this.taskTitle,
    this.taskId,
    this.initialMinutes = 25,
    this.openTreeTab = false,
  });

  @override
  ConsumerState<HandelhaFocusSessionScreen> createState() =>
      _HandelhaFocusSessionScreenState();
}

class _HandelhaFocusSessionScreenState
    extends ConsumerState<HandelhaFocusSessionScreen> {
  static const double _defaultAmbientVolume = 0.65;

  int _selectedFocusMinutes = 25;
  int _selectedBreakMinutes = 5;

  late int _focusSecondsTotal;
  late int _remainingSeconds;
  _FocusPhase _phase = _FocusPhase.active;
  late _FocusViewTab _viewTab;
  Timer? _timer;
  DateTime? _startedAt;
  bool _sessionRecorded = false;
  int _lastCompletedMinutes = 25;

  AmbientSoundscape _ambient = AmbientSoundscape.silent;
  bool _usedAmbientSound = false;
  List<FocusSession> _history = const [];

  @override
  void initState() {
    super.initState();
    _selectedFocusMinutes = widget.initialMinutes;
    _focusSecondsTotal = _selectedFocusMinutes * 60;
    _remainingSeconds = _focusSecondsTotal;
    _viewTab = widget.openTreeTab ? _FocusViewTab.tree : _FocusViewTab.timer;
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

  void _setDurationMinutes(int minutes) {
    final clamped = minutes.clamp(
      FocusDurationRulerBar.minMinutes,
      FocusDurationRulerBar.maxMinutes,
    );
    setState(() {
      _selectedFocusMinutes = clamped;
      _focusSecondsTotal = clamped * 60;
      _remainingSeconds = _focusSecondsTotal;
      _sessionRecorded = false;
    });
  }

  void _selectAmbient(AmbientSoundscape sound) {
    setState(() {
      _ambient = sound;
      if (sound != AmbientSoundscape.silent) {
        _usedAmbientSound = true;
      }
    });
    HandelhaSoundEngine.instance.playAmbient(
      sound,
      volume: _defaultAmbientVolume,
    );
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
    if (_phase == _FocusPhase.completed || _phase == _FocusPhase.onBreak) {
      return true;
    }
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

  double get _liveSessionElapsedFraction {
    if (_phase == _FocusPhase.onBreak) return 0.0;
    if (_phase == _FocusPhase.completed) return 1.0;
    if (_focusSecondsTotal <= 0) return 0.0;
    return ((_focusSecondsTotal - _remainingSeconds) / _focusSecondsTotal)
        .clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final user = ref.watch(authNotifierProvider).value;
    final sessions = ref.watch(focusSessionsProvider).value ?? _history;
    final treeProgress = FocusTreeProgress.compute(
      sessions: sessions,
      activeSessionFraction: _liveSessionElapsedFraction,
      justCompleted: _phase == _FocusPhase.completed,
    );

    final headerTitle = switch (_phase) {
      _FocusPhase.active => isEn ? 'Focus Session' : 'جلسة التركيز',
      _FocusPhase.paused => isEn ? 'Focus Paused' : 'التركيز متوقف',
      _FocusPhase.onBreak => isEn ? 'Break Time' : 'وقت الاستراحة',
      _FocusPhase.completed => isEn ? 'Well Done' : 'أحسنت',
    };

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
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: HandelhaHeader(
                        title: headerTitle,
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
                        onBack: () async {
                          if (_phase == _FocusPhase.completed) {
                            _exitScreen();
                            return;
                          }
                          final allow = await _confirmExitIfRunning();
                          if (allow && mounted) _exitScreen();
                        },
                      ),
                    ),
                    if (_phase != _FocusPhase.completed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: FocusTabSwitcher(
                          isTreeTab: _viewTab == _FocusViewTab.tree,
                          completedTreesCount: treeProgress.completedTrees,
                          isEn: isEn,
                          onSelectTimer: () =>
                              setState(() => _viewTab = _FocusViewTab.timer),
                          onSelectTree: () {
                            ref.read(focusSessionsProvider.notifier).refresh();
                            _loadFocusHistory();
                            setState(() => _viewTab = _FocusViewTab.tree);
                          },
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 132),
                        child: _phase == _FocusPhase.completed
                            ? _buildCompletedView(
                                context,
                                c: c,
                                isEn: isEn,
                                firstName: ArabicFormatters.trData(
                                  user?.firstName ?? (isEn ? 'Friend' : 'صديقي'),
                                ),
                                treeProgress: treeProgress,
                                sessions: sessions,
                              )
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.03),
                                      end: Offset.zero,
                                    ).animate(anim),
                                    child: child,
                                  ),
                                ),
                                child: _viewTab == _FocusViewTab.tree
                                    ? KeyedSubtree(
                                        key: const ValueKey<String>('tree_tab'),
                                        child: _buildYourTreeTabView(
                                          context,
                                          c: c,
                                          isEn: isEn,
                                          treeProgress: treeProgress,
                                          sessions: sessions,
                                        ),
                                      )
                                    : KeyedSubtree(
                                        key:
                                            const ValueKey<String>('timer_tab'),
                                        child: _buildTimerTabContent(
                                          context,
                                          c: c,
                                          isEn: isEn,
                                          treeProgress: treeProgress,
                                        ),
                                      ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 108,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          c.background.withValues(alpha: 0.0),
                          c.background.withValues(alpha: 0.88),
                          c.background,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const HandelhaBottomNav(currentIndex: 0),
      ),
    );
  }

  Widget _buildTimerTabContent(
    BuildContext context, {
    required AppThemeExtension c,
    required bool isEn,
    required FocusTreeProgress treeProgress,
  }) {
    final cleanTitle = ArabicFormatters.trData(widget.taskTitle);
    final breakSecondsTotal = _selectedBreakMinutes * 60;

    final config = switch (_phase) {
      _FocusPhase.active => (
          headline: isEn
              ? 'One thing. Your full focus on it.'
              : 'حاجة واحدة. تركيزك كله ليها.',
          badgeText: cleanTitle,
          badgeFill: c.surface,
          badgeTextColor: c.textSecondary,
          ringColor: c.primary,
          phaseBadge: isEn ? 'Deep Focus' : 'تركيز عميق',
          timerSub: isEn
              ? 'minutes for you and your task'
              : 'دقيقة لنفسك ولمهمتك',
          caption: isEn
              ? 'Turn off distractions, and leave the rest to us.'
              : 'اقفل المشتتات، وسيب الباقي علينا.',
          primaryLabel: isEn ? 'Pause' : 'إيقاف مؤقت',
          primaryIcon: Icons.pause_rounded,
          onPrimary: _pause,
          secondaryLabel: isEn ? 'End Session' : 'إنهاء الجلسة',
          onSecondary: _endSessionManually,
          progress: _focusSecondsTotal == 0
              ? 1.0
              : _remainingSeconds / _focusSecondsTotal,
          isRunning: true,
        ),
      _FocusPhase.paused => (
          headline: isEn
              ? 'Take your time, no rush.'
              : 'خد وقتك، مفيش استعجال.',
          badgeText: cleanTitle,
          badgeFill: c.surface,
          badgeTextColor: c.textSecondary,
          ringColor: c.lavenderAccent,
          phaseBadge: isEn ? 'Paused' : 'متوقف',
          timerSub: isEn
              ? 'minutes for you and your task'
              : 'دقيقة لنفسك ولمهمتك',
          caption: isEn
              ? 'Your progress is saved. Resume whenever you are ready.'
              : 'كل اللي عملته محفوظ. نكمّل لما تحب.',
          primaryLabel: isEn ? 'Resume Session' : 'كمّل الجلسة',
          primaryIcon: Icons.play_arrow_rounded,
          onPrimary: _resume,
          secondaryLabel: isEn ? 'End Session' : 'إنهاء الجلسة',
          onSecondary: _endSessionManually,
          progress: _focusSecondsTotal == 0
              ? 1.0
              : _remainingSeconds / _focusSecondsTotal,
          isRunning: false,
        ),
      _FocusPhase.onBreak => (
          headline: isEn
              ? 'A short break makes a big difference.'
              : 'استراحة صغيرة، تفرق كتير.',
          badgeText: isEn ? 'Time for yourself' : 'وقت لنفسك',
          badgeFill: c.primarySoft,
          badgeTextColor: c.primary,
          ringColor: c.primary,
          phaseBadge: isEn ? 'Calm Break' : 'استراحة',
          timerSub: isEn
              ? 'Drink water and take a breath'
              : 'اشرب ميّه وخد نفس',
          caption: isEn
              ? 'Stretch your back, work can wait.'
              : 'قوم افرد ضهرك، الشغل هيستناك.',
          primaryLabel: isEn ? 'Back to Focus' : 'رجوع للتركيز',
          primaryIcon: Icons.play_arrow_rounded,
          onPrimary: _restartFocusFromBreak,
          secondaryLabel: isEn ? 'End Break' : 'إنهاء الاستراحة',
          onSecondary: _exitScreen,
          progress: breakSecondsTotal == 0
              ? 1.0
              : _remainingSeconds / breakSecondsTotal,
          isRunning: true,
        ),
      _FocusPhase.completed => (
          headline: '',
          badgeText: cleanTitle,
          badgeFill: c.surface,
          badgeTextColor: c.textSecondary,
          ringColor: c.primary,
          phaseBadge: '',
          timerSub: '',
          caption: '',
          primaryLabel: '',
          primaryIcon: Icons.check_rounded,
          onPrimary: _exitScreen,
          secondaryLabel: '',
          onSecondary: _exitScreen,
          progress: 1.0,
          isRunning: false,
        ),
    };

    final treeGrowthPct =
        (treeProgress.visualGrowth * 100).round().clamp(5, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Text(
          config.headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            constraints: const BoxConstraints(minWidth: 140, maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: config.badgeFill,
              borderRadius: BorderRadius.circular(999),
              border: config.badgeFill == c.surface
                  ? Border.all(color: c.border)
                  : null,
            ),
            child: Text(
              config.badgeText,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: config.badgeTextColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Modern Animated Dial
        ModernFocusDial(
          remainingSeconds: _remainingSeconds,
          progress: config.progress,
          ringColor: config.ringColor,
          phaseLabel: config.phaseBadge,
          subLabel: config.timerSub,
          isRunning: config.isRunning,
          treeProgressPercent:
              _phase == _FocusPhase.onBreak ? null : treeGrowthPct,
          isEn: isEn,
        ),
        const SizedBox(height: 16),

        // Primary & Secondary Controls right below the dial for immediate access
        Row(
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: config.onPrimary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.textOnPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(config.primaryIcon, size: 20),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      config.primaryLabel,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: c.textOnPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: config.onSecondary,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.primarySoft,
                    foregroundColor: c.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      config.secondaryLabel,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: c.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Sleek Duration Bar OR Break Switcher
        if (_phase != _FocusPhase.onBreak)
          FocusDurationRulerBar(
            selectedMinutes: _selectedFocusMinutes,
            selectedBreakMinutes: _selectedBreakMinutes,
            isEn: isEn,
            onSelectMinutes: _setDurationMinutes,
            onSelectBreakMinutes: (b) =>
                setState(() => _selectedBreakMinutes = b),
          )
        else
          _buildBreakSelectorCard(c, isEn),

        const SizedBox(height: 12),

        // Upgraded Calm Soundscapes (No Volume Slider)
        FocusSoundscapeSection(
          selected: _ambient,
          isEn: isEn,
          onSelect: _selectAmbient,
        ),

        const SizedBox(height: 12),
        Text(
          config.caption,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakSelectorCard(AppThemeExtension c, bool isEn) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isEn ? 'Break Length' : 'مدة الاستراحة',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final bMin in const [5, 10, 15]) ...[
                      GestureDetector(
                        onTap: () => _startBreak(bMin),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedBreakMinutes == bMin
                                ? c.primary
                                : c.surfaceSoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _selectedBreakMinutes == bMin
                                  ? c.primary
                                  : c.border,
                            ),
                          ),
                          child: Text(
                            isEn
                                ? '${bMin}m'
                                : '${ArabicFormatters.toArabicDigits(bMin)} د',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _selectedBreakMinutes == bMin
                                  ? c.textOnPrimary
                                  : c.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      if (bMin != 15) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourTreeTabView(
    BuildContext context, {
    required AppThemeExtension c,
    required bool isEn,
    required FocusTreeProgress treeProgress,
    required List<FocusSession> sessions,
  }) {
    const dailyGoalMinutes = 90;
    final goalProgress =
        (treeProgress.todayMinutes / dailyGoalMinutes).clamp(0.0, 1.0);
    final completedSessions = sessions.where((s) => s.completed).toList();

    final badges = <({String title, String sub, IconData icon, bool unlocked})>[
      (
        title: isEn ? 'First Seed Planted' : 'فاتحة خير',
        sub: isEn
            ? 'Complete 1st focus session'
            : 'خلّص أول جلسة تركيز عشان تطلع شجرتك',
        icon: Icons.eco_rounded,
        unlocked: treeProgress.completedTrees >= 1,
      ),
      (
        title: isEn ? 'Growing Grove' : 'شدّيت حيلك',
        sub: isEn
            ? '3+ sessions or 75+ min'
            : 'كمّل ٣ جلسات أو ٧٥ دقيقة تركيز',
        icon: Icons.park_rounded,
        unlocked:
            treeProgress.completedTrees >= 3 || treeProgress.totalMinutes >= 75,
      ),
      (
        title: isEn ? 'Focus Champion' : 'بطل التركيز',
        sub: isEn
            ? '150+ total focus minutes'
            : 'وصلت لـ ١٥٠ دقيقة تركيز إجمالية',
        icon: Icons.emoji_events_rounded,
        unlocked: treeProgress.totalMinutes >= 150,
      ),
      (
        title: isEn ? 'Calm Focus' : 'رايق ومركّز',
        sub: isEn
            ? 'Focus with ambient sounds'
            : 'شغّل صوت طبيعة هادي وقت التركيز',
        icon: Icons.spa_rounded,
        unlocked: _usedAmbientSound || _ambient != AmbientSoundscape.silent,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FocusTreeStageCard(
          progress: treeProgress,
          isEn: isEn,
        ),
        const SizedBox(height: 12),

        // KPI Summary Cards
        Row(
          children: [
            Expanded(
              child: _FocusKpiBox(
                label: isEn ? 'Trees Grown' : 'شجر كملته',
                value: isEn
                    ? '${treeProgress.completedTrees}'
                    : ArabicFormatters.toArabicDigits(
                        treeProgress.completedTrees,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FocusKpiBox(
                label: isEn ? 'Today' : 'تركيز النهارده',
                value: isEn
                    ? '${treeProgress.todayMinutes}m'
                    : '${ArabicFormatters.toArabicDigits(treeProgress.todayMinutes)} د',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FocusKpiBox(
                label: isEn ? 'Total' : 'إجمالي التركيز',
                value: isEn
                    ? '${treeProgress.totalMinutes}m'
                    : '${ArabicFormatters.toArabicDigits(treeProgress.totalMinutes)} د',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grove / Completed Trees Shelf & Daily Goal
        Container(
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
                  Expanded(
                    child: Text(
                      isEn ? 'Your Focus Garden' : 'جنينة شجرك',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    isEn
                        ? '${treeProgress.todayMinutes}/$dailyGoalMinutes min'
                        : '${ArabicFormatters.toArabicDigits(treeProgress.todayMinutes)} / ${ArabicFormatters.toArabicDigits(dailyGoalMinutes)} د',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: c.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: goalProgress),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) => LinearProgressIndicator(
                    value: val,
                    minHeight: 8,
                    backgroundColor: c.surfaceSoft,
                    color: c.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (completedSessions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    isEn
                        ? 'Finish your first focus session to grow your sprout and plant your first completed tree.'
                        : 'خلّص أول جلسة تركيز عشان شجرتك تكبر وتزرع أول شجرة كاملة في جنينتك.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in completedSessions.take(8))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: c.primarySoft.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 140),
                              child: Text(
                                ArabicFormatters.trData(s.taskTitle),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
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
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: c.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Badges Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEn ? 'Tree Milestones & Badges' : 'أوسمة شجرتك',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < badges.length; i++) ...[
                _BadgeRowTile(
                  title: badges[i].title,
                  subtitle: badges[i].sub,
                  icon: badges[i].icon,
                  unlocked: badges[i].unlocked,
                ),
                if (i != badges.length - 1) const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => GoRouter.maybeOf(context)?.go('/tracking'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.primary,
                  side: BorderSide(color: c.primary.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: Text(
                  isEn
                      ? 'Open Full App Progress & Badges'
                      : 'افتح صفحة «إنجازك» وشوف باقي الأوسمة',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedView(
    BuildContext context, {
    required AppThemeExtension c,
    required bool isEn,
    required String firstName,
    required FocusTreeProgress treeProgress,
    required List<FocusSession> sessions,
  }) {
    final mins = _lastCompletedMinutes > 0
        ? _lastCompletedMinutes
        : _selectedFocusMinutes;
    final cleanTitle = ArabicFormatters.trData(widget.taskTitle);
    final isFullBloom =
        treeProgress.stageIndex >= FocusTreeProgress.maxStageIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isFullBloom
                  ? (isEn
                      ? 'Your tree blossomed!'
                      : 'عاش! شجرتك كملت وطلّعت ورد!')
                  : (isEn
                      ? 'Your tree grew a new stage!'
                      : 'شجرتك كبرت خطوة جديدة!'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: c.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isEn ? 'Way to go, $firstName!' : 'عاش يا $firstName!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: c.primary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          isEn
              ? '${ArabicFormatters.durationMinutesFull(mins)} of focus. A real step forward.'
              : '${ArabicFormatters.durationMinutesFull(mins)} تركيز. خطوة حقيقية لقدّام.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        // Compact Animated Growing Tree Celebration
        FocusTreeStageCard(
          progress: treeProgress,
          isEn: isEn,
          compact: true,
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Text(
            '$cleanTitle • ${ArabicFormatters.durationMinutesFull(mins)}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: _startBreak,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.textOnPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              isEn ? 'Take a Break' : 'خد استراحة',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: c.textOnPrimary,
              ),
            ),
          ),
        ),
        if (widget.taskId != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton(
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
              child: Text(
                isEn
                    ? 'Mark Task Completed in Schedule'
                    : 'علّم المهمة كمكتملة في جدولك',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
        TextButton(
          onPressed: _exitScreen,
          child: Text(
            isEn ? 'Back to Home' : 'ارجع للرئيسية',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeRowTile extends StatelessWidget {
  const _BadgeRowTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.unlocked,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: unlocked ? c.primarySoft.withValues(alpha: 0.55) : c.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked ? c.primary.withValues(alpha: 0.35) : c.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: unlocked ? c.primary : c.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              unlocked ? icon : Icons.lock_outline_rounded,
              size: 17,
              color: unlocked ? c.textOnPrimary : c.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: unlocked ? c.textPrimary : c.textSecondary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked)
            Icon(Icons.check_circle_rounded, size: 18, color: c.primary),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: c.primary,
            ),
          ),
          const SizedBox(height: 3),
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
