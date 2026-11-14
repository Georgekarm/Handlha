import '../../../shared/utils/arabic_formatters.dart';
import '../../tasks/domain/task.dart';
import '../domain/focus_session.dart';
import '../domain/project.dart';

enum AnalyticsGranularity { day, week, month }

class ProductivityAnalytics {
  final int totalTasks;
  final int completedTasks;
  final int overdueTasks;
  final int focusMinutes;
  final int completedFocusSessions;

  const ProductivityAnalytics({
    required this.totalTasks,
    required this.completedTasks,
    required this.overdueTasks,
    required this.focusMinutes,
    required this.completedFocusSessions,
  });

  double get completionRate => totalTasks == 0 ? 0 : completedTasks / totalTasks;
  bool get hasData => totalTasks > 0 || focusMinutes > 0;

  factory ProductivityAnalytics.from({
    required List<Task> tasks,
    required List<FocusSession> sessions,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    return ProductivityAnalytics(
      totalTasks: tasks.where((t) => !t.isCancelled).length,
      completedTasks: tasks.where((t) => t.isCompleted).length,
      overdueTasks: tasks
          .where(
            (t) =>
                !t.isCompleted &&
                !t.isCancelled &&
                t.dueAt != null &&
                t.dueAt!.isBefore(reference),
          )
          .length,
      focusMinutes: sessions.fold(0, (sum, s) => sum + s.elapsedMinutes),
      completedFocusSessions: sessions.where((s) => s.completed).length,
    );
  }
}

class ActivityBucket {
  final String label;
  final String rangeLabel;
  final int completedTasks;
  final int focusMinutes;
  final int sessionsCount;
  final bool isCurrent;

  const ActivityBucket({
    required this.label,
    required this.rangeLabel,
    required this.completedTasks,
    required this.focusMinutes,
    required this.sessionsCount,
    this.isCurrent = false,
  });

  int get combinedScore => focusMinutes + (completedTasks * 20);
}

class ProjectBreakdown {
  final String projectId;
  final String title;
  final int colorValue;
  final int completedTasks;
  final int totalTasks;

  const ProjectBreakdown({
    required this.projectId,
    required this.title,
    required this.colorValue,
    required this.completedTasks,
    required this.totalTasks,
  });

  double get completionRate =>
      totalTasks == 0 ? 0 : (completedTasks / totalTasks).clamp(0.0, 1.0);
}

enum MilestoneIconKind {
  firstStep,
  deepFocus,
  marathon,
  streak,
  tenTasks,
  finisher,
  hardTaskCrusher,
  examHero,
}

class AchievementMilestone {
  final String id;
  final String title;
  final String subtitle;
  final String progressLabel;
  final double progressRatio;
  final bool unlocked;
  final MilestoneIconKind iconKind;

  const AchievementMilestone({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.progressLabel,
    required this.progressRatio,
    required this.unlocked,
    required this.iconKind,
  });
}

class ProductivityReport {
  final AnalyticsGranularity granularity;
  final ProductivityAnalytics periodStats;
  final ProductivityAnalytics overallStats;
  final List<ActivityBucket> dayTimeSlots;
  final List<ActivityBucket> weekDayBuckets;
  final List<ActivityBucket> rollingWeekBuckets;
  final List<ActivityBucket> monthBuckets;
  final int currentStreakDays;
  final int bestStreakDays;
  final int avgFocusSessionMinutes;
  final double avgTasksPerActiveDay;
  final String? peakDayLabel;
  final String? peakTimeSlotLabel;
  final int monthDeltaTasks;
  final int monthDeltaMinutes;
  final List<ProjectBreakdown> projectBreakdowns;
  final Map<TaskPriority, int> priorityCompletedCounts;
  final List<AchievementMilestone> milestones;
  final List<Task> periodCompletedTasks;
  final List<FocusSession> periodSessions;
  final String encouragementTitle;
  final String encouragementSubtitle;

  const ProductivityReport({
    required this.granularity,
    required this.periodStats,
    required this.overallStats,
    required this.dayTimeSlots,
    required this.weekDayBuckets,
    required this.rollingWeekBuckets,
    required this.monthBuckets,
    required this.currentStreakDays,
    required this.bestStreakDays,
    required this.avgFocusSessionMinutes,
    required this.avgTasksPerActiveDay,
    required this.peakDayLabel,
    required this.peakTimeSlotLabel,
    required this.monthDeltaTasks,
    required this.monthDeltaMinutes,
    required this.projectBreakdowns,
    required this.priorityCompletedCounts,
    required this.milestones,
    required this.periodCompletedTasks,
    required this.periodSessions,
    required this.encouragementTitle,
    required this.encouragementSubtitle,
  });

