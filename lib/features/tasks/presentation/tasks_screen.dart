import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../domain/task.dart';
import 'task_providers.dart';

enum _TaskView { today, inbox, completed }

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _TaskView _view = _TaskView.today;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Task> _visibleTasks(List<Task> tasks) {
    final byView = tasks.where((task) {
      switch (_view) {
        case _TaskView.today:
          return task.status != TaskStatus.completed &&
              task.status != TaskStatus.cancelled &&
              task.status != TaskStatus.inbox;
        case _TaskView.inbox:
          return task.status == TaskStatus.inbox;
        case _TaskView.completed:
          return task.status == TaskStatus.completed;
      }
    });
    if (_query.trim().isEmpty) return byView.toList();
    return byView
        .where((task) => task.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  Future<void> _addTask() async {
    final controller = TextEditingController();
    final title = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'مهمة جديدة',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    hintText: 'اكتب المهمة اللي عايز تخلصها…',
                    prefixIcon: Icon(Icons.check_circle_outline_rounded),
                  ),
                  onSubmitted: (value) => Navigator.pop(sheetContext, value),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, controller.text),
                    child: const Text('إضافة المهمة'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (title == null || title.trim().isEmpty) return;
    await ref.read(todayTasksProvider.notifier).createTask(
          title: title.trim(),
          status: _view == _TaskView.today ? TaskStatus.planned : TaskStatus.inbox,
          scheduledStartAt: _view == _TaskView.today ? DateTime.now() : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final taskState = ref.watch(todayTasksProvider);
    final allTasks = taskState.value ?? const <Task>[];
    final tasks = _visibleTasks(allTasks);
    final activeCount = allTasks
        .where((task) => task.status != TaskStatus.completed && task.status != TaskStatus.cancelled)
        .length;
    final completedCount = allTasks.where((task) => task.status == TaskStatus.completed).length;
    final progress = activeCount + completedCount == 0
        ? 0.0
        : completedCount / (activeCount + completedCount);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مهامك', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkPrimary : AppColors.primaryStrong)),
            const SizedBox(height: 4),
            Text('خطوات صغيرة تصنع فرقاً كبيراً', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'بحث',
            onPressed: () async {
              final query = await showSearch<String?>(
                context: context,
                delegate: _TaskSearchDelegate(initialQuery: _query),
              );
              if (query != null) setState(() => _query = query);
            },
            icon: Icon(Icons.search_rounded, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary, size: 28),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: IconButton(
              tooltip: 'إضافة مهمة',
              onPressed: _addTask,
              icon: Icon(Icons.add_rounded, color: isDark ? AppColors.darkBackground : Colors.white, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkPrimaryStrong : AppColors.primaryStrong,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.primarySoft.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(child: _TabButton(label: 'المكتملة', active: _view == _TaskView.completed, onTap: () => setState(() => _view = _TaskView.completed))),
                  Expanded(child: _TabButton(label: 'الوارد', active: _view == _TaskView.inbox, onTap: () => setState(() => _view = _TaskView.inbox))),
                  Expanded(child: _TabButton(label: 'اليوم', active: _view == _TaskView.today, onTap: () => setState(() => _view = _TaskView.today))),
                ],
              ),
            ),
          ),
          if (_view == _TaskView.today) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_todayLabel(), style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  Icon(Icons.calendar_today_outlined, size: 16, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('٪${(progress * 100).toInt()}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                  Text('إنجاز $completedCount من ${activeCount + completedCount}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: isDark ? AppColors.darkDivider : AppColors.primarySoft,
                  valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.darkPrimary : AppColors.primaryStrong),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: taskState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : tasks.isEmpty
                    ? _EmptyTasksView(view: _view, onAdd: _addTask)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _TaskRow(
                            task: task,
                            onToggle: () => ref.read(todayTasksProvider.notifier).completeTask(task.id),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return 'اليوم، ${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? (isDark ? AppColors.darkPrimarySoft : AppColors.primaryStrong) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? (isDark ? AppColors.darkPrimaryStrong : Colors.white) : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            fontWeight: active ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onToggle});
  final Task task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final completed = task.status == TaskStatus.completed;
    final color = _priorityColor(task.priority, isDark);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onToggle,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: completed ? (isDark ? AppColors.darkPrimary : AppColors.primaryStrong) : (isDark ? AppColors.darkBorder : AppColors.border), width: completed ? 12 : 2),
              ),
              child: completed ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    decoration: completed ? TextDecoration.lineThrough : null,
                    color: completed ? (isDark ? AppColors.darkTextMuted : AppColors.textMuted) : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('11:00 ص - 12:00 م', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 12)),
                    const Spacer(),
                    Icon(Icons.flag_rounded, size: 16, color: color),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _duration(Task task) => task.estimatedDurationMinutes == null
      ? 'من غير مدة'
      : '${task.estimatedDurationMinutes} د';

  static String _priorityLabel(TaskPriority priority) => switch (priority) {
        TaskPriority.urgent => 'عاجلة',
        TaskPriority.high => 'عالية',
        TaskPriority.medium => 'متوسطة',
        TaskPriority.low => 'منخفضة',
      };

  static Color _priorityColor(TaskPriority priority, bool isDark) => switch (priority) {
        TaskPriority.urgent || TaskPriority.high => isDark ? AppColors.darkDanger : AppColors.accent,
        TaskPriority.medium => isDark ? AppColors.darkSecondary : AppColors.secondary,
        TaskPriority.low => isDark ? AppColors.darkPrimary : AppColors.primary,
      };
}

class _EmptyTasksView extends StatelessWidget {
  const _EmptyTasksView({required this.view, required this.onAdd});
  final _TaskView view;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInbox = view == _TaskView.inbox;
    final title = isInbox
        ? 'لو في حاجة شاغلة بالك، حطّها في الوارد.'
        : view == _TaskView.completed
            ? 'لسه مفيش مهام مكتملة.'
            : 'يومك لسه فاضي من المهام.';
    final subtitle = isInbox ? 'كل فكرة تستحق مكانها.' : 'ابدأ بخطوة صغيرة على قد وقتك.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(color: isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft, shape: BoxShape.circle),
              child: Icon(Icons.note_add_outlined, color: isDark ? AppColors.darkPrimaryStrong : AppColors.primaryStrong, size: 34),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            if (view != _TaskView.completed) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAdd, 
                icon: const Icon(Icons.add_rounded), 
                label: const Text('إضافة مهمة'),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkPrimaryStrong : AppColors.primaryStrong,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskSearchDelegate extends SearchDelegate<String?> {
  _TaskSearchDelegate({required this.initialQuery}) {
    query = initialQuery;
  }
  final String initialQuery;

  @override
  String get searchFieldLabel => 'ابحث عن مهمة';
  @override
  TextStyle? get searchFieldStyle => const TextStyle(fontSize: 16);
  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => query = ''),
      ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => close(context, null),
      );
  @override
  Widget buildResults(BuildContext context) => _closeWithQuery(context);
  @override
  Widget buildSuggestions(BuildContext context) => _closeWithQuery(context);

  Widget _closeWithQuery(BuildContext context) => Center(
        child: TextButton.icon(
          onPressed: () => close(context, query),
          icon: const Icon(Icons.search_rounded),
          label: Text(query.isEmpty ? 'اكتب كلمة للبحث' : 'عرض النتائج عن «$query»'),
        ),
      );
}
