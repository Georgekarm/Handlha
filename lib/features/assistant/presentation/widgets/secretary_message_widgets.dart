import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme_extension.dart';
import '../../../../shared/utils/arabic_formatters.dart';
import '../../../../shared/widgets/handelha_feedback.dart';
import '../../../notifications/alarm_reminder_store.dart';
import '../../../notifications/native_alarm_bridge.dart';
import '../../../notifications/presentation/alarm_ringing_dialog.dart';
import '../../../notifications/presentation/notification_permission_sheet.dart';
import '../../../tasks/domain/task.dart';

/// Renders assistant responses as rich, interactive "Executive Secretary" widgets
/// (schedule timeline boards, multi-task registration cards, step-by-step roadmaps,
/// and daily briefing cards) instead of plain text walls.
class SecretaryRichMessageBody extends StatelessWidget {
  const SecretaryRichMessageBody({
    super.key,
    required this.content,
    required this.onQuickReply,
    this.isLastAssistant = false,
    this.suggestedTask,
    this.suggestedProjectName,
    this.onStartFocus,
  });

  final String content;
  final ValueChanged<String> onQuickReply;
  final bool isLastAssistant;
  final Task? suggestedTask;
  final String? suggestedProjectName;
  final VoidCallback? onStartFocus;

  @override
  Widget build(BuildContext context) {
    final trimmed = content.trim();

    if (_isScheduleDraft(trimmed)) {
      return _SecretaryScheduleDraftCard(
        rawText: trimmed,
        onQuickReply: onQuickReply,
      );
    }

    if (_isCreatedTasksWithBreakdown(trimmed)) {
      final splitIdx = trimmed.indexOf('أكيد!');
      final enSplitIdx = splitIdx == -1 ? trimmed.indexOf('Sure!') : splitIdx;
      if (enSplitIdx > 0) {
        final createdPart = trimmed.substring(0, enSplitIdx).trim();
        final breakdownPart = trimmed.substring(enSplitIdx).trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SecretaryCreatedTasksCard(
              rawText: createdPart,
              onQuickReply: onQuickReply,
              showActions: false,
            ),
            const SizedBox(height: 12),
            _SecretaryBreakdownCard(
              rawText: breakdownPart,
              onQuickReply: onQuickReply,
            ),
          ],
        );
      }
    }

    if (_isCreatedTasksReply(trimmed)) {
      return _SecretaryCreatedTasksCard(
        rawText: trimmed,
        onQuickReply: onQuickReply,
      );
    }

    if (_isBreakdownReply(trimmed)) {
      return _SecretaryBreakdownCard(
        rawText: trimmed,
        onQuickReply: onQuickReply,
      );
    }

    if (_isTaskListReply(trimmed)) {
      return _SecretaryTaskListCard(
        rawText: trimmed,
        onQuickReply: onQuickReply,
      );
    }

    if (_isAlarmReminderSetupReply(trimmed)) {
      return _SecretaryAlarmReminderCard(
        rawText: trimmed,
        onQuickReply: onQuickReply,
      );
    }

    if (_isCelebrationReply(trimmed)) {
      return _SecretaryCelebrationCard(
        rawText: trimmed,
        onQuickReply: onQuickReply,
      );
    }

    final c = context.appColors;
    return Text(
      trimmed,
      style: TextStyle(
        fontSize: 14.5,
        color: c.textPrimary,
        height: 1.55,
      ),
    );
  }

  bool _isScheduleDraft(String text) =>
      text.contains('مسودة ترتيب المهام') ||
      text.contains('جهّزتلك مسودة الخطة') ||
      text.contains('حدّثت المسودة') ||
      text.contains('Prepared your schedule draft') ||
      text.contains('Updated draft');

  bool _isCreatedTasksWithBreakdown(String text) =>
      _isCreatedTasksReply(text) && _isBreakdownReply(text);

  bool _isCreatedTasksReply(String text) =>
      text.startsWith('تمام، ضفتلك') ||
      text.startsWith('تمام! ضفتلك') ||
      text.startsWith('Added ');

  bool _isBreakdownReply(String text) =>
      (text.contains('خطوات عملية') ||
          text.contains('actionable steps')) &&
      (text.contains('١)') || text.contains('1)'));

  bool _isTaskListReply(String text) =>
      text.startsWith('دي المهام اللي لقيتها عندك:') ||
      text.startsWith('Here are the tasks I found:');

  bool _isAlarmReminderSetupReply(String text) =>
      text.contains('إعداد المنبه والتذكير') ||
      text.contains('Alarm & Reminder Setup');

  bool _isCelebrationReply(String text) =>
      text.contains('وسام') ||
      text.contains('Badge') ||
      text.contains('علّمت على') ||
      (text.contains('Marked "') && text.contains('completed')) ||
      text.startsWith('عاش بجد!') ||
      text.startsWith('عاش عليك!');
}