  factory ProductivityReport.build({
    required List<Task> tasks,
    required List<FocusSession> sessions,
    required List<Project> projects,
    required AnalyticsGranularity granularity,
    String firstName = 'صديقي',
    bool isStudentMode = false,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final todayStart = DateTime(reference.year, reference.month, reference.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final activeTasks = tasks.where((t) => !t.isCancelled && !t.isDeleted).toList();

    final periodStart = switch (granularity) {
      AnalyticsGranularity.day => todayStart,
      AnalyticsGranularity.week => todayStart.subtract(const Duration(days: 6)),
      AnalyticsGranularity.month =>
        DateTime(reference.year, reference.month - 5, 1),
    };

    final periodTasks = activeTasks.where((t) {
      final stamp = t.isCompleted
          ? t.updatedAt
          : (t.scheduledStartAt ?? t.dueAt ?? t.updatedAt);
      if (granularity == AnalyticsGranularity.day) {
        if (t.isCompleted) {
          return !t.updatedAt.isBefore(todayStart) &&
              t.updatedAt.isBefore(tomorrowStart);
        }
        final plannedAt = t.scheduledStartAt ?? t.dueAt;
        if (plannedAt == null) return true;
        return plannedAt.isBefore(tomorrowStart);
      }
      return !stamp.isBefore(periodStart) && stamp.isBefore(tomorrowStart);
    }).toList();

    final periodSessions = sessions
        .where(
          (s) => !s.endedAt.isBefore(periodStart) && s.endedAt.isBefore(tomorrowStart),
        )
        .toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

    final periodCompletedTasks = periodTasks.where((t) => t.isCompleted).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final overallStats = ProductivityAnalytics.from(
      tasks: activeTasks,
      sessions: sessions,
      now: reference,
    );
    final periodStats = ProductivityAnalytics.from(
      tasks: periodTasks,
      sessions: periodSessions,
      now: reference,
    );

    final dayTimeSlots = _buildDayTimeSlots(
      tasks: activeTasks.where((t) => t.isCompleted).toList(),
      sessions: sessions,
      todayStart: todayStart,
      tomorrowStart: tomorrowStart,
    );
    final weekDayBuckets = _buildWeekDayBuckets(
      completedTasks: activeTasks.where((t) => t.isCompleted).toList(),
      sessions: sessions,
      todayStart: todayStart,
    );
    final rollingWeekBuckets = _buildRollingWeekBuckets(
      completedTasks: activeTasks.where((t) => t.isCompleted).toList(),
      sessions: sessions,
      todayStart: todayStart,
    );
    final monthBuckets = _buildMonthBuckets(
      completedTasks: activeTasks.where((t) => t.isCompleted).toList(),
      sessions: sessions,
      reference: reference,
    );

    final streaks = _computeStreaks(
      completedTasks: activeTasks.where((t) => t.isCompleted).toList(),
      sessions: sessions,
      todayStart: todayStart,
    );

    final avgFocus = periodSessions.isEmpty
        ? 0
        : (periodStats.focusMinutes / periodSessions.length).round();

    final activeDaysInPeriod = <String>{
      for (final t in periodCompletedTasks) _dayKey(t.updatedAt),
      for (final s in periodSessions) _dayKey(s.endedAt),
    };
    final avgPerDay = activeDaysInPeriod.isEmpty
        ? 0.0
        : periodCompletedTasks.length / activeDaysInPeriod.length;

    final peakDay = _findPeakBucket(weekDayBuckets);
    final peakSlot = _findPeakBucket(dayTimeSlots);

    final currentMonth = monthBuckets.last;
    final previousMonth = monthBuckets[monthBuckets.length - 2];
    final monthDeltaTasks =
        currentMonth.completedTasks - previousMonth.completedTasks;
    final monthDeltaMinutes =
        currentMonth.focusMinutes - previousMonth.focusMinutes;

    final projectBreakdowns = _buildProjectBreakdowns(
      tasks: activeTasks,
      projects: projects,
    );

    final priorityCounts = <TaskPriority, int>{
      for (final p in TaskPriority.values) p: 0,
    };
    for (final t in periodCompletedTasks) {
      priorityCounts[t.priority] = (priorityCounts[t.priority] ?? 0) + 1;
    }

    final completedProjectsCount = projects
        .where((p) => p.status == ProjectStatus.completed || p.progressPercent >= 100)
        .length;
    final completedHardTasksCount = activeTasks
        .where(
          (t) =>
              t.isCompleted &&
              (t.priority == TaskPriority.high ||
                  t.priority == TaskPriority.urgent),
        )
        .length;
    final completedExamsCount = activeTasks
        .where(
          (t) =>
              t.isCompleted &&
              RegExp(r'(امتحان|اختبار|كويز|exam|quiz)', caseSensitive: false)
                  .hasMatch(t.title),
        )
        .length;

    final milestones = _buildMilestones(
      overallStats: overallStats,
      bestStreak: streaks.best,
      completedProjectsCount: completedProjectsCount,
      completedHardTasksCount: completedHardTasksCount,
      completedExamsCount: completedExamsCount,
      isStudentMode: isStudentMode,
    );

    final encouragement = _buildEncouragement(
      firstName: firstName,
      granularity: granularity,
      periodStats: periodStats,
      overallStats: overallStats,
      streak: streaks.current,
      peakDayLabel: peakDay,
    );

    return ProductivityReport(
      granularity: granularity,
      periodStats: periodStats,
      overallStats: overallStats,
      dayTimeSlots: dayTimeSlots,
      weekDayBuckets: weekDayBuckets,
      rollingWeekBuckets: rollingWeekBuckets,
      monthBuckets: monthBuckets,
      currentStreakDays: streaks.current,
      bestStreakDays: streaks.best,
      avgFocusSessionMinutes: avgFocus,
      avgTasksPerActiveDay: avgPerDay,
      peakDayLabel: peakDay,
      peakTimeSlotLabel: peakSlot,
      monthDeltaTasks: monthDeltaTasks,
      monthDeltaMinutes: monthDeltaMinutes,
      projectBreakdowns: projectBreakdowns,
      priorityCompletedCounts: priorityCounts,
      milestones: milestones,
      periodCompletedTasks: periodCompletedTasks,
      periodSessions: periodSessions,
      encouragementTitle: encouragement.$1,
      encouragementSubtitle: encouragement.$2,
    );
  }

  static List<ActivityBucket> _buildDayTimeSlots({
    required List<Task> tasks,
    required List<FocusSession> sessions,
    required DateTime todayStart,
    required DateTime tomorrowStart,
  }) {
    final todayTasks = tasks
        .where(
          (t) =>
              !t.updatedAt.isBefore(todayStart) &&
              t.updatedAt.isBefore(tomorrowStart),
        )
        .toList();
    final todaySessions = sessions
        .where(
          (s) =>
              !s.endedAt.isBefore(todayStart) &&
              s.endedAt.isBefore(tomorrowStart),
        )
        .toList();

    bool inSlot(int hour, int index) => switch (index) {
          0 => hour >= 5 && hour < 12,
          1 => hour >= 12 && hour < 16,
          2 => hour >= 16 && hour < 20,
          _ => hour >= 20 || hour < 5,
        };

    final isEn = ArabicFormatters.useEnglish;
    final defs = isEn
        ? const [
            ('Morning', '5 AM – 12 PM'),
            ('Noon', '12 PM – 4 PM'),
            ('Afternoon', '4 PM – 8 PM'),
            ('Night', '8 PM – 5 AM'),
          ]
        : const [
            ('الصبح', '٥ ص – ١٢ م'),
            ('الضهر', '١٢ م – ٤ م'),
            ('العصر', '٤ م – ٨ م'),
            ('بالليل', '٨ م – ٥ ص'),
          ];
    final currentHour = DateTime.now().hour;

    return [
      for (int i = 0; i < defs.length; i++)
        ActivityBucket(
          label: defs[i].$1,
          rangeLabel: defs[i].$2,
          completedTasks:
              todayTasks.where((t) => inSlot(t.updatedAt.hour, i)).length,
          focusMinutes: todaySessions
              .where((s) => inSlot(s.endedAt.hour, i))
              .fold(0, (sum, s) => sum + s.elapsedMinutes),
          sessionsCount:
              todaySessions.where((s) => inSlot(s.endedAt.hour, i)).length,
          isCurrent: inSlot(currentHour, i),
        ),
    ];
  }

  static List<ActivityBucket> _buildWeekDayBuckets({
    required List<Task> completedTasks,
    required List<FocusSession> sessions,
    required DateTime todayStart,
  }) {
    return List.generate(7, (idx) {
      final day = todayStart.subtract(Duration(days: 6 - idx));
      final nextDay = day.add(const Duration(days: 1));
      final daySessions = sessions.where(
        (s) => !s.endedAt.isBefore(day) && s.endedAt.isBefore(nextDay),
      );
      final dayCompleted = completedTasks.where(
        (t) => !t.updatedAt.isBefore(day) && t.updatedAt.isBefore(nextDay),
      );
      return ActivityBucket(
        label: ArabicFormatters.weekdayShort(day),
        rangeLabel: ArabicFormatters.dateShort(day),
        completedTasks: dayCompleted.length,
        focusMinutes: daySessions.fold(0, (sum, s) => sum + s.elapsedMinutes),
        sessionsCount: daySessions.length,
        isCurrent: idx == 6,
      );
    });
  }

  static List<ActivityBucket> _buildRollingWeekBuckets({
    required List<Task> completedTasks,
    required List<FocusSession> sessions,
    required DateTime todayStart,
  }) {
    return List.generate(4, (idx) {
      final weeksBack = 3 - idx;
      final end = todayStart.add(Duration(days: 1 - (weeksBack * 7)));
      final start = end.subtract(const Duration(days: 7));
      final inclusiveEndDay = end.subtract(const Duration(days: 1));
      final weekSessions = sessions.where(
        (s) => !s.endedAt.isBefore(start) && s.endedAt.isBefore(end),
      );
      final weekCompleted = completedTasks.where(
        (t) => !t.updatedAt.isBefore(start) && t.updatedAt.isBefore(end),
      );
      final isEn = ArabicFormatters.useEnglish;
      final label = isEn
          ? switch (weeksBack) {
              0 => 'This Week',
              1 => 'Last Week',
              2 => '2w Ago',
              _ => '3w Ago',
            }
          : switch (weeksBack) {
              0 => 'الأسبوع ده',
              1 => 'الأسبوع اللي فات',
              2 => 'قبل أسبوعين',
              _ => 'قبل ٣ أسابيع',
            };
      return ActivityBucket(
        label: label,
        rangeLabel:
            '${ArabicFormatters.dateShort(start)} - ${ArabicFormatters.dateShort(inclusiveEndDay)}',
        completedTasks: weekCompleted.length,
        focusMinutes: weekSessions.fold(0, (sum, s) => sum + s.elapsedMinutes),
        sessionsCount: weekSessions.length,
        isCurrent: weeksBack == 0,
      );
    });
  }

  static List<ActivityBucket> _buildMonthBuckets({
    required List<Task> completedTasks,
    required List<FocusSession> sessions,
    required DateTime reference,
  }) {
    return List.generate(6, (idx) {
      final monthsBack = 5 - idx;
      final monthStart = DateTime(reference.year, reference.month - monthsBack, 1);
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
      final monthSessions = sessions.where(
        (s) => !s.endedAt.isBefore(monthStart) && s.endedAt.isBefore(monthEnd),
      );
      final monthCompleted = completedTasks.where(
        (t) =>
            !t.updatedAt.isBefore(monthStart) && t.updatedAt.isBefore(monthEnd),
      );
      final monthName = ArabicFormatters.monthName(monthStart.month);
      return ActivityBucket(
        label: monthName,
        rangeLabel: '$monthName ${ArabicFormatters.toArabicDigits(monthStart.year)}',
        completedTasks: monthCompleted.length,
        focusMinutes: monthSessions.fold(0, (sum, s) => sum + s.elapsedMinutes),
        sessionsCount: monthSessions.length,
        isCurrent: monthsBack == 0,
      );
    });
  }

  static ({int current, int best}) _computeStreaks({
    required List<Task> completedTasks,
    required List<FocusSession> sessions,
    required DateTime todayStart,
  }) {
    final activeDates = <DateTime>{
      for (final t in completedTasks)
        DateTime(t.updatedAt.year, t.updatedAt.month, t.updatedAt.day),
      for (final s in sessions)
        DateTime(s.endedAt.year, s.endedAt.month, s.endedAt.day),
    };
    if (activeDates.isEmpty) return (current: 0, best: 0);

    var current = 0;
    var cursor = activeDates.contains(todayStart)
        ? todayStart
        : todayStart.subtract(const Duration(days: 1));
    while (activeDates.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final sorted = activeDates.toList()..sort();
    var best = 1;
    var run = 1;
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 1) {
        run++;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return (current: current, best: best);
  }

  static String? _findPeakBucket(List<ActivityBucket> buckets) {
    ActivityBucket? best;
    for (final b in buckets) {
      if (b.combinedScore <= 0) continue;
      if (best == null || b.combinedScore > best.combinedScore) {
        best = b;
      }
    }
    return best?.label;
  }

  static List<ProjectBreakdown> _buildProjectBreakdowns({
    required List<Task> tasks,
    required List<Project> projects,
  }) {
    final isEn = ArabicFormatters.useEnglish;
    final result = <ProjectBreakdown>[];
    for (final project in projects) {
      final projectTasks =
          tasks.where((t) => t.projectId == project.id).toList();
      if (projectTasks.isEmpty && project.taskIds.isEmpty) continue;
      final completedCount = projectTasks.where((t) => t.isCompleted).length;
      final totalCount = projectTasks.length;
      result.add(
        ProjectBreakdown(
          projectId: project.id,
          title: ArabicFormatters.trData(project.title),
          colorValue: project.colorValue,
          completedTasks: completedCount,
          totalTasks: totalCount,
        ),
      );
    }

    final generalTasks = tasks.where((t) => t.projectId == null).toList();
    if (generalTasks.isNotEmpty) {
      result.add(
        ProjectBreakdown(
          projectId: '_general',
          title: isEn ? 'General Daily Tasks' : 'مهام يومية عامة',
          colorValue: 0xFF007067,
          completedTasks: generalTasks.where((t) => t.isCompleted).length,
          totalTasks: generalTasks.length,
        ),
      );
    }

    result.sort((a, b) => b.completedTasks.compareTo(a.completedTasks));
    return result;
  }

  static List<AchievementMilestone> _buildMilestones({
    required ProductivityAnalytics overallStats,
    required int bestStreak,
    required int completedProjectsCount,
    int completedHardTasksCount = 0,
    int completedExamsCount = 0,
    bool isStudentMode = false,
  }) {
    final isEn = ArabicFormatters.useEnglish;
    final completed = overallStats.completedTasks;
    final focusMin = overallStats.focusMinutes;
    final sessionsCount = overallStats.completedFocusSessions;

    return [
      AchievementMilestone(
        id: 'first_step',
        title: isEn ? 'First Step' : 'أول خطوة',
        subtitle: isEn ? 'Complete your first task' : 'أنهِ أول مهمة ليك',
        progressLabel: isEn
            ? '${completed.clamp(0, 1)}/1'
            : '${ArabicFormatters.toArabicDigits(completed.clamp(0, 1))}/١',
        progressRatio: completed >= 1 ? 1.0 : 0.0,
        unlocked: completed >= 1,
        iconKind: MilestoneIconKind.firstStep,
      ),
      AchievementMilestone(
        id: 'focus_hour',
        title: isEn ? 'Focus Hour' : 'ساعة تركيز',
        subtitle: isEn ? '60 total focus minutes' : '٦٠ دقيقة تركيز متجمعة',
        progressLabel: isEn
            ? '${focusMin.clamp(0, 60)}/60m'
            : '${ArabicFormatters.toArabicDigits(focusMin.clamp(0, 60))}/٦٠ د',
        progressRatio: (focusMin / 60).clamp(0.0, 1.0),
        unlocked: focusMin >= 60,
        iconKind: MilestoneIconKind.deepFocus,
      ),
      AchievementMilestone(
        id: 'steady_streak',
        title: isEn ? 'Steady Rhythm' : 'نَفَس ثابت',
        subtitle: isEn ? '3-day active streak' : '٣ أيام إنجاز متواصلة',
        progressLabel: isEn
            ? '${bestStreak.clamp(0, 3)}/3 days'
            : '${ArabicFormatters.toArabicDigits(bestStreak.clamp(0, 3))}/٣ أيام',
        progressRatio: (bestStreak / 3).clamp(0.0, 1.0),
        unlocked: bestStreak >= 3,
        iconKind: MilestoneIconKind.streak,
      ),
      AchievementMilestone(
        id: 'hard_task_crusher',
        title: isEn ? 'Hard Task Crusher' : 'قاهر الصعاب',
        subtitle: isEn
            ? 'Finish 3 high/urgent priority tasks'
            : 'أنهِ ٣ مهام صعبة أو عاجلة',
        progressLabel: isEn
            ? '${completedHardTasksCount.clamp(0, 3)}/3 hard'
            : '${ArabicFormatters.toArabicDigits(completedHardTasksCount.clamp(0, 3))}/٣ صعبة',
        progressRatio: (completedHardTasksCount / 3).clamp(0.0, 1.0),
        unlocked: completedHardTasksCount >= 3,
        iconKind: MilestoneIconKind.hardTaskCrusher,
      ),
      AchievementMilestone(
        id: 'focus_marathon',
        title: isEn ? 'Deep Focus' : 'تركيز عميق',
        subtitle: isEn ? '5 sessions or 150 minutes' : '٥ جلسات أو ١٥٠ دقيقة',
        progressLabel: isEn
            ? '${sessionsCount.clamp(0, 5)}/5 sessions'
            : '${ArabicFormatters.toArabicDigits(sessionsCount.clamp(0, 5))}/٥ جلسات',
        progressRatio:
            ((sessionsCount / 5).clamp(0.0, 1.0) > (focusMin / 150).clamp(0.0, 1.0))
                ? (sessionsCount / 5).clamp(0.0, 1.0)
                : (focusMin / 150).clamp(0.0, 1.0),
        unlocked: sessionsCount >= 5 || focusMin >= 150,
        iconKind: MilestoneIconKind.marathon,
      ),
      AchievementMilestone(
        id: 'ten_tasks',
        title: isEn ? 'Ten Done' : 'عشرة منجزة',
        subtitle: isEn ? 'Finish 10 tasks successfully' : 'كمّل ١٠ مهام بنجاح',
        progressLabel: isEn
            ? '${completed.clamp(0, 10)}/10'
            : '${ArabicFormatters.toArabicDigits(completed.clamp(0, 10))}/١٠',
        progressRatio: (completed / 10).clamp(0.0, 1.0),
        unlocked: completed >= 10,
        iconKind: MilestoneIconKind.tenTasks,
      ),
      AchievementMilestone(
        id: 'project_finisher',
        title: isEn ? 'Project Champion' : 'بطل المشروعات',
        subtitle: isEn
            ? 'Complete a full project or 5 focus hours'
            : 'أنهِ مشروع كامل أو ٥ ساعات تركيز',
        progressLabel: completedProjectsCount >= 1
            ? (isEn ? 'Done' : 'مكتمل')
            : (isEn
                ? '${focusMin.clamp(0, 300)}/300m'
                : '${ArabicFormatters.toArabicDigits(focusMin.clamp(0, 300))}/٣٠٠ د'),
        progressRatio: completedProjectsCount >= 1
            ? 1.0
            : (focusMin / 300).clamp(0.0, 1.0),
        unlocked: completedProjectsCount >= 1 || focusMin >= 300,
        iconKind: MilestoneIconKind.finisher,
      ),
      if (isStudentMode)
        AchievementMilestone(
          id: 'exam_hero',
          title: isEn ? 'Exam & Grade Hero' : 'بطل الامتحانات والتقدير',
          subtitle: isEn
              ? 'Complete an exam or record your grade'
              : 'أنهِ امتحان أو سجّل تقديرك الدراسي',
          progressLabel: completedExamsCount >= 1
              ? (isEn ? 'Unlocked' : 'مفتوح')
              : (isEn ? '0/1 exam' : '٠/١ امتحان'),
          progressRatio: completedExamsCount >= 1 ? 1.0 : 0.25,
          unlocked: completedExamsCount >= 1,
          iconKind: MilestoneIconKind.examHero,
        ),
    ];
  }

  static (String, String) _buildEncouragement({
    required String firstName,
    required AnalyticsGranularity granularity,
    required ProductivityAnalytics periodStats,
    required ProductivityAnalytics overallStats,
    required int streak,
    required String? peakDayLabel,
  }) {
    final isEn = ArabicFormatters.useEnglish;
    final cleanName = ArabicFormatters.trData(firstName);
    if (!overallStats.hasData) {
      return isEn
          ? (
              'Your space is ready, $cleanName',
              'Any small task you finish or focus session you start will show up here and build real momentum for your day and week.',
            )
          : (
              'مساحتك جاهزة يا $firstName',
              'أي مهمة صغيرة تخلصها أو جلسة تركيز تبدأها هتظهر هنا وتبنيلك تتابع حقيقي ليومك وأسبوعك.',
            );
    }
    if (streak >= 3) {
      return isEn
          ? (
              'Amazing consistency, $cleanName!',
              'You have kept a steady rhythm for $streak days in a row. Take it one step at a time and stay calm.',
            )
          : (
              'استمرارية هايلة يا $firstName!',
              'ماشي على وتيرة حلوة بقى لك ${ArabicFormatters.toArabicDigits(streak)} أيام ورا بعض. خد خطوة واحدة في المرة وحافظ على هدوءك.',
            );
    }
    if (periodStats.completedTasks >= 3 || periodStats.focusMinutes >= 60) {
      if (isEn) {
        final peakHint = peakDayLabel == null
            ? ''
            : ' Your most active day was $peakDayLabel.';
        return (
          'Real progress, $cleanName',
          'You completed ${periodStats.completedTasks} tasks and logged ${ArabicFormatters.durationCompact(periodStats.focusMinutes)} of focus.$peakHint Every step counts.',
        );
      }
      final peakHint = peakDayLabel == null
          ? ''
          : ' وأكتر يوم نشيط عندك كان $peakDayLabel.';
      return (
        'إنجاز ملموس يا $firstName',
        'خلصت ${ArabicFormatters.toArabicDigits(periodStats.completedTasks)} مهام وسجلت ${ArabicFormatters.durationCompact(periodStats.focusMinutes)} تركيز$peakHint كل خطوة بتفرق.',
      );
    }
    if (periodStats.totalTasks > 0 && periodStats.completedTasks == 0) {
      final openCount = periodStats.totalTasks - periodStats.completedTasks;
      return isEn
          ? (
              'One step breaks the ice, $cleanName',
              'You have $openCount open tasks. Pick the smallest one and start with 15 minutes of focus.',
            )
          : (
              'خطوة واحدة تكسر الحاجز يا $firstName',
              'عندك ${ArabicFormatters.toArabicDigits(openCount)} مهام مفتوحة، اختار أصغر واحدة بس وابدأ بتركيز ١٥ دقيقة.',
            );
    }
    if (isEn) {
      return switch (granularity) {
        AnalyticsGranularity.day => (
            'Calm start, $cleanName',
            'You still have room to win the day. Focus on just one task now and the rest will follow.',
          ),
        AnalyticsGranularity.week => (
            'Balanced week, $cleanName',
            'Your total focus this week is ${ArabicFormatters.durationCompact(periodStats.focusMinutes)}, and every session adds up.',
          ),
        AnalyticsGranularity.month => (
            'Broader view of your progress, $cleanName',
            'Your total progress reached ${overallStats.completedTasks} tasks and ${ArabicFormatters.durationCompact(overallStats.focusMinutes)} of focus.',
          ),
      };
    }
    return switch (granularity) {
      AnalyticsGranularity.day => (
          'بداية هادية يا $firstName',
          'عندك لسه مساحة تكسب اليوم. ركّز على مهمة واحدة بس دلوقتي والباقي ييجي بعدها.',
        ),
      AnalyticsGranularity.week => (
          'أسبوع متوازن يا $firstName',
          'إجمالي تركيزك الأسبوع ده ${ArabicFormatters.durationCompact(periodStats.focusMinutes)}، وكل جلسة بتضيف لرصيدك.',
        ),
      AnalyticsGranularity.month => (
          'صورة أوسع لتقدّمك يا $firstName',
          'إجمالي إنجازك وصل لـ ${ArabicFormatters.toArabicDigits(overallStats.completedTasks)} مهام و${ArabicFormatters.durationCompact(overallStats.focusMinutes)} تركيز.',
        ),
    };
  }

  static String _dayKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';
}
