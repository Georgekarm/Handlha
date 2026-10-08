import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../features/tasks/domain/task.dart';
import '../../features/tasks/presentation/task_providers.dart';

class QuickAddBottomSheet extends ConsumerStatefulWidget {
  const QuickAddBottomSheet({super.key});

  @override
  ConsumerState<QuickAddBottomSheet> createState() =>
      _QuickAddBottomSheetState();
}

class _QuickAddBottomSheetState extends ConsumerState<QuickAddBottomSheet> {
  final _titleCtrl = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _isLoading = true);
    await ref
        .read(todayTasksProvider.notifier)
        .createTask(title: title, priority: _priority);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('مهمة جديدة', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),

            // Title field
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'وصف المهمة...',
                prefixIcon: Icon(Icons.task_alt_outlined),
              ),
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.done,
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 16),

            // Priority selector
            Text('مستوى الأولوية', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                _PriorityChip(
                  label: 'خفيف',
                  priority: TaskPriority.low,
                  color: AppColors.info,
                  isSelected: _priority == TaskPriority.low,
                  onTap: () => setState(() => _priority = TaskPriority.low),
                ),
                const SizedBox(width: 8),
                _PriorityChip(
                  label: 'عادي',
                  priority: TaskPriority.medium,
                  color: AppColors.primary,
                  isSelected: _priority == TaskPriority.medium,
                  onTap: () => setState(() => _priority = TaskPriority.medium),
                ),
                const SizedBox(width: 8),
                _PriorityChip(
                  label: 'مهم',
                  priority: TaskPriority.high,
                  color: AppColors.warning,
                  isSelected: _priority == TaskPriority.high,
                  onTap: () => setState(() => _priority = TaskPriority.high),
                ),
                const SizedBox(width: 8),
                _PriorityChip(
                  label: 'عاجل',
                  priority: TaskPriority.urgent,
                  color: AppColors.danger,
                  isSelected: _priority == TaskPriority.urgent,
                  onTap: () => setState(() => _priority = TaskPriority.urgent),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.surface,
                        ),
                      )
                    : Text('إضافة المهمة ✓', style: theme.textTheme.labelLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final TaskPriority priority;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.priority,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isSelected ? color : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
