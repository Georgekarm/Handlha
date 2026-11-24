import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_extension.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loading_view.dart';
import '../../../shared/widgets/handelha_header.dart';
import '../../../shared/widgets/handelha_task_card.dart';
import '../../assistant/data/user_energy_preferences.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../../notifications/notification_inbox_store.dart';
import '../../projects/domain/focus_session.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/project_providers.dart';
import '../../projects/presentation/widgets/focus_tree_canvas.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_providers.dart';
import '../data/dashboard_task_selector.dart';

final _dashboardReadIdsProvider =
    FutureProvider.autoDispose.family<Set<String>, String>((ref, userId) {
  return NotificationInboxStore.loadReadIds(userId);
});

/// الشاشة الرئيسية.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedDayOffset = 0;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _greetingText(String firstName, bool isEn) {
    final hour = DateTime.now().hour;
    final cleanName = ArabicFormatters.trData(firstName);
    if (isEn) {
      final prefix = hour < 12 ? 'Good morning,' : 'Good evening,';
      return '$prefix $cleanName';
    }
    final prefix = hour < 12 ? 'صباح الخير يا' : 'مساء الخير يا';
    return '$prefix $cleanName';
  }

  String _singleDayInitial(DateTime dt, bool isEn) {
    if (isEn) {
      return switch (dt.weekday) {
        DateTime.monday => 'M',
        DateTime.tuesday => 'T',
        DateTime.wednesday => 'W',
        DateTime.thursday => 'T',
        DateTime.friday => 'F',
        DateTime.saturday => 'S',
        DateTime.sunday => 'S',
        _ => '',
      };
    }
    switch (dt.weekday) {
      case DateTime.monday:
        return 'ن';
      case DateTime.tuesday:
        return 'ث';
      case DateTime.wednesday:
        return 'ر';
      case DateTime.thursday:
        return 'خ';
      case DateTime.friday:
        return 'ج';
      case DateTime.saturday:
        return 'س';
      case DateTime.sunday:
        return 'ح';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final user = ref.watch(authNotifierProvider).value;
    final todayAsync = ref.watch(todayTasksProvider);
    final allAsync = ref.watch(allTasksProvider);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final focusSessions =
        ref.watch(focusSessionsProvider).value ?? const <FocusSession>[];
    final projectMap = {for (final p in projects) p.id: p};

    if (todayAsync.isLoading && todayAsync.value == null) {
      return const Material(
        type: MaterialType.transparency,
        child: AppLoadingView(showHeader: false),
      );
    }

    if (todayAsync.hasError && todayAsync.value == null) {
      return Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: AppErrorView(
            onRetry: () => ref.read(todayTasksProvider.notifier).refresh(),
            onSecondary: () => context.go('/tasks'),
          ),
        ),
      );
    }

    final today = DateTime.now();
    final selectedDate = DateTime(today.year, today.month, today.day)
        .add(Duration(days: _selectedDayOffset));

    final allTasks = allAsync.value ?? todayAsync.value ?? const <Task>[];
    final dayTasks = _selectedDayOffset == 0
        ? (todayAsync.value ?? const <Task>[])
        : allTasks.where((t) {
            if (t.isCancelled) return false;
            final dt = t.scheduledStartAt ?? t.dueAt;
            return dt != null && _isSameDay(dt, selectedDate);
          }).toList();

    final totalCount = dayTasks.length;
    final completedCount = dayTasks.where((t) => t.isCompleted).length;
    final progressRatio = totalCount == 0 ? 0.0 : completedCount / totalCount;

    final openTasks =
        dayTasks.where((t) => !t.isCompleted && !t.isCancelled).toList();
    final energyPrefs = ref.watch(userEnergyPreferencesProvider);
    final rankedOpen = DashboardTaskSelector.rankOpenTasks(
      openTasks,
      energyPrefs,
      today,
    );
    final heroSelection = DashboardTaskSelector.pickHeroTask(
      openTasks,
      energyPrefs,
      today,
    );
    final heroTask = heroSelection?.task;
    final remainingTasks = heroTask != null
        ? rankedOpen.where((t) => t.id != heroTask.id).take(4).toList()
        : const <Task>[];

    final readIds = user == null
        ? const <String>{}
        : (ref.watch(_dashboardReadIdsProvider(user.id)).value ??
            const <String>{});
    final hasUnreadNotifications = user != null &&
        allTasks.any(
          (t) =>
              !t.isCompleted &&
              !t.isCancelled &&
              t.dueAt != null &&
              !readIds.contains(t.id),
        );

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
        color: c.primary,
        onRefresh: () async {
          await Future.wait([
            ref.read(todayTasksProvider.notifier).refresh(),
            ref.read(allTasksProvider.notifier).refresh(),
            ref.read(projectsProvider.notifier).refresh(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top header bar
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                isEn
                                    ? '${ArabicFormatters.weekdayShort(selectedDate)}, ${ArabicFormatters.dateShort(selectedDate)}'
                                    : '${ArabicFormatters.weekdayShort(selectedDate)}، ${ArabicFormatters.dateShort(selectedDate)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _greetingText(
                            user?.firstName ?? (isEn ? 'Friend' : 'صديقي'),
                            isEn,
                          ),
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            color: c.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEn
                              ? "You don't have to finish everything. Start with one thing."
                              : 'مش لازم تخلّص كل حاجة. ابدأ بحاجة واحدة.',
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HandelhaHeaderIconButton(
                        icon: isDark
                            ? Icons.light_mode_outlined
                            : Icons.wb_sunny_outlined,
                        tooltip: isEn
                            ? (isDark ? 'Light Mode' : 'Dark Mode')
                            : (isDark ? 'الوضع النهاري' : 'الوضع الليلي'),
                        iconColor: c.primary,
                        backgroundColor: Colors.transparent,
                        onTap: () =>
                            ref.read(themeModeProvider.notifier).toggle(),
                      ),
                      const SizedBox(width: 6),
                      HandelhaHeaderIconButton(
                        icon: Icons.notifications_none_rounded,
                        tooltip: isEn ? 'Notifications' : 'الإشعارات',
                        showBadge: hasUnreadNotifications,
                        onTap: () => context.push('/notifications'),
                      ),
                      const SizedBox(width: 6),
                      HandelhaHeaderIconButton(
                        icon: Icons.settings_outlined,
                        tooltip: isEn ? 'Settings' : 'الإعدادات',
                        onTap: () => context.push('/settings'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 7-day strip
              Row(
                children: List.generate(7, (i) {
                  final date = DateTime(today.year, today.month, today.day)
                      .add(Duration(days: i));
                  final selected = i == _selectedDayOffset;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(end: i < 6 ? 6 : 0),
                      child: Material(
                        color: selected ? c.primary : c.surface,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _selectedDayOffset = i),
                          child: Container(
                            height: 62,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: selected
                                  ? null
                                  : Border.all(color: c.border, width: 1),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _singleDayInitial(date, isEn),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: selected
                                            ? c.textOnPrimary.withValues(alpha: 0.85)
                                            : c.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      ArabicFormatters.toArabicDigits(date.day),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: selected
                                            ? c.textOnPrimary
                                            : c.textPrimary,
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
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Row: Progress card + Quick "+ مهمة جديدة" lavender card
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      isEn
                                          ? '$completedCount of $totalCount'
                                          : '${ArabicFormatters.toArabicDigits(completedCount)} من ${ArabicFormatters.toArabicDigits(totalCount)}',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isEn
                                        ? (_selectedDayOffset == 0
                                            ? 'Tasks done today'
                                            : 'Tasks for this day')
                                        : (_selectedDayOffset == 0
                                            ? 'مهام خلصوا النهارده'
                                            : 'مهام اليوم ده'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 58,
                              height: 58,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 58,
                                    height: 58,
                                    child: CircularProgressIndicator(
                                      value: progressRatio,
                                      strokeWidth: 5.5,
                                      strokeCap: StrokeCap.round,
                                      backgroundColor: c.primarySoft,
                                      color: c.primary,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        ArabicFormatters.percent(
                                          progressRatio * 100,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: c.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Material(
                        color: c.lavenderSoft,
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => context.push('/tasks/add'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 16,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 26,
                                  color: c.lavenderAccent,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isEn ? 'New Task' : 'مهمة جديدة',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: c.lavenderAccent,
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
              ),
              const SizedBox(height: 18),

              // Hero teal focus card: خطوتك الجاية
              _HeroNextStepCard(
                heroTask: heroTask,
                selectionReason: heroSelection == null
                    ? null
                    : (isEn ? heroSelection.reasonEn : heroSelection.reasonAr),
                projectName: heroTask?.projectId != null
                    ? projectMap[heroTask!.projectId!]?.title
                    : null,
                onStartFocus: () {
                  final title = heroTask?.title != null
                      ? ArabicFormatters.trData(heroTask!.title)
                      : (isEn ? 'Calm Focus Session' : 'جلسة تركيز هادئة');
                  context.push(
                    '/focus-session',
                    extra: {
                      'title': title,
                      if (heroTask != null) 'id': heroTask.id,
                    },
                  );
                },
                onOpenAssistant: () => context.go('/chat'),
              ),
              const SizedBox(height: 14),
              _FocusDashboardStripCard(
                sessions: focusSessions,
                onOpenFocus: () => context.push(
                  '/focus-session',
                  extra: {
                    'title': heroTask?.title != null
                        ? ArabicFormatters.trData(heroTask!.title)
                        : (isEn ? 'Calm Focus Session' : 'جلسة تركيز هادئة'),
                    if (heroTask != null) 'id': heroTask.id,
                    'tab': 'timer',
                  },
                ),
                onOpenTree: () => context.push(
                  '/focus-session',
                  extra: {
                    'title': heroTask?.title != null
                        ? ArabicFormatters.trData(heroTask!.title)
                        : (isEn ? 'Calm Focus Session' : 'جلسة تركيز هادئة'),
                    if (heroTask != null) 'id': heroTask.id,
                    'tab': 'tree',
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Section: باقي يومك
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      isEn ? 'Rest of Your Day' : 'باقي يومك',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/tasks'),
                    child: Text(
                      isEn ? 'View All' : 'عرض الكل',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: c.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (remainingTasks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        heroTask == null
                            ? (isEn
                                ? 'Your day is clear! Add your first task or plan your day with the assistant.'
                                : 'يومك رايق! تقدر تضيف أول مهمة أو ترتّب يومك مع المساعد.')
                            : (isEn
                                ? 'No other tasks left today besides your current focus step.'
                                : 'مفيش مهام تانية متبقية النهارده غير خطوتك الحالية.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < remainingTasks.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      HandelhaTaskCard(
                        task: remainingTasks[i],
                        projectName: remainingTasks[i].projectId != null
                            ? projectMap[remainingTasks[i].projectId!]?.title
                            : null,
                        stripeColor: remainingTasks[i].projectId != null &&
                                projectMap[remainingTasks[i].projectId!] != null
                            ? Color(
                                projectMap[remainingTasks[i].projectId!]!
                                    .colorValue,
                              )
                            : null,
                        onToggleComplete: () {
                          final task = remainingTasks[i];
                          final notifier =
                              ref.read(todayTasksProvider.notifier);
                          if (task.isCompleted) {
                            notifier.reopenTask(task.id);
                          } else {
                            notifier.completeTask(task.id);
                          }
                        },
                        onTap: () => context.push(
                          '/tasks/add',
                          extra: remainingTasks[i],
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _HeroNextStepCard extends StatelessWidget {
  final Task? heroTask;
  final String? selectionReason;
  final String? projectName;
  final VoidCallback onStartFocus;
  final VoidCallback onOpenAssistant;

  const _HeroNextStepCard({
    required this.heroTask,
    this.selectionReason,
    this.projectName,
    required this.onStartFocus,
    required this.onOpenAssistant,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final minutes = heroTask?.estimatedDurationMinutes ?? 25;
    final cleanProject = projectName != null
        ? ArabicFormatters.trData(projectName!)
        : (isEn ? 'Core Task' : 'مهمة أساسية');
    final isHigh = heroTask != null &&
        (heroTask!.priority == TaskPriority.high ||
            heroTask!.priority == TaskPriority.urgent);
    final subLabel = heroTask == null
        ? (isEn ? 'Calm planning • Step by step' : 'تنظيم هادئ • خطوة بخطوة')
        : '$cleanProject • ${isHigh ? (isEn ? 'Work' : 'شغل') : (isEn ? 'Focus' : 'تركيز')}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.heroTeal,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: c.heroTeal.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Your Next Step' : 'خطوتك الجاية',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      heroTask != null
                          ? ArabicFormatters.trData(heroTask!.title)
                          : (isEn
                              ? 'Start a short focus session'
                              : 'ابدأ جلسة تركيز قصيرة'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    if (selectionReason != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        selectionReason!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // 25 دقيقة circular ring
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.34),
                    width: 2,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ArabicFormatters.toArabicDigits(minutes),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.05,
                          ),
                        ),
                        Text(
                          isEn ? 'min' : 'دقيقة',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ElevatedButton(
                    onPressed: onStartFocus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.92),
                      foregroundColor: c.heroTeal,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_outlined, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            isEn ? 'Start Focus Session' : 'ابدأ جلسة تركيز',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: c.heroTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: TextButton(
                  onPressed: onOpenAssistant,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isEn ? 'Plan together?' : 'نرتّبها سوا؟',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.92),
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

class _FocusDashboardStripCard extends StatelessWidget {
  const _FocusDashboardStripCard({
    required this.sessions,
    required this.onOpenFocus,
    required this.onOpenTree,
  });

  final List<FocusSession> sessions;
  final VoidCallback onOpenFocus;
  final VoidCallback onOpenTree;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final treeProgress = FocusTreeProgress.compute(sessions: sessions);
    const goalMinutes = 90;
    final progress = (treeProgress.todayMinutes / goalMinutes).clamp(0.0, 1.0);
    final stageName = treeProgress.stageTitle(isEn: isEn);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpenTree,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: CustomPaint(
                      painter: _MiniFocusTreeEmblemPainter(
                        stageIndex: treeProgress.stageIndex,
                        trunkColor: const Color(0xFF6B4F3B),
                        foliageColor: c.primary,
                        blossomColor: context.limeAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              flex: 2,
                              child: Text(
                                isEn ? 'Your Focus Tree' : 'شجرتك ونمو تركيزك',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              flex: 1,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: c.primarySoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  stageName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: c.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEn
                              ? 'Today: ${treeProgress.todayMinutes} min • ${treeProgress.completedTrees} completed tree(s)'
                              : 'النهارده ${ArabicFormatters.toArabicDigits(treeProgress.todayMinutes)} د • ${ArabicFormatters.toArabicDigits(treeProgress.completedTrees)} شجرة مكتملة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 76),
                    child: TextButton(
                      onPressed: onOpenTree,
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn ? 'Open Tree' : 'عرض شجرتك',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: c.surfaceSoft,
                  color: c.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      isEn
                          ? 'Daily focus goal: ${treeProgress.todayMinutes} / $goalMinutes min'
                          : 'الهدف اليومي: ${ArabicFormatters.toArabicDigits(treeProgress.todayMinutes)} من ${ArabicFormatters.toArabicDigits(goalMinutes)} د',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onOpenFocus,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: c.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isEn ? 'Start Timer' : 'فتح المؤقت',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: c.primary,
                            ),
                          ),
                        ],
                      ),
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

class _MiniFocusTreeEmblemPainter extends CustomPainter {
  final int stageIndex;
  final Color trunkColor;
  final Color foliageColor;
  final Color blossomColor;

  const _MiniFocusTreeEmblemPainter({
    required this.stageIndex,
    required this.trunkColor,
    required this.foliageColor,
    required this.blossomColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Ground soil arc
    final soilPaint = Paint()
      ..color = trunkColor.withValues(alpha: 0.35)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.25, h * 0.80),
      Offset(w * 0.75, h * 0.80),
      soilPaint,
    );

    // Stem / trunk height scales with growth stage (0..4)
    final stemHeight = (0.18 + stageIndex * 0.08).clamp(0.18, 0.45);
    final trunkPaint = Paint()
      ..color = trunkColor
      ..strokeWidth = stageIndex >= 2 ? 3.2 : 2.2
      ..strokeCap = StrokeCap.round;
    final basePt = Offset(cx, h * 0.79);
    final topPt = Offset(cx, h * (0.79 - stemHeight));
    canvas.drawLine(basePt, topPt, trunkPaint);

    final leafPaint = Paint()..color = foliageColor;
    if (stageIndex <= 1) {
      // Seed sprout: two tender side leaves
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx - 5, topPt.dy + 1),
          width: 9,
          height: 5.5,
        ),
        leafPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + 5, topPt.dy - 1),
          width: 9,
          height: 5.5,
        ),
        leafPaint,
      );
      return;
    }

    // Layered botanical canopy
    final sideLeafPaint = Paint()..color = foliageColor.withValues(alpha: 0.86);
    canvas.drawCircle(
      Offset(cx, topPt.dy - 4),
      stageIndex >= 3 ? 9.5 : 7.5,
      leafPaint,
    );
    canvas.drawCircle(
      Offset(cx - 6.5, topPt.dy + 2),
      6.0,
      sideLeafPaint,
    );
    canvas.drawCircle(
      Offset(cx + 6.5, topPt.dy + 2),
      6.0,
      sideLeafPaint,
    );

    if (stageIndex >= 4) {
      final bloomPaint = Paint()..color = blossomColor;
      canvas.drawCircle(Offset(cx - 3.5, topPt.dy - 6), 2.1, bloomPaint);
      canvas.drawCircle(Offset(cx + 4.5, topPt.dy - 3), 2.1, bloomPaint);
      canvas.drawCircle(Offset(cx, topPt.dy + 1), 1.9, bloomPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniFocusTreeEmblemPainter oldDelegate) =>
      oldDelegate.stageIndex != stageIndex ||
      oldDelegate.foliageColor != foliageColor ||
      oldDelegate.blossomColor != blossomColor;
}
