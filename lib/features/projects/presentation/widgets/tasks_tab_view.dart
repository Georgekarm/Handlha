import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class TasksTabView extends StatelessWidget {
  const TasksTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        _buildTaskItem(
          title: 'تحديث نظام الألوان الهادئ',
          isCompleted: true,
        ),
        const SizedBox(height: 12),
        _buildTaskItem(
          title: 'ضبط تدفق الشات والمقترحات',
          isCompleted: true,
        ),
        const SizedBox(height: 12),
        _buildTaskItem(
          title: 'إعداد جلسة التركيز التفاعلية',
          isCompleted: false,
          isUrgent: true,
        ),
      ],
    );
  }

  Widget _buildTaskItem({required String title, required bool isCompleted, bool isUrgent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF2E7D32) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isCompleted ? const Color(0xFF2E7D32) : const Color(0xFFD0D5DD),
                width: 2,
              ),
            ),
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (isUrgent)
            const Icon(Icons.flag_rounded, color: AppColors.danger, size: 24),
        ],
      ),
    );
  }
}