// =============================================================================
// 1. EXECUTIVE SCHEDULE DRAFT BOARD CARD
// =============================================================================

class _ParsedDraftItem {
  const _ParsedDraftItem({
    required this.index,
    required this.title,
    required this.dateLabel,
    required this.timeRangeLabel,
    required this.durationLabel,
    required this.reason,
  });

  final int index;
  final String title;
  final String dateLabel;
  final String timeRangeLabel;
  final String durationLabel;
  final String reason;
}

class _SecretaryScheduleDraftCard extends StatelessWidget {
  const _SecretaryScheduleDraftCard({
    required this.rawText,
    required this.onQuickReply,
  });

  final String rawText;
  final ValueChanged<String> onQuickReply;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;

    final parsed = _parseDraft(rawText, isEn);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Executive Banner Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                c.heroTeal,
                c.primary,
              ],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn
                          ? 'Executive Schedule Proposal'
                          : 'خطة مكتب السكرتير المقترحة',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      parsed.versionBadge.isNotEmpty
                          ? parsed.versionBadge
                          : (isEn
                              ? '${parsed.items.length} tasks organized by priority'
                              : 'ترتيب ذكي لـ ${ArabicFormatters.toArabicDigits(parsed.items.length)} مهام حسب الأولوية والميعاد'),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isEn
                      ? '${parsed.items.length} Tasks'
                      : '${ArabicFormatters.toArabicDigits(parsed.items.length)} مهام',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Timeline Task Items
        for (var i = 0; i < parsed.items.length; i++) ...[
          _DraftTimelineItemCard(
            item: parsed.items[i],
            isLast: i == parsed.items.length - 1,
            isEn: isEn,
          ),
          if (i < parsed.items.length - 1) const SizedBox(height: 8),
        ],

        // Assumptions & Conflict Alerts
        if (parsed.notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: c.warning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isEn ? 'Secretary Notes & Alerts' : 'ملاحظات وتنبيهات الجدول',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final note in parsed.notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $note',
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Interactive Action Buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => onQuickReply(
                isEn ? 'confirm schedule' : 'اعتمد الخطة',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.textOnPrimary,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.verified_rounded, size: 17),
              label: Text(
                isEn ? 'Confirm & Save Schedule' : 'اعتمد الجدول الآن',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => onQuickReply(
                isEn ? 'make it from 6 to 9 pm' : 'خليه من 6 ل 9 بليل',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primary,
                side: BorderSide(color: c.primary.withValues(alpha: 0.45)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.nights_stay_outlined, size: 16),
              label: Text(
                isEn ? 'Shift to Evening (6–9 PM)' : 'نقل للفترة المسائية',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  ({
    String versionBadge,
    List<_ParsedDraftItem> items,
    List<String> notes,
  }) _parseDraft(String raw, bool isEn) {
    final lines = raw.split('\n');
    String versionBadge = '';
    final items = <_ParsedDraftItem>[];
    final notes = <String>[];

    final verMatch = RegExp(r'\(([^)]+#[a-fA-F0-9]+)\)').firstMatch(raw);
    if (verMatch != null) {
      versionBadge = verMatch.group(1) ?? '';
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final itemMatch = RegExp(
        r'^(\d+)\.\s*(?:«([^»]+)»|"([^"]+)")\s*—\s*(\d{4}-\d{2}-\d{2})\s*(?:الساعة|at)?\s*(\d{2}:\d{2}\.\.\d{2}:\d{2})\s*\(([^)]+)\)',
      ).firstMatch(line);

      if (itemMatch != null) {
        final idx = int.tryParse(itemMatch.group(1) ?? '1') ?? (items.length + 1);
        final title = (itemMatch.group(2) ?? itemMatch.group(3) ?? '').trim();
        final dateStr = itemMatch.group(4) ?? '';
        final timeRange = (itemMatch.group(5) ?? '').replaceAll('..', ' → ');
        final dur = itemMatch.group(6) ?? '';
        var reason = '';
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (nextLine.startsWith('السبب:') || nextLine.startsWith('Reason:')) {
            reason = nextLine
                .replaceFirst(RegExp(r'^(?:السبب:|Reason:)\s*'), '')
                .trim();
            i++;
          }
        }
        items.add(
          _ParsedDraftItem(
            index: idx,
            title: title,
            dateLabel: dateStr,
            timeRangeLabel: timeRange,
            durationLabel: dur,
            reason: reason,
          ),
        );
      } else if (line.startsWith('•')) {
        notes.add(line.substring(1).trim());
      }
    }

    return (versionBadge: versionBadge, items: items, notes: notes);
  }
}

class _DraftTimelineItemCard extends StatelessWidget {
  const _DraftTimelineItemCard({
    required this.item,
    required this.isLast,
    required this.isEn,
  });

  final _ParsedDraftItem item;
  final bool isLast;
  final bool isEn;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isHighPriority =
        item.reason.contains('عالية') || item.reason.toLowerCase().contains('high');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighPriority
              ? c.primary.withValues(alpha: 0.45)
              : c.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  isEn
                      ? '${item.index}'
                      : ArabicFormatters.toArabicDigits(item.index),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: c.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniMetaBadge(
                          icon: Icons.access_time_filled_rounded,
                          label: item.timeRangeLabel,
                          color: c.primary,
                          bgColor: c.primarySoft,
                        ),
                        _MiniMetaBadge(
                          icon: Icons.timer_outlined,
                          label: item.durationLabel,
                          color: c.textSecondary,
                          bgColor: c.surface,
                        ),
                        _MiniMetaBadge(
                          icon: Icons.calendar_today_rounded,
                          label: item.dateLabel,
                          color: c.textSecondary,
                          bgColor: c.surface,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    isHighPriority
                        ? Icons.bolt_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 15,
                    color: isHighPriority ? c.warning : c.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isEn ? 'Why: ${item.reason}' : 'السبب: ${item.reason}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// 2. NEWLY CREATED TASKS CONFIRMATION CARD
// =============================================================================

class _SecretaryCreatedTasksCard extends StatelessWidget {
  const _SecretaryCreatedTasksCard({
    required this.rawText,
    required this.onQuickReply,
    this.showActions = true,
  });

  final String rawText;
  final ValueChanged<String> onQuickReply;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final tasks = _extractTasks(rawText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Secretary Registration Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.task_alt_rounded,
                  size: 18,
                  color: c.textOnPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn
                          ? (tasks.length > 1
                              ? 'Registered ${tasks.length} Separate Tasks'
                              : 'Task Registered in Your Schedule')
                          : (tasks.length > 1
                              ? 'تم تسجيل ${ArabicFormatters.toArabicDigits(tasks.length)} مهام منفصلة في أجندتك'
                              : 'تم تسجيل المهمة في أجندتك بنجاح'),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      isEn
                          ? 'Organized automatically with date & time'
                          : 'مكتب السكرتير قسّم المواعيد وحدد كل مهمة لوحدها',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Individual Created Task Cards
        for (var i = 0; i < tasks.length; i++) ...[
          _CreatedTaskMiniCard(
            index: i + 1,
            title: tasks[i].title,
            whenLabel: tasks[i].when,
            totalCount: tasks.length,
            isEn: isEn,
          ),
          if (i < tasks.length - 1) const SizedBox(height: 8),
        ],

        if (showActions) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: Icon(Icons.auto_fix_high_rounded, size: 16, color: c.primary),
                label: Text(
                  isEn
                      ? (tasks.length > 1 ? 'Break Each Into Steps' : 'Break Into Steps')
                      : (tasks.length > 1 ? 'قسّم كل مهمة لخطوات' : 'قسّمها لخطوات عملية'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.primary,
                  ),
                ),
                backgroundColor: c.primarySoft,
                side: BorderSide(color: c.primary.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onPressed: () => onQuickReply(
                  isEn ? 'break it down into steps' : 'قسمها لخطوات',
                ),
              ),
              ActionChip(
                avatar: Icon(Icons.calendar_month_rounded, size: 16, color: c.textPrimary),
                label: Text(
                  isEn ? 'Organize My Day' : 'رتّب جدولي بالكامل',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                backgroundColor: c.surfaceSoft,
                side: BorderSide(color: c.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onPressed: () => onQuickReply(
                  isEn
                      ? 'Plan and prioritize my tasks for today'
                      : 'رتّب معايا أولويات مهامي النهارده',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<({String title, String when})> _extractTasks(String raw) {
    final out = <({String title, String when})>[];
    final lines = raw.split('\n');

    // Multi-task numbered lines: ١. «امتحان عربي» — بكرة الساعة ٨ صباحًا
    for (final line in lines) {
      final m = RegExp(
        r'^(?:[١٢٣٤٥٦\d]+\.)\s*(?:«([^»]+)»|"([^"]+)")(?:\s*—\s*(.+))?$',
      ).firstMatch(line.trim());
      if (m != null) {
        final title = (m.group(1) ?? m.group(2) ?? '').trim();
        final when = (m.group(3) ?? '').trim();
        if (title.isNotEmpty) {
          out.add((title: title, when: when));
        }
      }
    }
    if (out.isNotEmpty) return out;

    // Single task: تمام، ضفتلك «...» في ميعاد بكرة الساعة ٨ صباحًا.
    final singleAr = RegExp(
      r'«([^»]+)»(?:\s+في\s+ميعاد\s+([^.؟]+))?',
    ).firstMatch(raw);
    if (singleAr != null) {
      return [
        (
          title: (singleAr.group(1) ?? '').trim(),
          when: (singleAr.group(2) ?? '').trim(),
        ),
      ];
    }

    final singleEn = RegExp(
      r'Added\s+"([^"]+)"(?:\s*\(([^)]+)\))?',
    ).firstMatch(raw);
    if (singleEn != null) {
      return [
        (
          title: (singleEn.group(1) ?? '').trim(),
          when: (singleEn.group(2) ?? '').trim(),
        ),
      ];
    }

    return [(title: raw, when: '')];
  }
}

class _CreatedTaskMiniCard extends ConsumerStatefulWidget {
  const _CreatedTaskMiniCard({
    required this.index,
    required this.title,
    required this.whenLabel,
    required this.totalCount,
    required this.isEn,
  });

  final int index;
  final String title;
  final String whenLabel;
  final int totalCount;
  final bool isEn;

  @override
  ConsumerState<_CreatedTaskMiniCard> createState() =>
      _CreatedTaskMiniCardState();
}

class _CreatedTaskMiniCardState extends ConsumerState<_CreatedTaskMiniCard> {
  String _selectedMode = 'alarm';

  Future<void> _setAlertMode(String mode) async {
    setState(() => _selectedMode = mode);
    await ref.read(alarmReminderProvider.notifier).addOrUpdateAlarm(
          title: widget.title,
          scheduledAt: DateTime.now().add(const Duration(hours: 1)),
          alertMode: mode,
        );
    if (!mounted) return;
    HandelhaFeedback.showSuccess(
      context,
      mode == 'alarm'
          ? (widget.isEn
              ? 'Ringing Alarm enabled for "${widget.title}" (Permission granted)'
              : 'تم تفعيل «منبه يرن» لـ «${widget.title}» وتأكيد إذن التنبيهات!')
          : (widget.isEn
              ? 'Notification message enabled for "${widget.title}"'
              : 'تم ضبط «رسالة إشعار» لـ «${widget.title}» في ميعادها!'),
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final whenLabel = widget.whenLabel;
    final title = widget.title;
    final isEn = widget.isEn;
    final index = widget.index;
    final totalCount = widget.totalCount;
    final isEvening = whenLabel.contains('مساء') ||
        whenLabel.contains('بليل') ||
        whenLabel.toLowerCase().contains('pm');
    final isMorning = whenLabel.contains('صباح') ||
        whenLabel.contains('الصبح') ||
        whenLabel.toLowerCase().contains('am');
    final isExamOrStudy = title.contains('امتحان') ||
        title.contains('مذاكر') ||
        title.contains('مراجع') ||
        title.toLowerCase().contains('exam') ||
        title.toLowerCase().contains('study');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isExamOrStudy ? Icons.school_rounded : Icons.event_note_rounded,
                  color: c.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (totalCount > 1) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: c.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isEn
                                  ? '#$index'
                                  : 'مهمة ${ArabicFormatters.toArabicDigits(index)}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: c.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (whenLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _MiniMetaBadge(
                        icon: isEvening
                            ? Icons.nights_stay_rounded
                            : (isMorning
                                ? Icons.wb_sunny_rounded
                                : Icons.schedule_rounded),
                        label: whenLabel,
                        color: isEvening ? c.info : c.primary,
                        bgColor: isEvening
                            ? c.info.withValues(alpha: 0.12)
                            : c.primarySoft,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (whenLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _AlertModePill(
                  icon: Icons.alarm_rounded,
                  label: isEn ? '⏰ Ringing Alarm' : '⏰ منبه يرن',
                  selected: _selectedMode == 'alarm',
                  onTap: () => _setAlertMode('alarm'),
                ),
                _AlertModePill(
                  icon: Icons.notifications_active_outlined,
                  label: isEn ? '🔔 Notification' : '🔔 رسالة إشعار',
                  selected: _selectedMode == 'notification',
                  onTap: () => _setAlertMode('notification'),
                ),
                _AlertModePill(
                  icon: Icons.volume_up_rounded,
                  label: isEn ? 'Test Alarm' : 'تجربة المنبه',
                  selected: false,
                  onTap: () async {
                    if (_selectedMode != 'notification') {
                      final launched =
                          await NativeAlarmBridge.instance.showExternalAlarm(
                        id: 'assistant_preview_${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        isEn: isEn,
                        isPreview: true,
                      );
                      if (launched) return;
                    }
                    if (!context.mounted) return;
                    await HandelhaAlarmRingingDialog.show(
                      context,
                      title: title,
                      scheduledTimeLabel: whenLabel,
                      isNotificationMode: _selectedMode == 'notification',
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertModePill extends StatelessWidget {
  const _AlertModePill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? c.primary : c.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: selected ? c.textOnPrimary : c.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: selected ? c.textOnPrimary : c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3. STEP-BY-STEP BREAKDOWN ROADMAP CARD
// =============================================================================

class _SecretaryBreakdownCard extends StatelessWidget {
  const _SecretaryBreakdownCard({
    required this.rawText,
    required this.onQuickReply,
  });

  final String rawText;
  final ValueChanged<String> onQuickReply;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final sections = _parseSections(rawText, isEn);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_tree_rounded,
                  size: 18,
                  color: c.textOnPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn
                          ? 'Executive Step-by-Step Roadmap'
                          : 'خطة تقسيم الخطوات العملية',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      isEn
                          ? '${sections.length > 1 ? '${sections.length} separate items' : 'Actionable focus blocks'} ready to add'
                          : (sections.length > 1
                              ? 'تم فصل كل مهمة لوحدها بخطوات مذاكرة وتنفيذ مستقلة'
                              : 'خطوات صغيرة ومنظمة عشان تبدأ من غير تشتيت'),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        for (var sIdx = 0; sIdx < sections.length; sIdx++) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bookmark_added_rounded,
                      size: 18,
                      color: c.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sections[sIdx].heading,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final step in sections[sIdx].steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: c.border.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: c.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (sIdx < sections.length - 1) const SizedBox(height: 10),
        ],

        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () => onQuickReply(
            isEn ? 'yes add them' : 'تمام ضيفهم',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: c.textOnPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
          label: Text(
            isEn
                ? 'Add All Steps to My Tasks Today'
                : 'اعتمد وضيف الخطوات دي كمهام النهارده',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  List<({String heading, List<String> steps})> _parseSections(
    String raw,
    bool isEn,
  ) {
    final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final out = <({String heading, List<String> steps})>[];

    String currentHeading = '';
    var currentSteps = <String>[];

    // Check if single-goal header has a quoted title
    final firstQuote = RegExp(r'«([^»]+)»|"([^"]+)"').firstMatch(lines.firstOrNull ?? '');
    if (firstQuote != null) {
      currentHeading = (firstQuote.group(1) ?? firstQuote.group(2) ?? '').trim();
    }

    for (final line in lines) {
      if (line.startsWith('📌')) {
        if (currentSteps.isNotEmpty) {
          out.add((
            heading: currentHeading.isEmpty
                ? (isEn ? 'Action Steps' : 'خطوات التنفيذ')
                : currentHeading,
            steps: currentSteps,
          ));
          currentSteps = <String>[];
        }
        currentHeading = line.replaceFirst('📌', '').trim();
      } else if (RegExp(r'^[١٢٣123]\)').hasMatch(line)) {
        currentSteps.add(line);
      }
    }

    if (currentSteps.isNotEmpty) {
      out.add((
        heading: currentHeading.isEmpty
            ? (isEn ? 'Action Steps' : 'خطوات التنفيذ')
            : currentHeading,
        steps: currentSteps,
      ));
    }

    return out;
  }
}

// =============================================================================
// 4. TASK LIST BRIEFING CARD
// =============================================================================

class _SecretaryTaskListCard extends StatelessWidget {
  const _SecretaryTaskListCard({
    required this.rawText,
    required this.onQuickReply,
  });

  final String rawText;
  final ValueChanged<String> onQuickReply;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.contains('•'))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.folder_special_rounded, size: 18, color: c.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEn ? 'Open Tasks in Your Agenda' : 'المهام المسجلة في أجندتك حاليًا',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MiniMetaBadge extends StatelessWidget {
  const _MiniMetaBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecretaryCelebrationCard extends StatelessWidget {
  const _SecretaryCelebrationCard({
    required this.rawText,
    required this.onQuickReply,
  });

  final String rawText;
  final ValueChanged<String> onQuickReply;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final asksExamGrade = rawText.contains('تقدير كام') || rawText.contains('what grade');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF5A623).withValues(alpha: 0.18),
                c.primarySoft,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFF5A623).withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFD98200),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEn
                      ? 'Well Done — Keep Going'
                      : 'عاش عليك — خطوة تفرّق',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          rawText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
            height: 1.55,
          ),
        ),
        if (asksExamGrade) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickGradeChip(
                icon: Icons.workspace_premium_rounded,
                label: isEn ? 'Got A+ (Excellent)' : 'جبت امتياز',
                onTap: () => onQuickReply(
                  isEn ? 'I got an A+ on the exam' : 'جبت امتياز في الامتحان',
                ),
              ),
              _QuickGradeChip(
                icon: Icons.trending_up_rounded,
                label: isEn ? 'Very Good (B+)' : 'جبت جيد جدا',
                onTap: () => onQuickReply(
                  isEn ? 'I got a B+ on the exam' : 'جبت جيد جدا في الامتحان',
                ),
              ),
              _QuickGradeChip(
                icon: Icons.thumb_up_alt_rounded,
                label: isEn ? 'Good (B)' : 'جبت جيد',
                onTap: () => onQuickReply(
                  isEn ? 'I got a B on the exam' : 'جبت جيد في الامتحان',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuickGradeChip extends StatelessWidget {
  const _QuickGradeChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: c.primarySoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: c.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecretaryAlarmReminderCard extends ConsumerWidget {
  const _SecretaryAlarmReminderCard({
    required this.rawText,
    required this.onQuickReply,
  });

  final String rawText;
  final ValueChanged<String> onQuickReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final alarmState = ref.watch(alarmReminderProvider);
    final quoteMatch = RegExp(r'«([^»]+)»|"([^"]+)"').firstMatch(rawText);
    final extractedTitle =
        (quoteMatch?.group(1) ?? quoteMatch?.group(2) ?? (isEn ? 'Reminder' : 'ميعاد مذاكرة/امتحان'))
            .trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.alarm_add_rounded,
                  color: c.textOnPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn
                          ? 'Smart Alarm & Notification Setup'
                          : 'ضبط المنبه والتنبيهات',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      alarmState.permissionGranted
                          ? (isEn
                              ? 'Notification permission active'
                              : 'إذن الإشعارات والمنبه مفعّل')
                          : (isEn
                              ? 'Requires your permission to ring or notify'
                              : 'يحتاج إذنك لتشغيل المنبه أو إرسال الإشعار'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          rawText,
          style: TextStyle(
            fontSize: 13.5,
            color: c.textPrimary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        // Permission button if not yet granted
        if (!alarmState.permissionGranted) ...[
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await ensureHandelhaNotificationPermission(
                context,
                ref,
                includeExactAlarm: true,
              );
              if (!context.mounted) return;
              if (ok) {
                HandelhaFeedback.showSuccess(
                  context,
                  isEn
                      ? 'Notification & Alarm permission granted!'
                      : 'تم السماح بالإشعارات والمنبهات بنجاح!',
                );
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: c.primary,
              side: BorderSide(color: c.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.verified_user_outlined, size: 17),
            label: Text(
              isEn
                  ? 'Allow Notification & Alarm Permission'
                  : 'السماح بإذن الإشعارات والمنبه الآن',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Mode choice buttons: Ringing Alarm vs Notification Message
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await ensureHandelhaNotificationPermission(
                    context,
                    ref,
                    includeExactAlarm: true,
                  );
                  await ref
                      .read(alarmReminderProvider.notifier)
                      .setDefaultAlertMode('alarm');
                  onQuickReply(
                    isEn ? 'Set as ringing alarm' : 'اعمله منبه يرن',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.alarm_on_rounded, size: 17),
                label: Text(
                  isEn ? 'Ringing Alarm' : 'منبه يرن',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ensureHandelhaNotificationPermission(
                    context,
                    ref,
                    includeExactAlarm: false,
                  );
                  await ref
                      .read(alarmReminderProvider.notifier)
                      .setDefaultAlertMode('notification');
                  onQuickReply(
                    isEn ? 'Set as notification message' : 'اعمله رسالة إشعار',
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.primary,
                  side: BorderSide(color: c.primary.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.notifications_active_outlined, size: 17),
                label: Text(
                  isEn ? 'Message' : 'رسالة إشعار',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => HandelhaAlarmRingingDialog.show(
            context,
            title: extractedTitle,
          ),
          icon: Icon(Icons.volume_up_rounded, size: 17, color: c.primary),
          label: Text(
            isEn
                ? 'Preview Full Alarm Screen & Sound Now'
                : 'معاينة وتجربة شكل وصوت المنبه الآن',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: c.primary,
            ),
          ),
        ),
      ],
    );
  }
}
