import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/handelha_brand.dart';
import '../../../core/result/result.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _quickAddController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _quickAddController.dispose();
    super.dispose();
  }

  Future<void> _saveQuickTask() async {
    final title = _quickAddController.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    final result = await ref.read(todayTasksProvider.notifier).createTask(title: title);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is Success<Task>) {
      _quickAddController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اتضافت للوارد. خطوة حلوة!'), behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ماقدرناش نضيف المهمة دلوقتي.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final tasksState = ref.watch(todayTasksProvider);
    final tasks = tasksState.value ?? const <Task>[];
    final pending = tasks.where((task) =>
        task.status != TaskStatus.completed && task.status != TaskStatus.cancelled).toList();
    final nextTask = pending.isEmpty ? null : pending.first;
    final done = tasks.where((task) => task.status == TaskStatus.completed).length;
    final greeting = _greeting();
    final savedName = ref.watch(authNotifierProvider).value?.displayName?.trim();
    final displayName = (savedName == null || savedName.isEmpty) ? 'صديقي' : savedName;
    final avatarLetter = displayName.substring(0, 1);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 80,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 22,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HandelhaLogo(markSize: 26, fontSize: 16, dark: isDark),
            const SizedBox(height: 4),
            Text(_dateLabel(), style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 22),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => context.push('/settings'),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft,
                child: Text(avatarLetter, style: TextStyle(color: isDark ? AppColors.darkPrimaryStrong : AppColors.primaryStrong, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
        children: [
          Text('$greeting يا $displayName!', style: TextStyle(fontSize: 26, height: 1.25, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkPrimary : AppColors.primaryStrong)),
          const SizedBox(height: 6),
          Text('نبدأ بإيه الأول النهارده؟', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          _ProgressCard(completed: done, total: tasks.length),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddTaskDialog(context),
            icon: Icon(Icons.add_rounded, color: isDark ? AppColors.darkBackground : Colors.white),
            label: Text('إضافة مهمة جديدة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkBackground : Colors.white)),
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkPrimaryStrong : AppColors.primaryStrong, 
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white, 
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: Text('مهام النهارده', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
              TextButton(
                onPressed: () => context.go('/tasks'),
                child: Text('الكل', style: TextStyle(color: isDark ? AppColors.darkPrimary : AppColors.primaryStrong, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasksState.isLoading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (pending.isEmpty)
            _EmptyPriorities(onTap: () => _showAddTaskDialog(context))
          else
            ...pending.map((task) => _PriorityTaskCard(task: task, onDone: () => ref.read(todayTasksProvider.notifier).completeTask(task.id))),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('مهمة جديدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                const SizedBox(height: 16),
                TextField(
                  controller: _quickAddController,
                  autofocus: true,
                  style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'اكتب اسم المهمة هنا...',
                    hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                  ),
                  onSubmitted: (_) {
                    Navigator.pop(context);
                    _saveQuickTask();
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _saveQuickTask();
                  },
                  style: FilledButton.styleFrom(backgroundColor: isDark ? AppColors.darkPrimaryStrong : AppColors.primaryStrong, minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text('إضافة المهمة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkBackground : Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الفل';
    if (hour < 17) return 'مساء الفل';
    return 'مساء الفل';
  }

  String _dateLabel() {
    final now = DateTime.now();
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return 'اليوم، ${now.day} ${months[now.month - 1]}';
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.completed, required this.total});
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: [
          BoxShadow(color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0x0A000000), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('إنجازك النهارده', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextSecondary : AppColors.textPrimary)),
              Text('$percentage٪', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkPrimary : AppColors.primaryStrong)),
            ],
          ),
          const SizedBox(height: 8),
          Text(total == 0 ? 'ضيف مهام عشان تبدأ' : '$completed مهام خلصوا من أصل $total', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: isDark ? AppColors.darkDivider : AppColors.primarySoft,
              valueColor: AlwaysStoppedAnimation(isDark ? AppColors.darkPrimary : AppColors.primaryStrong),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityTaskCard extends StatelessWidget {
  const _PriorityTaskCard({required this.task, required this.onDone});
  final Task task;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final color = switch (task.priority) {
      TaskPriority.urgent || TaskPriority.high => isDark ? AppColors.darkDanger : AppColors.danger,
      TaskPriority.medium => isDark ? AppColors.darkSecondary : AppColors.accent,
      TaskPriority.low => isDark ? AppColors.darkPrimary : AppColors.primaryStrong,
    };
    
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
            onTap: onDone,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border, width: 2),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.schedule_rounded, size: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary), 
                  const SizedBox(width: 4), 
                  Text('11:00 ص - 12:00 م', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 12)), 
                  const Spacer(), 
                  Icon(Icons.flag_rounded, size: 16, color: color),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPriorities extends StatelessWidget {
  const _EmptyPriorities({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border)),
        child: Row(children: [Icon(Icons.add_task_rounded, color: isDark ? AppColors.darkPrimary : AppColors.primary, size: 28), const SizedBox(width: 12), Expanded(child: Text('مفيش أولويات لسه. حط أول حاجة في دماغك في الوارد.', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontWeight: FontWeight.w600)))]),
      ),
    );
  }
}
