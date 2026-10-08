import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _smartInputCtrl = TextEditingController();
  bool _isListening = false;

  @override
  void dispose() {
    _smartInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleDumpIdea() async {
    final text = _smartInputCtrl.text.trim();
    if (text.isEmpty) return;

    _smartInputCtrl.clear();
    FocusScope.of(context).unfocus();

    await ref.read(todayTasksProvider.notifier).createTask(title: text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم حفظ الفكرة في الوارد وجاهزة للتنظيم'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkPrimary
              : AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _toggleMic() {
    setState(() => _isListening = !_isListening);
    if (_isListening) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          _smartInputCtrl.text = 'مراجعة أول 5 شرائح من العرض التقديمي في 20 دقيقة بعد الظهر';
          _isListening = false;
        });
      });
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return '${days[now.weekday - 1]}، ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).value;
    final userName = user?.displayName;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 90,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getFormattedDate(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(userName != null && userName.isNotEmpty ? 'صباح الخير يا $userName' : 'صباح الخير', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            const Text('يوم جديد، مستوى أفضل.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 28),
            onPressed: () {},
          ),
          InkWell(
            onTap: () => context.push('/settings'),
            child: Container(
              margin: const EdgeInsetsDirectional.only(end: 16, start: 8),
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(userName != null && userName.isNotEmpty ? userName[0] : 'ي', style: const TextStyle(color: AppColors.primaryStrong, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.read(todayTasksProvider.notifier).refresh(),
              color: AppColors.primaryStrong,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  const SizedBox(height: 16),
                  const Text('نخلّص خطوة واحدة دلوقتي.', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primaryDark, height: 1.2)),
                  const SizedBox(height: 6),
                  const Text('التركيز على خطوة صغيرة اليوم يصنع فرق كبير.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  
                  // Big Task Card
                  _NextTaskCard(),

                  const SizedBox(height: 32),
                  
                  // Priorities Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('أولويات النهار', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      TextButton(
                        onPressed: () {}, 
                        child: const Row(
                          children: [
                            Text('عرض الكل', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            Icon(Icons.chevron_left_rounded, size: 16, color: AppColors.textSecondary),
                          ],
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Task List
                  _TodayTasksList(),
                ],
              ),
            ),
          ),
          
          // Bottom Input Bar
          _BottomInputBar(
            controller: _smartInputCtrl,
            isListening: _isListening,
            onToggleMic: _toggleMic,
            onSubmit: _handleDumpIdea,
          ),
        ],
      ),
    );
  }
}

class _NextTaskCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F2F0),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المهمة التالية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.track_changes_rounded, color: AppColors.primaryStrong, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('مراجعة العرض التقديمي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 4),
              Text('٢٠ دقيقة', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryStrong,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {}, 
                child: const Row(
                  children: [
                    Text('ابدأ التركيز', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    SizedBox(width: 4),
                    Icon(Icons.play_arrow_rounded, size: 18),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('٢ من ٤', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryStrong)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildDot(true),
                      _buildDot(true),
                      _buildDot(false),
                      _buildDot(false),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool active) {
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 4),
      width: 16,
      height: 4,
      decoration: BoxDecoration(
        color: active ? AppColors.primaryStrong : AppColors.primaryStrong.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _TodayTasksList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayTasksProvider);
    final tasks = state.value ?? [];
    
    final displayTasks = tasks.where((t) => t.status != TaskStatus.completed).toList();
    
    if (displayTasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('لا توجد مهام اليوم', style: TextStyle(color: AppColors.textMuted))),
      );
    }
    
    return Column(
      children: displayTasks.take(3).map((task) => _TaskTile(task: task)).toList(),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_indicator_rounded, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.flag_rounded, size: 16, color: _getPriorityColor(task.priority)),
                    const SizedBox(width: 8),
                    const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${task.estimatedDurationMinutes ?? 20} دقيقة', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getPriorityColor(TaskPriority priority) {
    switch(priority) {
      case TaskPriority.urgent:
      case TaskPriority.high: return AppColors.danger;
      case TaskPriority.medium: return AppColors.accent; 
      case TaskPriority.low: return AppColors.primaryStrong;
    }
  }
}

class _BottomInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final VoidCallback onToggleMic;
  final VoidCallback onSubmit;

  const _BottomInputBar({
    required this.controller,
    required this.isListening,
    required this.onToggleMic,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.background,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onToggleMic,
            icon: Icon(isListening ? Icons.mic_rounded : Icons.mic_none_rounded, color: isListening ? (isDark ? AppColors.darkDanger : AppColors.danger) : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'اكتب اللي في دماغك...',
                hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted, fontSize: 14),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onSubmit,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkPrimary : AppColors.primaryStrong,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, color: isDark ? AppColors.darkBackground : Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
