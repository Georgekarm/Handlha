import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import 'project_settings_screen.dart';

class ProjectWorkspaceScreen extends StatefulWidget {
  final String projectId;
  final String projectTitle;
  final String projectGoal;
  final String dateRange;
  final Color? accentColor;

  const ProjectWorkspaceScreen({
    super.key,
    this.projectId = '1',
    this.projectTitle = 'إطلاق نسخة هندلها',
    this.projectGoal = 'نشر نسخة تجريبية قابلة للاستخدام.',
    this.dateRange = '١ سبتمبر ٢٠٢٦ - ٣١ أكتوبر ٢٠٢٦',
    this.accentColor,
  });

  @override
  State<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen> {
  int _currentTab = 0;

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectSettingsScreen(
          projectId: widget.projectId,
          initialTitle: widget.projectTitle,
          initialGoal: widget.projectGoal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = widget.accentColor ?? (isDark ? AppColors.darkPrimary : AppColors.primary);
    final primaryStrongColor = widget.accentColor != null 
        ? widget.accentColor!.withValues(alpha: 0.8) 
        : (isDark ? AppColors.darkPrimaryStrong : AppColors.primaryStrong);
    final primarySoftColor = widget.accentColor != null 
        ? widget.accentColor!.withValues(alpha: 0.2) 
        : (isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft);
    
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        toolbarHeight: 60,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'مساحة المشروع',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: textColor),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة مهمة للمشروع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: primaryStrongColor,
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.projectTitle,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: primaryColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.projectGoal,
                    style: TextStyle(fontSize: 14, color: textSecondaryColor, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '18 من 29 مهمة مكتملة',
                        style: TextStyle(fontSize: 13, color: textSecondaryColor, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '٪65',
                        style: TextStyle(fontSize: 16, color: primaryStrongColor, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: 0.65,
                      minHeight: 8,
                      backgroundColor: primarySoftColor,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryStrongColor),
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: primarySoftColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(child: _TabButton(label: 'المهام (11)', active: _currentTab == 0, isDark: isDark, activeColor: primaryStrongColor, onTap: () => setState(() => _currentTab = 0))),
                    Expanded(child: _TabButton(label: 'الأفكار (3)', active: _currentTab == 1, isDark: isDark, activeColor: primaryStrongColor, onTap: () => setState(() => _currentTab = 1))),
                    Expanded(child: _TabButton(label: 'ملاحظات', active: _currentTab == 2, isDark: isDark, activeColor: primaryStrongColor, onTap: () => setState(() => _currentTab = 2))),
                    Expanded(child: _TabButton(label: 'التحليلات', active: _currentTab == 3, isDark: isDark, activeColor: primaryStrongColor, onTap: () => setState(() => _currentTab = 3))),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            if (_currentTab == 0) _buildTasksList(isDark, surfaceColor, borderColor, primaryStrongColor),
            if (_currentTab == 3) _buildAnalyticsTab(isDark, surfaceColor, borderColor, primaryColor, primarySoftColor),
            if (_currentTab == 1 || _currentTab == 2)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('لا توجد بيانات', style: TextStyle(color: textMutedColor)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab(bool isDark, Color surfaceColor, Color borderColor, Color primaryColor, Color primarySoft) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSec = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final gridLineColor = isDark ? AppColors.darkDivider : AppColors.divider;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نظرة عامة على الأداء', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('المنجز', '18', primaryColor, textSec),
                    Container(height: 40, width: 1, color: gridLineColor),
                    _buildStatItem('المتبقي', '11', isDark ? AppColors.darkWarning : AppColors.warning, textSec),
                    Container(height: 40, width: 1, color: gridLineColor),
                    _buildStatItem('ساعات العمل', '24h', isDark ? AppColors.darkInfo : AppColors.info, textSec),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('توزيع الوقت', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 24),
                SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBarChart(0.4, 'السبت', primaryColor, primarySoft, textSec),
                      _buildBarChart(0.7, 'الأحد', primaryColor, primarySoft, textSec),
                      _buildBarChart(1.0, 'الإثنين', primaryColor, primarySoft, textSec),
                      _buildBarChart(0.5, 'الثلاثاء', primaryColor, primarySoft, textSec),
                      _buildBarChart(0.2, 'الأربعاء', primaryColor, primarySoft, textSec),
                      _buildBarChart(0.6, 'الخميس', primaryColor, primarySoft, textSec),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor, Color labelColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: valueColor)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor)),
      ],
    );
  }

  Widget _buildBarChart(double percent, String day, Color color, Color bg, Color labelColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 16,
          height: 100,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 16,
            height: 100 * percent,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTasksList(bool isDark, Color surface, Color border, Color primaryStrong) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _TaskTile(
            title: 'مراجعة تدفق المهام',
            duration: '20 دقيقة',
            isCompleted: false,
            priorityColor: isDark ? AppColors.darkDanger : AppColors.danger,
            isDark: isDark, surfaceColor: surface, borderColor: border, primaryStrongColor: primaryStrong,
          ),
          _TaskTile(
            title: 'إعداد جلسة التركيز التفاعلية',
            duration: '30 دقيقة',
            isCompleted: false,
            priorityColor: isDark ? AppColors.darkAccent : AppColors.accent,
            isDark: isDark, surfaceColor: surface, borderColor: border, primaryStrongColor: primaryStrong,
          ),
          _TaskTile(
            title: 'تحديث نظام الألوان الهادئ',
            duration: '15 دقيقة',
            isCompleted: true,
            priorityColor: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            isDark: isDark, surfaceColor: surface, borderColor: border, primaryStrongColor: primaryStrong,
          ),
          _TaskTile(
            title: 'ضبط تدفق الشات والمقترحات',
            duration: '45 دقيقة',
            isCompleted: true,
            priorityColor: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            isDark: isDark, surfaceColor: surface, borderColor: border, primaryStrongColor: primaryStrong,
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.isDark, required this.activeColor, required this.onTap});
  final String label;
  final bool active;
  final bool isDark;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active 
                ? (isDark ? AppColors.darkBackground : Colors.white) 
                : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            fontWeight: active ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final String title;
  final String duration;
  final bool isCompleted;
  final Color priorityColor;
  final bool isDark;
  final Color surfaceColor;
  final Color borderColor;
  final Color primaryStrongColor;

  const _TaskTile({
    required this.title,
    required this.duration,
    required this.isCompleted,
    required this.priorityColor,
    required this.isDark,
    required this.surfaceColor,
    required this.borderColor,
    required this.primaryStrongColor,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator_rounded, color: borderColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? textMuted : textPrimary,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (!isCompleted) ...[
                      Icon(Icons.flag_rounded, size: 16, color: priorityColor),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.schedule_rounded, size: 14, color: isCompleted ? textMuted : textSecondary),
                    const SizedBox(width: 4),
                    Text(duration, style: TextStyle(fontSize: 12, color: isCompleted ? textMuted : textSecondary)),
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
              color: isCompleted ? primaryStrongColor : Colors.transparent,
              border: Border.all(color: isCompleted ? primaryStrongColor : borderColor, width: 2),
            ),
            child: isCompleted ? Icon(Icons.check_rounded, size: 16, color: isDark ? AppColors.darkBackground : Colors.white) : null,
          ),
        ],
      ),
    );
  }
}
