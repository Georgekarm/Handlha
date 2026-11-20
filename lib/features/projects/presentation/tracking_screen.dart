import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/mode/student_mode_controller.dart';
import '../../../app/theme/app_theme_extension.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loading_view.dart';
import '../../../shared/widgets/feature_empty_state.dart';
import '../../../shared/widgets/handelha_feedback.dart';
import '../../../shared/widgets/handelha_header.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_providers.dart';
import '../data/exam_grades_store.dart';
import '../data/productivity_analytics.dart';
import '../domain/focus_session.dart';
import '../domain/project.dart';
import 'project_providers.dart';

enum _ActivityLogFilter { all, tasks, focus }

/// شاشة الإنجازات والتحليلات الشاملة: تتابع اليوم والأسبوع والأسابيع والشهور،
/// مع مؤشرات فعلية، توزيع المشروعات، أوسمة الإنجاز والتشجيع الهادئ.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  AnalyticsGranularity _granularity = AnalyticsGranularity.week;
  _ActivityLogFilter _logFilter = _ActivityLogFilter.all;
  bool _showAllDetails = false;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final user = ref.watch(authNotifierProvider).value;
    final isStudentMode = ref.watch(isStudentModeActiveProvider);
    final tasksAsync = ref.watch(allTasksProvider);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];

    final isEn = Directionality.of(context) == TextDirection.ltr;
    if (tasksAsync.isLoading && !tasksAsync.hasValue) {
      return Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: AppLoadingView(
            message: isEn
                ? 'Gathering your real progress...'
                : 'بنجمعلك إنجازاتك الفعلية...',
          ),
        ),
      );
    }

    if (tasksAsync.hasError && !tasksAsync.hasValue) {
      return Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: AppErrorView(
            onRetry: () => ref.read(allTasksProvider.notifier).refresh(),
          ),
        ),
      );
    }

    final sessions = ref.watch(focusSessionsProvider).value ?? const <FocusSession>[];
    final tasks = tasksAsync.value ?? const <Task>[];
    final report = ProductivityReport.build(
      tasks: tasks,
      sessions: sessions,
      projects: projects,
      granularity: _granularity,
      firstName: user?.firstName ?? 'صديقي',
      isStudentMode: isStudentMode,
    );

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.primary,
          onRefresh: () async {
            await ref.read(allTasksProvider.notifier).refresh();
            await ref.read(projectsProvider.notifier).refresh();
            await ref.read(focusSessionsProvider.notifier).refresh();
          },
          child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 118),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HandelhaHeader(
                      title: isEn ? 'Your Progress' : 'إنجازك',
                      subtitle: isEn
                          ? 'Track your days, weeks, and months clearly'
                          : 'تتابع أيامك وأسابيعك وشهورك بوضوح',
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
                      actions: [
                        HandelhaHeaderIconButton(
                          icon: Icons.settings_outlined,
                          tooltip: isEn ? 'Settings' : 'الإعدادات',
                          onTap: () => context.push('/settings'),
                        ),
                      ],
                    ),
                    if (isStudentMode) ...[
                      _StudentModeActiveBanner(
                        onPlansTap: () => context.push('/subscription'),
                      ),
                      const SizedBox(height: 14),
                    ],

                    _GranularitySegmentedSwitch(
                      selected: _granularity,
                      onChanged: (next) => setState(() {
                        _granularity = next;
                        _showAllDetails = false;
                      }),
                    ),
                    const SizedBox(height: 16),

                    _HeroSummaryCard(report: report),
                    const SizedBox(height: 16),

                    if (!report.overallStats.hasData) ...[
                      FeatureEmptyState(
                        icon: Icons.bar_chart_rounded,
                        title: isEn
                            ? 'Your progress is just getting started'
                            : 'إنجازاتك لسه في بدايتها',
                        subtitle: isEn
                            ? 'The first task you finish or focus session you start will build your progress charts and reports right here.'
                            : 'أول مهمة تخلصها أو جلسة تركيز تبدأها هتبني رسومات وتقارير التتابع الخاصة بيك هنا.',
                        primaryCtaLabel:
                            isEn ? 'Add First Task' : 'إضافة أول مهمة',
                        onPrimaryCta: () => context.push('/tasks/add'),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      ..._buildTimelineSection(context, report),
                      const SizedBox(height: 16),

                      _RealInsightsCard(
                        report: report,
                        projects: projects,
                      ),
                      const SizedBox(height: 16),
                    ],

                    _EncouragementBanner(report: report),
                    const SizedBox(height: 14),

                    _MilestonesCard(milestones: report.milestones),
                    if (isStudentMode) ...[
                      const SizedBox(height: 16),
                      _ExamGradesAndCelebrationCard(
                        userId: user?.id ?? 'guest',
                        tasks: tasks,
                        onGradeSaved: () {
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                    if (report.overallStats.hasData) ...[
                      const SizedBox(height: 16),
                      _ActivityDetailsSection(
                        report: report,
                        projects: projects,
                        filter: _logFilter,
                        showAll: _showAllDetails,
                        onFilterChanged: (f) => setState(() => _logFilter = f),
                        onToggleShowAll: () =>
                            setState(() => _showAllDetails = !_showAllDetails),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ),
    );
  }

  List<Widget> _buildTimelineSection(
    BuildContext context,
    ProductivityReport report,
  ) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    switch (report.granularity) {
      case AnalyticsGranularity.day:
        return [
          _InteractiveBucketChartCard(
            title: isEn ? 'Daily Time Slots' : 'تتابع فترات اليوم',
            subtitle: isEn
                ? 'Your activity today across hours of the day'
                : 'نشاطك النهارده متوزع على ساعات اليوم',
            buckets: report.dayTimeSlots,
            barColor: c.primary,
            accentColor: c.primarySoft,
            highlightBadge: report.peakTimeSlotLabel == null
                ? null
                : (isEn
                    ? 'Peak: ${report.peakTimeSlotLabel}'
                    : 'ذروتك: ${report.peakTimeSlotLabel}'),
          ),
        ];
      case AnalyticsGranularity.week:
        return [
          _InteractiveBucketChartCard(
            title: isEn ? 'Weekly Day Progress' : 'تتابع أيام الأسبوع',
            subtitle: isEn
                ? 'Last 7 days • Focus minutes & completed tasks'
                : 'آخر ٧ أيام • دقائق التركيز والمهام المكتملة',
            buckets: report.weekDayBuckets,
            barColor: c.primary,
            accentColor: c.lavenderSoft,
            highlightBadge: report.peakDayLabel == null
                ? null
                : (isEn
                    ? 'Most active: ${report.peakDayLabel}'
                    : 'أنشط يوم: ${report.peakDayLabel}'),
          ),
          const SizedBox(height: 14),
          _InteractiveBucketChartCard(
            title: isEn ? 'Last 4 Weeks Comparison' : 'مقارنة آخر ٤ أسابيع',
            subtitle: isEn
                ? 'A broader picture of your week-to-week consistency'
                : 'صورة أوسع لاستمراريتك من أسبوع للتاني',
            buckets: report.rollingWeekBuckets,
            barColor: c.lavenderAccent,
            accentColor: c.lavenderSoft,
          ),
        ];
      case AnalyticsGranularity.month:
        final deltaSignTasks = report.monthDeltaTasks >= 0 ? '+' : '';
        final deltaSignMin = report.monthDeltaMinutes >= 0 ? '+' : '';
        final momText = isEn
            ? 'vs. last month: $deltaSignTasks${report.monthDeltaTasks} tasks • $deltaSignMin${report.monthDeltaMinutes}m focus'
            : 'مقارنة بالشهر اللي فات: $deltaSignTasks${ArabicFormatters.toArabicDigits(report.monthDeltaTasks)} مهام • $deltaSignMin${ArabicFormatters.toArabicDigits(report.monthDeltaMinutes)} د تركيز';
        return [
          _InteractiveBucketChartCard(
            title: isEn
                ? 'Monthly Progress (Last 6 Months)'
                : 'تتابع الشهور (آخر ٦ شهور)',
            subtitle: momText,
            buckets: report.monthBuckets,
            barColor: c.primary,
            accentColor: c.primarySoft,
            highlightBadge: report.monthDeltaTasks >= 0 && report.monthDeltaMinutes >= 0
                ? (isEn ? 'Positive Trend' : 'تصاعد إيجابي')
                : null,
          ),
          const SizedBox(height: 14),
          _InteractiveBucketChartCard(
            title: isEn ? 'Recent Weeks Breakdown' : 'تفصيل الأسابيع الأخيرة',
            subtitle: isEn
                ? 'Performance over the last 4 consecutive weeks'
                : 'أداء آخر ٤ أسابيع متتالية',
            buckets: report.rollingWeekBuckets,
            barColor: c.lavenderAccent,
            accentColor: c.lavenderSoft,
          ),
        ];
    }
  }
}

class _GranularitySegmentedSwitch extends StatelessWidget {
  final AnalyticsGranularity selected;
  final ValueChanged<AnalyticsGranularity> onChanged;

  const _GranularitySegmentedSwitch({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final options = [
      (AnalyticsGranularity.day, isEn ? 'Day' : 'اليوم'),
      (AnalyticsGranularity.week, isEn ? 'Week' : 'الأسبوع'),
      (AnalyticsGranularity.month, isEn ? 'Months' : 'الشهور'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (final item in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == item.$1
                        ? c.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color:
                          selected == item.$1 ? Colors.white : c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  final ProductivityReport report;

  const _HeroSummaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final stats = report.periodStats;
    final scopeTitle = switch (report.granularity) {
      AnalyticsGranularity.day => isEn ? "Today's Harvest" : 'حصاد النهارده',
      AnalyticsGranularity.week =>
        isEn ? 'Weekly Performance' : 'أداء الأسبوع',
      AnalyticsGranularity.month =>
        isEn ? 'Last 6 Months Progress' : 'إنجاز آخر ٦ شهور',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [c.primary, c.primaryStrong],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  scopeTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      report.currentStreakDays > 0
                          ? Icons.local_fire_department_rounded
                          : Icons.spa_outlined,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      report.currentStreakDays > 0
                          ? (isEn
                              ? '${report.currentStreakDays}-day streak'
                              : 'سلسلة ${ArabicFormatters.toArabicDigits(report.currentStreakDays)} أيام')
                          : (isEn ? 'Calm pace' : 'إيقاع هادي'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                isEn
                    ? '${stats.completedTasks} completed tasks'
                    : '${ArabicFormatters.toArabicDigits(stats.completedTasks)} مهام مكتملة',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                isEn
                    ? 'out of ${stats.totalTasks}'
                    : 'من أصل ${ArabicFormatters.toArabicDigits(stats.totalTasks)}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroStatColumn(
                    value: ArabicFormatters.durationMinutes(stats.focusMinutes),
                    label: stats.focusMinutes >= 60
                        ? '(${ArabicFormatters.durationCompact(stats.focusMinutes)})'
                        : (isEn ? 'Focus Minutes' : 'دقائق التركيز'),
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                Expanded(
                  child: _HeroStatColumn(
                    value: ArabicFormatters.toArabicDigits(
                      stats.completedFocusSessions,
                    ),
                    label: isEn ? 'Focus Sessions' : 'جلسات التركيز',
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                Expanded(
                  child: _HeroStatColumn(
                    value: ArabicFormatters.percent(
                      stats.completionRate * 100,
                    ),
                    label: isEn ? 'Completion Rate' : 'نسبة الإنجاز',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatColumn extends StatelessWidget {
  final String value;
  final String label;

  const _HeroStatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

class _InteractiveBucketChartCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<ActivityBucket> buckets;
  final Color barColor;
  final Color accentColor;
  final String? highlightBadge;

  const _InteractiveBucketChartCard({
    required this.title,
    required this.subtitle,
    required this.buckets,
    required this.barColor,
    required this.accentColor,
    this.highlightBadge,
  });

  @override
  State<_InteractiveBucketChartCard> createState() =>
      _InteractiveBucketChartCardState();
}

class _InteractiveBucketChartCardState
    extends State<_InteractiveBucketChartCard> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _defaultSelection();
  }

  @override
  void didUpdateWidget(covariant _InteractiveBucketChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buckets.length != widget.buckets.length) {
      _selectedIndex = _defaultSelection();
    } else if (_selectedIndex >= widget.buckets.length) {
      _selectedIndex = math.max(0, widget.buckets.length - 1);
    }
  }

  int _defaultSelection() {
    final currentIdx = widget.buckets.indexWhere((b) => b.isCurrent);
    if (currentIdx != -1) return currentIdx;
    return math.max(0, widget.buckets.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final buckets = widget.buckets;
    if (buckets.isEmpty) return const SizedBox.shrink();

    final maxScore = buckets.fold<int>(
      1,
      (maxV, b) => math.max(maxV, b.combinedScore),
    );
    final selected = buckets[_selectedIndex.clamp(0, buckets.length - 1)];

    return Container(
      padding: const EdgeInsets.all(18),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              if (widget.highlightBadge != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.highlightBadge!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.barColor,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Interactive Bar Chart
          SizedBox(
            height: 138,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < buckets.length; i++)
                  Expanded(
                    child: _ChartBarColumn(
                      bucket: buckets[i],
                      maxScore: maxScore,
                      isSelected: i == _selectedIndex,
                      barColor: widget.barColor,
                      onTap: () => setState(() => _selectedIndex = i),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Selected Bucket Real Breakdown Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${selected.label} • ${selected.rangeLabel}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected.combinedScore == 0
                            ? (Directionality.of(context) == TextDirection.ltr
                                ? 'No activity recorded in this period'
                                : 'مفيش نشاط متسجل في الفترة دي')
                            : (Directionality.of(context) == TextDirection.ltr
                                ? '${selected.completedTasks} tasks completed • ${ArabicFormatters.durationMinutes(selected.focusMinutes)} focus (${selected.sessionsCount} sessions)'
                                : '${ArabicFormatters.toArabicDigits(selected.completedTasks)} مهام مكتملة • ${ArabicFormatters.durationMinutes(selected.focusMinutes)} تركيز (${ArabicFormatters.toArabicDigits(selected.sessionsCount)} جلسات)'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected.focusMinutes > 0 || selected.completedTasks > 0)
                  Icon(
                    Icons.verified_rounded,
                    size: 18,
                    color: widget.barColor,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartBarColumn extends StatelessWidget {
  final ActivityBucket bucket;
  final int maxScore;
  final bool isSelected;
  final Color barColor;
  final VoidCallback onTap;

  const _ChartBarColumn({
    required this.bucket,
    required this.maxScore,
    required this.isSelected,
    required this.barColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final hasActivity = bucket.combinedScore > 0;
    final ratio =
        hasActivity ? (bucket.combinedScore / maxScore).clamp(0.14, 1.0) : 0.08;
    final barHeight = 76.0 * ratio;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (hasActivity)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                bucket.focusMinutes > 0
                    ? ArabicFormatters.toArabicDigits(bucket.focusMinutes)
                    : ArabicFormatters.toArabicDigits(bucket.completedTasks),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? barColor : c.textSecondary,
                ),
              ),
            )
          else
            const SizedBox(height: 17),
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: isSelected ? 22 : 16,
            height: barHeight,
            decoration: BoxDecoration(
              color: hasActivity
                  ? (isSelected ? barColor : barColor.withValues(alpha: 0.48))
                  : c.border.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: barColor.withValues(alpha: 0.9),
                      width: 1.5,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            bucket.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight:
                  isSelected || bucket.isCurrent ? FontWeight.w800 : FontWeight.w500,
              color: isSelected ? barColor : c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RealInsightsCard extends StatelessWidget {
  final ProductivityReport report;
  final List<Project> projects;

  const _RealInsightsCard({
    required this.report,
    required this.projects,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final avgPerDayText = report.avgTasksPerActiveDay == 0
        ? '—'
        : ArabicFormatters.toArabicDigits(
            report.avgTasksPerActiveDay.toStringAsFixed(1),
          );

    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(Icons.insights_rounded, size: 20, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEn ? 'Performance & Insights' : 'تحليل الأداء والتفاصيل',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2x2 Real KPI Grid
          Row(
            children: [
              Expanded(
                child: _InsightMiniTile(
                  icon: Icons.timer_outlined,
                  title: isEn ? 'Avg Session' : 'متوسط الجلسة',
                  value: report.avgFocusSessionMinutes == 0
                      ? '—'
                      : ArabicFormatters.durationMinutes(
                          report.avgFocusSessionMinutes,
                        ),
                  tint: c.primarySoft,
                  iconColor: c.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightMiniTile(
                  icon: Icons.local_fire_department_outlined,
                  title: isEn ? 'Best Streak' : 'أطول سلسلة',
                  value: report.bestStreakDays == 0
                      ? '—'
                      : (isEn
                          ? '${report.bestStreakDays} days'
                          : '${ArabicFormatters.toArabicDigits(report.bestStreakDays)} أيام'),
                  tint: c.danger.withValues(alpha: 0.12),
                  iconColor: c.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InsightMiniTile(
                  icon: Icons.wb_twilight_rounded,
                  title: isEn ? 'Peak Focus' : 'ذروة تركيزك',
                  value: report.peakTimeSlotLabel ??
                      report.peakDayLabel ??
                      (isEn ? 'Varied' : 'متنوّع'),
                  tint: c.lavenderSoft,
                  iconColor: c.lavenderAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightMiniTile(
                  icon: Icons.speed_rounded,
                  title: isEn ? 'Active Day Avg' : 'متوسط يومك النشط',
                  value: avgPerDayText == '—'
                      ? '—'
                      : (isEn ? '$avgPerDayText tasks' : '$avgPerDayText مهمة'),
                  tint: c.primarySoft,
                  iconColor: c.primary,
                ),
              ),
            ],
          ),

          // Completed breakdown by Project
          if (report.projectBreakdowns.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              isEn ? 'Progress by Project' : 'التقدّم حسب المشروعات',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            for (final item in report.projectBreakdowns.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProjectProgressRow(item: item),
              ),
          ],

          // Priority completion distribution
          if (report.periodCompletedTasks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              isEn
                  ? 'Completed Tasks by Priority'
                  : 'أولويات اللي خلصته في الفترة دي',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PriorityCountPill(
                  label: isEn ? 'Urgent' : 'عاجل',
                  count: report.priorityCompletedCounts[TaskPriority.urgent] ?? 0,
                  bg: c.danger.withValues(alpha: 0.12),
                  fg: c.danger,
                ),
                _PriorityCountPill(
                  label: isEn ? 'High' : 'عالي',
                  count: report.priorityCompletedCounts[TaskPriority.high] ?? 0,
                  bg: c.primarySoft,
                  fg: c.primary,
                ),
                _PriorityCountPill(
                  label: isEn ? 'Medium' : 'متوسط',
                  count: report.priorityCompletedCounts[TaskPriority.medium] ?? 0,
                  bg: c.lavenderSoft,
                  fg: c.lavenderAccent,
                ),
                _PriorityCountPill(
                  label: isEn ? 'Calm' : 'هادي',
                  count: report.priorityCompletedCounts[TaskPriority.low] ?? 0,
                  bg: c.surfaceSoft,
                  fg: c.textSecondary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightMiniTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color tint;
  final Color iconColor;

  const _InsightMiniTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.tint,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
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
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectProgressRow extends StatelessWidget {
  final ProjectBreakdown item;

  const _ProjectProgressRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final accent = Color(item.colorValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${ArabicFormatters.toArabicDigits(item.completedTasks)}/${ArabicFormatters.toArabicDigits(item.totalTasks)} (${ArabicFormatters.percent(item.completionRate * 100)})',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: item.completionRate,
            minHeight: 7,
            backgroundColor: c.border.withValues(alpha: 0.45),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ],
    );
  }
}

class _PriorityCountPill extends StatelessWidget {
  final String label;
  final int count;
  final Color bg;
  final Color fg;

  const _PriorityCountPill({
    required this.label,
    required this.count,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$label: ${ArabicFormatters.toArabicDigits(count)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _EncouragementBanner extends StatelessWidget {
  final ProductivityReport report;

  const _EncouragementBanner({required this.report});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: c.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.encouragementTitle,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: c.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.encouragementSubtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestonesCard extends StatelessWidget {
  final List<AchievementMilestone> milestones;

  const _MilestonesCard({required this.milestones});

  IconData _iconFor(MilestoneIconKind kind) => switch (kind) {
        MilestoneIconKind.firstStep => Icons.flag_rounded,
        MilestoneIconKind.deepFocus => Icons.hourglass_bottom_rounded,
        MilestoneIconKind.streak => Icons.local_fire_department_rounded,
        MilestoneIconKind.marathon => Icons.psychology_alt_rounded,
        MilestoneIconKind.tenTasks => Icons.workspace_premium_rounded,
        MilestoneIconKind.finisher => Icons.emoji_events_rounded,
        MilestoneIconKind.hardTaskCrusher => Icons.military_tech_rounded,
        MilestoneIconKind.examHero => Icons.school_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final unlockedCount = milestones.where((m) => m.unlocked).length;

    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(Icons.emoji_events_outlined, size: 20, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  Directionality.of(context) == TextDirection.ltr
                      ? 'Achievement Badges'
                      : 'أوسمة الإنجاز',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Text(
                '${ArabicFormatters.toArabicDigits(unlockedCount)}/${ArabicFormatters.toArabicDigits(milestones.length)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final m in milestones)
                    SizedBox(
                      width: tileWidth,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: m.unlocked ? c.primarySoft : c.surfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: m.unlocked
                                ? c.primary.withValues(alpha: 0.35)
                                : c.border.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  _iconFor(m.iconKind),
                                  size: 19,
                                  color: m.unlocked
                                      ? c.primary
                                      : c.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    m.progressLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: m.unlocked
                                          ? c.primary
                                          : c.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              m.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: m.progressRatio,
                                minHeight: 5,
                                backgroundColor: c.border.withValues(alpha: 0.5),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  m.unlocked ? c.primary : c.lavenderAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityDetailsSection extends StatelessWidget {
  final ProductivityReport report;
  final List<Project> projects;
  final _ActivityLogFilter filter;
  final bool showAll;
  final ValueChanged<_ActivityLogFilter> onFilterChanged;
  final VoidCallback onToggleShowAll;

  const _ActivityDetailsSection({
    required this.report,
    required this.projects,
    required this.filter,
    required this.showAll,
    required this.onFilterChanged,
    required this.onToggleShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final projectTitles = {
      for (final p in projects) p.id: ArabicFormatters.trData(p.title),
    };

    final entries = <_LogEntry>[
      if (filter == _ActivityLogFilter.all || filter == _ActivityLogFilter.tasks)
        for (final t in report.periodCompletedTasks)
          _LogEntry(
            isFocus: false,
            title: ArabicFormatters.trData(t.title),
            meta: [
              isEn
                  ? 'Completed ${ArabicFormatters.dateShort(t.updatedAt)}'
                  : 'أُنجزت ${ArabicFormatters.dateShort(t.updatedAt)}',
              if (t.projectId != null && projectTitles[t.projectId] != null)
                projectTitles[t.projectId]!,
              if ((t.actualDurationMinutes ?? t.estimatedDurationMinutes) != null)
                ArabicFormatters.durationMinutes(
                  t.actualDurationMinutes ?? t.estimatedDurationMinutes!,
                ),
            ].join(' • '),
            timestamp: t.updatedAt,
            badgeText: isEn ? 'Task' : 'مهمة',
          ),
      if (filter == _ActivityLogFilter.all || filter == _ActivityLogFilter.focus)
        for (final s in report.periodSessions)
          _LogEntry(
            isFocus: true,
            title: ArabicFormatters.trData(s.taskTitle),
            meta: isEn
                ? 'Focus session ${ArabicFormatters.dateShort(s.endedAt)} • ${ArabicFormatters.timeOfDayAr(s.endedAt)}'
                : 'جلسة تركيز ${ArabicFormatters.dateShort(s.endedAt)} • ${ArabicFormatters.timeOfDayAr(s.endedAt)}',
            timestamp: s.endedAt,
            badgeText: ArabicFormatters.durationMinutes(s.elapsedMinutes),
          ),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final visible = showAll ? entries : entries.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(Icons.history_rounded, size: 20, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEn ? 'Activity Log' : 'سجل التفاصيل',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Text(
                isEn
                    ? '${entries.length} items'
                    : '${ArabicFormatters.toArabicDigits(entries.length)} بند',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LogFilterChip(
                label: isEn ? 'All' : 'الكل',
                selected: filter == _ActivityLogFilter.all,
                onTap: () => onFilterChanged(_ActivityLogFilter.all),
              ),
              _LogFilterChip(
                label: isEn
                    ? 'Tasks (${report.periodCompletedTasks.length})'
                    : 'مهام (${ArabicFormatters.toArabicDigits(report.periodCompletedTasks.length)})',
                selected: filter == _ActivityLogFilter.tasks,
                onTap: () => onFilterChanged(_ActivityLogFilter.tasks),
              ),
              _LogFilterChip(
                label: isEn
                    ? 'Focus (${report.periodSessions.length})'
                    : 'تركيز (${ArabicFormatters.toArabicDigits(report.periodSessions.length)})',
                selected: filter == _ActivityLogFilter.focus,
                onTap: () => onFilterChanged(_ActivityLogFilter.focus),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                isEn
                    ? 'No activity recorded for this filter in the selected period.'
                    : 'مفيش تفاصيل متسجلة في الفلتر ده للفترة المختارة.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: c.textSecondary),
              ),
            )
          else ...[
            for (final entry in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: entry.isFocus ? c.lavenderSoft : c.primarySoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        entry.isFocus
                            ? Icons.timer_outlined
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                        color: entry.isFocus ? c.lavenderAccent : c.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.meta,
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: entry.isFocus ? c.lavenderSoft : c.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        entry.badgeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: entry.isFocus ? c.lavenderAccent : c.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (entries.length > 5)
              TextButton(
                onPressed: onToggleShowAll,
                child: Text(
                  showAll
                      ? (isEn ? 'Show Less' : 'عرض أقل')
                      : (isEn
                          ? 'Show All Details (${entries.length})'
                          : 'عرض كل التفاصيل (${ArabicFormatters.toArabicDigits(entries.length)})'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LogEntry {
  final bool isFocus;
  final String title;
  final String meta;
  final DateTime timestamp;
  final String badgeText;

  const _LogEntry({
    required this.isFocus,
    required this.title,
    required this.meta,
    required this.timestamp,
    required this.badgeText,
  });
}

class _LogFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LogFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surfaceSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? c.primary : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ExamGradesAndCelebrationCard extends StatefulWidget {
  const _ExamGradesAndCelebrationCard({
    required this.userId,
    required this.tasks,
    required this.onGradeSaved,
  });

  final String userId;
  final List<Task> tasks;
  final VoidCallback onGradeSaved;

  @override
  State<_ExamGradesAndCelebrationCard> createState() =>
      _ExamGradesAndCelebrationCardState();
}

class _ExamGradesAndCelebrationCardState
    extends State<_ExamGradesAndCelebrationCard> {
  List<ExamGradeEntry> _grades = const [];

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  @override
  void didUpdateWidget(covariant _ExamGradesAndCelebrationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadGrades();
    }
  }

  Future<void> _loadGrades() async {
    final loaded = await ExamGradesStore.load(widget.userId);
    if (mounted) {
      setState(() => _grades = loaded);
    }
  }

  void _openLogGradeSheet(BuildContext context, {String? initialExamTitle}) {
    final examTasks = widget.tasks
        .where(
          (t) => RegExp(r'(امتحان|اختبار|كويز|exam|quiz)', caseSensitive: false)
              .hasMatch(t.title),
        )
        .toList();

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LogGradeSheetContent(
        userId: widget.userId,
        examTasks: examTasks,
        initialExamTitle: initialExamTitle,
        onSaved: (entry) async {
          await _loadGrades();
          widget.onGradeSaved();
          if (mounted) {
            _showCelebrationDialog(this.context, entry);
          }
        },
      ),
    );
  }

  void _showCelebrationDialog(BuildContext context, ExamGradeEntry entry) {
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final msg = ExamGradesStore.buildEncouragement(
      examTitle: entry.examTitle,
      gradeTier: entry.gradeTier,
      scoreLabel: entry.scoreLabel,
    );

    HandelhaDialog.showCelebration(
      context,
      badgeTitle: isEn ? msg.badgeEn : msg.badgeAr,
      message: isEn ? msg.en : msg.ar,
      buttonLabel: isEn ? 'Keep Going!' : 'عاش، مكمّلين',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    const studentIndigo = Color(0xFF4F46E5);
    const studentTeal = Color(0xFF0D9488);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: studentIndigo.withValues(alpha: 0.28),
                width: 1.2,
              ),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  studentIndigo.withValues(alpha: 0.06),
                  c.surface,
                  studentTeal.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [studentIndigo, studentTeal],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(6),
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn ? 'Exam Grades' : 'تقديرات الامتحانات',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEn ? 'Student Mode Only' : 'ميزة خاصة بوضع الطالب',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: studentIndigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openLogGradeSheet(context),
                      style: TextButton.styleFrom(
                        backgroundColor: studentIndigo.withValues(alpha: 0.1),
                        foregroundColor: studentIndigo,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: Text(
                        isEn ? 'Add Grade' : 'سجّل نتيجتك',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_grades.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: studentIndigo.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: studentIndigo.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: studentIndigo,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEn
                                ? 'Finished an exam or quiz? Tap "Add Grade" to save your mark and track your semester progress.'
                                : 'خلصت امتحان أو كويز؟ اضغط «سجّل نتيجتك» واحفظ درجتك عشان تتابع مستواك في الترم.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final g in _grades.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.surfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: studentIndigo.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: studentIndigo,
                                  size: 19,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    g.examTitle,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [studentIndigo, studentTeal],
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    g.scoreLabel,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isEn ? g.encouragementEn : g.encouragementAr,
                              style: TextStyle(
                                fontSize: 12,
                                color: c.textPrimary,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentModeActiveBanner extends StatelessWidget {
  const _StudentModeActiveBanner({required this.onPlansTap});

  final VoidCallback onPlansTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    const studentIndigo = Color(0xFF4F46E5);
    const studentTeal = Color(0xFF0D9488);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: CustomPaint(
        painter: _StudentCrestPainter(
          accent: studentIndigo.withValues(alpha: 0.14),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: studentIndigo.withValues(alpha: 0.35),
            ),
            gradient: LinearGradient(
              colors: [
                studentIndigo.withValues(alpha: 0.12),
                studentTeal.withValues(alpha: 0.08),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [studentIndigo, studentTeal],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(5),
                    bottomLeft: Radius.circular(5),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 19,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Student Mode Active' : 'وضع الطالب شغّال',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isEn
                          ? 'Exam grades & study milestones are enabled'
                          : 'تسجيل تقديرات الامتحانات وأوسمة الدراسة مفعّلين هنا',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onPlansTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: studentIndigo.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    isEn ? 'Plans' : 'الباقات',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: studentIndigo,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentCrestPainter extends CustomPainter {
  const _StudentCrestPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.2), 26, paint);
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.2), 40, paint);
  }

  @override
  bool shouldRepaint(covariant _StudentCrestPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _LogGradeSheetContent extends StatefulWidget {
  const _LogGradeSheetContent({
    required this.userId,
    required this.examTasks,
    required this.initialExamTitle,
    required this.onSaved,
  });

  final String userId;
  final List<Task> examTasks;
  final String? initialExamTitle;
  final Future<void> Function(ExamGradeEntry entry) onSaved;

  @override
  State<_LogGradeSheetContent> createState() => _LogGradeSheetContentState();
}

class _LogGradeSheetContentState extends State<_LogGradeSheetContent> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _scoreCtrl;
  String _selectedTier = 'excellent';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final isEn = ArabicFormatters.useEnglish;
    _titleCtrl = TextEditingController(
      text: widget.initialExamTitle ??
          (widget.examTasks.isNotEmpty
              ? widget.examTasks.first.title
              : (isEn ? 'Arabic Exam' : 'امتحان عربي')),
    );
    _scoreCtrl = TextEditingController(
      text: isEn ? 'A+ (98%)' : 'امتياز (٩٨٪)',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _scoreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    const studentIndigo = Color(0xFF4F46E5);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    final options = [
      (
        tier: 'excellent',
        label: isEn ? 'Excellent (A+)' : 'امتياز (A+)',
        defaultScore: isEn ? 'A+ (98%)' : 'امتياز (٩٨٪)',
        icon: Icons.workspace_premium_rounded,
      ),
      (
        tier: 'very_good',
        label: isEn ? 'Very Good (B+)' : 'جيد جدًا',
        defaultScore: isEn ? 'Very Good (88%)' : 'جيد جدًا (٨٨٪)',
        icon: Icons.trending_up_rounded,
      ),
      (
        tier: 'good',
        label: isEn ? 'Good (B)' : 'جيد',
        defaultScore: isEn ? 'Good (78%)' : 'جيد (٧٨٪)',
        icon: Icons.thumb_up_alt_rounded,
      ),
      (
        tier: 'pass',
        label: isEn ? 'Pass / Comeback' : 'مقبول / تعويض',
        defaultScore: isEn ? 'Passed' : 'مقبول',
        icon: Icons.autorenew_rounded,
      ),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsetsBottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: c.border.withValues(alpha: 0.85)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: studentIndigo.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: studentIndigo,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEn ? 'Log Exam Grade' : 'سجّل نتيجة الامتحان',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            Text(
                              isEn
                                  ? 'Student Mode • Save your score clearly'
                                  : 'وضع الطالب • احفظ درجتك وتابع مستواك',
                              style: TextStyle(
                                fontSize: 12,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: c.textSecondary),
                        tooltip: isEn ? 'Close' : 'إغلاق',
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: c.border.withValues(alpha: 0.6)),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.examTasks.isNotEmpty) ...[
                          Text(
                            isEn ? 'Recent exam tasks' : 'امتحانات من مهامك',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final t in widget.examTasks.take(4))
                                ActionChip(
                                  label: Text(
                                    t.title,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: c.primary,
                                    ),
                                  ),
                                  backgroundColor: c.primarySoft,
                                  side: BorderSide(
                                    color: c.primary.withValues(alpha: 0.25),
                                  ),
                                  onPressed: () {
                                    setState(() => _titleCtrl.text = t.title);
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],
                        Text(
                          isEn
                              ? 'Exam or subject name'
                              : 'اسم الامتحان أو المادة',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _titleCtrl,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: c.surfaceSoft,
                            hintText: isEn
                                ? 'e.g. Arabic Midterm'
                                : 'مثلًا: امتحان عربي أو ميدتيرم',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: c.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: c.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: studentIndigo,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          isEn ? 'Grade tier' : 'التقدير',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final opt in options)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedTier = opt.tier;
                                    _scoreCtrl.text = opt.defaultScore;
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selectedTier == opt.tier
                                        ? studentIndigo.withValues(alpha: 0.14)
                                        : c.surfaceSoft,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _selectedTier == opt.tier
                                          ? studentIndigo
                                          : c.border,
                                      width:
                                          _selectedTier == opt.tier ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        opt.icon,
                                        size: 16,
                                        color: _selectedTier == opt.tier
                                            ? studentIndigo
                                            : c.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        opt.label,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: _selectedTier == opt.tier
                                              ? studentIndigo
                                              : c.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          isEn
                              ? 'Score details (optional)'
                              : 'الدرجة بالتفصيل (مثلًا ١٩/٢٠ أو ٩٥٪)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _scoreCtrl,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: c.surfaceSoft,
                            hintText: isEn ? '19/20 or 95%' : '٩٥٪ أو ١٩/٢٠',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: c.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: c.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: studentIndigo,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                  child: ElevatedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            final entry = await ExamGradesStore.addGrade(
                              userId: widget.userId,
                              examTitle: _titleCtrl.text,
                              gradeTier: _selectedTier,
                              scoreLabel: _scoreCtrl.text,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            await widget.onSaved(entry);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: studentIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 19),
                    label: Text(
                      isEn ? 'Save Grade' : 'احفظ النتيجة',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
