import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/quick_add_bottom_sheet.dart';

enum _ProjectTab { active, paused, completed, archived }

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  _ProjectTab _currentTab = _ProjectTab.active;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            // Top Header: + button on left, Title on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add_rounded, color: textColor, size: 24),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const NewProjectSheet(),
                      );
                    },
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'من فكرة لخطوة',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'مشاريعك • ٢ نشطة',
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _searchCtrl,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: '...دوّر على مشروع',
                  hintStyle: TextStyle(color: textMutedColor, fontSize: 13.5),
                  suffixIcon: Icon(Icons.search_rounded, color: textMutedColor, size: 22),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Filter Tabs: [مؤرشفة] [مكتملة] [متوقفة] [نشطة ٢]
            Row(
              children: [
                _buildTab('مؤرشفة', _ProjectTab.archived, isDark),
                const SizedBox(width: 8),
                _buildTab('مكتملة', _ProjectTab.completed, isDark),
                const SizedBox(width: 8),
                _buildTab('متوقفة', _ProjectTab.paused, isDark),
                const SizedBox(width: 8),
                _buildTab('نشطة ٢', _ProjectTab.active, isDark),
              ],
            ),
            const SizedBox(height: 20),

            if (_currentTab == _ProjectTab.active) ...[
              // Project Card 1: "إطلاق نسخة هندلها"
              _ProjectCard(
                title: 'إطلاق نسخة هندلها',
                percent: 50,
                statusTag: 'على المسار',
                targetDate: '٣١ أكتوبر ٢٠٢٦',
                taskCount: '٦ من ١٢ مهمة',
                phaseName: 'التجربة والاختبار',
                nextStep: 'مراجعة تدفق المهام وتجربة المستخدم',
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                textColor: textColor,
                textSecColor: textSecColor,
                primaryColor: primaryColor,
                isDark: isDark,
                onTap: () {
                  context.push(
                    '/project-workspace',
                    extra: {
                      'id': '1',
                      'title': 'إطلاق نسخة هندلها',
                      'goal': 'تجربة مريحة لتنظيم اليوم والبدء بهدوء.',
                    },
                  );
                },
              ),
              const SizedBox(height: 14),

              // Project Card 2: "تنظيم مساحة العمل"
              _ProjectCard(
                title: 'تنظيم مساحة العمل',
                percent: 25,
                targetDate: '٢٥ أكتوبر ٢٠٢٦',
                taskCount: '٢ من ٨ مهام',
                phaseName: 'الترتيب الأولي',
                nextStep: 'ترتيب ملفات المشروع',
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                textColor: textColor,
                textSecColor: textSecColor,
                primaryColor: primaryColor,
                isDark: isDark,
                onTap: () {
                  context.push(
                    '/project-workspace',
                    extra: {
                      'id': '2',
                      'title': 'تنظيم مساحة العمل',
                      'goal': 'تهيئة مكان مريح للتركيز والإنجاز.',
                    },
                  );
                },
              ),
              const SizedBox(height: 20),

              // Button: "+ ابدأ مشروع جديد"
              OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const NewProjectSheet(),
                  );
                },
                icon: Icon(Icons.add_rounded, size: 20, color: textColor),
                label: Text(
                  'ابدأ مشروع جديد',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: borderColor, width: 1.2),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: Text(
                  'مش لازم كل المشاريع تتحرك في نفس الوقت.',
                  style: TextStyle(fontSize: 12, color: textMutedColor),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text('لا توجد مشاريع في هذا التبويب', style: TextStyle(color: textMutedColor)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, _ProjectTab tab, bool isDark) {
    final active = _currentTab == tab;
    final activeBg = isDark ? const Color(0xFF1F3530) : const Color(0xFFC7E6DE);
    final inactiveBg = isDark ? AppColors.darkSurface : Colors.white;
    final activeText = isDark ? AppColors.darkPrimary : AppColors.primaryStrong;
    final inactiveText = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentTab = tab),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: active ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? (isDark ? AppColors.darkPrimary.withValues(alpha: 0.4) : AppColors.primary.withValues(alpha: 0.4))
                  : (isDark ? AppColors.darkBorder : AppColors.border),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? activeText : inactiveText,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final String title;
  final int percent;
  final String? statusTag;
  final String targetDate;
  final String taskCount;
  final String phaseName;
  final String nextStep;
  final Color surfaceColor;
  final Color borderColor;
  final Color textColor;
  final Color textSecColor;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.title,
    required this.percent,
    this.statusTag,
    required this.targetDate,
    required this.taskCount,
    required this.phaseName,
    required this.nextStep,
    required this.surfaceColor,
    required this.borderColor,
    required this.textColor,
    required this.textSecColor,
    required this.primaryColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            // Top line: Status Tag + Title + Circular Progress
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circular progress ring
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: percent / 100,
                        strokeWidth: 3.8,
                        backgroundColor: isDark ? AppColors.darkDivider : AppColors.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                      Text(
                        '$percent٪',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (statusTag != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1D3B35) : const Color(0xFFE2F3EF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusTag!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$targetDate • $taskCount',
                      style: TextStyle(fontSize: 12, color: textSecColor),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Next Step Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : const Color(0xFFF4F8F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.north_west_rounded, size: 16, color: primaryColor),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$phaseName • الخطوة الجاية',
                        style: TextStyle(fontSize: 11, color: textSecColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextStep,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
