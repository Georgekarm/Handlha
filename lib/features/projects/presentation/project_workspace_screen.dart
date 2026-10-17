import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/quick_add_bottom_sheet.dart';

enum _WorkspaceTab { overview, tasks, phases, activity, analytics }

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
    this.projectGoal = 'تجربة مريحة لتنظيم اليوم والبدء بهدوء.',
    this.dateRange = '٣١ أكتوبر ٢٠٢٦',
    this.accentColor,
  });

  @override
  State<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen> {
  _WorkspaceTab _currentTab = _WorkspaceTab.overview;
  int _selectedPhaseDetail = 0; // 0: list, 1: detail view for phase 2 (Page 23)
  String _activityFilter = 'الكل';

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
    final primaryColor = widget.accentColor ?? (isDark ? AppColors.darkPrimary : AppColors.primary);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar: Back arrow -> "المشاريع" on right, Options "..." on left
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.more_horiz_rounded, color: textColor, size: 20),
                      onPressed: () {},
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'المشاريع',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textSecColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: Icon(Icons.chevron_right_rounded, color: textSecColor, size: 24),
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  // Title & Description
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      widget.projectTitle,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      widget.projectGoal,
                      style: TextStyle(fontSize: 13.5, color: textSecColor),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Status Card: "على المسار" • "٣١ أكتوبر ٢٠٢٦" • "٦ من ١٢ مهمة خلصوا" • "٥٠٪"
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 50% Circular Progress
                        SizedBox(
                          width: 58,
                          height: 58,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: 0.50,
                                strokeWidth: 4.5,
                                backgroundColor: isDark ? AppColors.darkDivider : AppColors.divider,
                                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                              ),
                              Text(
                                '٥٠٪',
                                style: TextStyle(
                                  fontSize: 14.5,
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1D3B35) : const Color(0xFFE2F3EF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'على المسار',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.dateRange,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '٦ من ١٢ مهمة خلصوا',
                              style: TextStyle(fontSize: 12, color: textSecColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 5 Workspace Tabs: [التحليلات] [النشاط] [المراحل] [المهام] [نظرة عامة]
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true, // RTL order
                    child: Row(
                      children: [
                        _buildTabButton('نظرة عامة', _WorkspaceTab.overview, isDark, primaryColor),
                        const SizedBox(width: 8),
                        _buildTabButton('المهام', _WorkspaceTab.tasks, isDark, primaryColor),
                        const SizedBox(width: 8),
                        _buildTabButton('المراحل', _WorkspaceTab.phases, isDark, primaryColor),
                        const SizedBox(width: 8),
                        _buildTabButton('النشاط', _WorkspaceTab.activity, isDark, primaryColor),
                        const SizedBox(width: 8),
                        _buildTabButton('التحليلات', _WorkspaceTab.analytics, isDark, primaryColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tab View Bodies
                  switch (_currentTab) {
                    _WorkspaceTab.overview => _buildOverviewTab(surfaceColor, borderColor, textColor, textSecColor, textMutedColor, primaryColor, isDark),
                    _WorkspaceTab.tasks => _buildTasksTab(surfaceColor, borderColor, textColor, textSecColor, textMutedColor, primaryColor, isDark),
                    _WorkspaceTab.phases => _buildPhasesTab(surfaceColor, borderColor, textColor, textSecColor, textMutedColor, primaryColor, isDark),
                    _WorkspaceTab.activity => _buildActivityTab(surfaceColor, borderColor, textColor, textSecColor, textMutedColor, primaryColor, isDark),
                    _WorkspaceTab.analytics => _buildAnalyticsTab(surfaceColor, borderColor, textColor, textSecColor, textMutedColor, primaryColor, isDark),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, _WorkspaceTab tab, bool isDark, Color primaryColor) {
    final active = _currentTab == tab;
    final activeBg = isDark ? const Color(0xFF1F3530) : const Color(0xFFC7E6DE);
    final inactiveBg = isDark ? AppColors.darkSurface : Colors.white;
    final activeText = isDark ? AppColors.darkPrimary : AppColors.primaryStrong;
    final inactiveText = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return InkWell(
      onTap: () {
        setState(() {
          _currentTab = tab;
          _selectedPhaseDetail = 0;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? (isDark ? AppColors.darkPrimary.withValues(alpha: 0.4) : AppColors.primary.withValues(alpha: 0.4))
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? activeText : inactiveText,
          ),
        ),
      ),
    );
  }

  // Tab 1: نظرة عامة (Page 6 & Page 42)
  Widget _buildOverviewTab(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color textSecColor,
    Color textMutedColor,
    Color primaryColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card "خطوتك الجاية • أولوية عالية"
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'خطوتك الجاية • أولوية عالية',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textSecColor),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'مراجعة تدفق المهام وتجربة المستخدم',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                '١٢:٠٠ م • ٢٥ دقيقة • طاقة متوسطة',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, color: textSecColor),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.push('/focus-session', extra: 'مراجعة تدفق المهام وتجربة المستخدم');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('ابدأ الخطوة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white)),
                    const SizedBox(width: 8),
                    Icon(Icons.play_arrow_rounded, size: 20, color: isDark ? AppColors.darkBackground : Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section "التجربة والاختبار" (٢ من ٤)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('٢ من ٤', style: TextStyle(fontSize: 13, color: textSecColor, fontWeight: FontWeight.bold)),
            Text(
              'التجربة والاختبار',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 4 Stepper Pills
        Row(
          children: [
            _buildStepPill('لاحقًا', false, isDark, textMutedColor),
            const SizedBox(width: 6),
            _buildStepPill('لاحقًا', false, isDark, textMutedColor),
            const SizedBox(width: 6),
            _buildStepPill('الحالية', true, isDark, primaryColor),
            const SizedBox(width: 6),
            _buildStepPill('اكتملت', false, isDark, textSecColor),
          ],
        ),
        const SizedBox(height: 16),

        // Caution Card (Flag)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'خلي بالك: تأجيل الاختبار بعد ٢٠ أكتوبر هيقلل وقت التحسين قبل الإطلاق.',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, color: textColor, height: 1.45),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.flag_outlined, color: AppColors.salmonBadge, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Suggestion Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : const Color(0xFFF3F7F5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            'اقتراح: راجع شاشة المهام الأول. أي تغيير في خطتك محتاج تأكيدك.',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12.5, color: textSecColor, height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _buildStepPill(String label, bool isCurrent, bool isDark, Color color) {
    return Expanded(
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: isCurrent
              ? (isDark ? const Color(0xFF1D3B35) : const Color(0xFFC7E6DE))
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent ? color : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  // Tab 2: المهام (Page 21)
  Widget _buildTasksTab(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color textSecColor,
    Color textMutedColor,
    Color primaryColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter chips row
        Row(
          children: [
            InkWell(
              onTap: () => QuickAddBottomSheet.show(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkPrimarySoft : const Color(0xFFE2F3EF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('+ إضافة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor)),
              ),
            ),
            const Spacer(),
            _buildSmallChip('الحالة والأولوية', surfaceColor, borderColor, textColor),
            const SizedBox(width: 6),
            _buildSmallChip('حسب المرحلة', surfaceColor, borderColor, textColor),
          ],
        ),
        const SizedBox(height: 16),

        // Phase 1 section: التجربة والاختبار ٢ / ٤
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('٢ / ٤', style: TextStyle(fontSize: 13, color: textSecColor, fontWeight: FontWeight.bold)),
            Text('التجربة والاختبار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
          ],
        ),
        const SizedBox(height: 10),

        _buildWorkspaceTaskRow('مراجعة تدفق المهام وتجربة المستخدم', 'اليوم، ١٢:٠٠ م • ٢٥ دقيقة', 'أولوية عالية • طاقة متوسطة', false, surfaceColor, borderColor, textColor, textSecColor, primaryColor),
        const SizedBox(height: 8),
        _buildWorkspaceTaskRow('إعداد جلسة الاختبار التفاعلية', '١٦ أكتوبر • ١:٠٠ م • ٣٠ دقيقة', 'أولوية متوسطة • طاقة متوسطة', false, surfaceColor, borderColor, textColor, textSecColor, primaryColor),
        const SizedBox(height: 8),
        _buildWorkspaceTaskRow('تجهيز سيناريوهات الاختبار', 'مكتملة • ١٥ أكتوبر', '', true, surfaceColor, borderColor, textColor, textSecColor, primaryColor),
        const SizedBox(height: 8),
        _buildWorkspaceTaskRow('تحديد المشاركين', 'مكتملة • ١٤ أكتوبر', '', true, surfaceColor, borderColor, textColor, textSecColor, primaryColor),

        const SizedBox(height: 24),
        // Phase 2 section: التحسين والإطلاق ٠ / ٤
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('٠ / ٤', style: TextStyle(fontSize: 13, color: textSecColor, fontWeight: FontWeight.bold)),
            Text('التحسين والإطلاق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            'تبدأ بعد اكتمال الاختبار • مرحلة التخطيط مكتملة ٤ / ٤',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12.5, color: textSecColor),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallChip(String label, Color surfaceColor, Color borderColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Text(label, style: TextStyle(fontSize: 11.5, color: textColor, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildWorkspaceTaskRow(
    String title,
    String line1,
    String line2,
    bool isCompleted,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color textSecColor,
    Color primaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isCompleted ? textSecColor : textColor,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              if (line1.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(line1, style: TextStyle(fontSize: 11.5, color: textSecColor)),
              ],
              if (line2.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(line2, style: TextStyle(fontSize: 11.5, color: textSecColor)),
              ],
            ],
          ),
          const SizedBox(width: 12),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isCompleted ? primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isCompleted ? primaryColor : textSecColor, width: 1.5),
            ),
            child: isCompleted ? const Icon(Icons.check_rounded, size: 16, color: Colors.black) : null,
          ),
        ],
      ),
    );
  }

  // Tab 3: المراحل (Page 22 & Page 23)
  Widget _buildPhasesTab(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color textSecColor,
    Color textMutedColor,
    Color primaryColor,
    bool isDark,
  ) {
    if (_selectedPhaseDetail == 1) {
      // Page 23: Phase Detail View ("تفاصيل المرحلة")
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_forward_rounded, color: textColor),
                onPressed: () => setState(() => _selectedPhaseDetail = 0),
              ),
              Text('تفاصيل المرحلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
            ],
          ),
          const SizedBox(height: 16),

          // Header
          Align(
            alignment: Alignment.centerRight,
            child: Text('التجربة والاختبار', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('نتأكد إن ترتيب المهام مفهوم ومريح قبل التحسين.', style: TextStyle(fontSize: 13, color: textSecColor)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('١١ - ٢٠ أكتوبر ٢٠٢٦', style: TextStyle(fontSize: 12, color: textSecColor)),
              Text('٥٠٪ • ٢ من ٤ مهام', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryColor)),
            ],
          ),
          const SizedBox(height: 14),

          // Dependency Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'الاعتماد السابق مكتمل: مرحلة التخطيط والتصميم • ٤ من ٤ مهام',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: textColor),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.link_rounded, color: primaryColor, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Phase Note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تعديل', style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold)),
                    Text('ملاحظة المرحلة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'نختبر مع ٣ أشخاص. نسجّل أماكن التردد، مش بس هل خلصوا المهمة ولا لأ.',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, color: textSecColor, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () => setState(() => _currentTab = _WorkspaceTab.tasks),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('عرض مهام المرحلة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white)),
          ),
        ],
      );
    }

    // Page 22: Connected Phases List
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '٣ مراحل مترابطة • ٦ من ١٢ مهمة مكتملة',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecColor),
          ),
        ),
        const SizedBox(height: 16),

        // Phase 1 Card
        _buildPhaseCard(
          title: 'التخطيط والتصميم',
          status: 'مكتملة',
          dateAndTasks: '١ - ١٠ أكتوبر • ٤ / ٤ مهام',
          desc: 'الهدف والتدفقات الأساسية جاهزين.',
          isCompleted: true,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          textSecColor: textSecColor,
          primaryColor: primaryColor,
          isDark: isDark,
          onTap: () => setState(() => _selectedPhaseDetail = 1),
        ),
        const SizedBox(height: 12),

        // Phase 2 Card
        _buildPhaseCard(
          title: 'التجربة والاختبار',
          status: 'جارية',
          dateAndTasks: '١١ - ٢٠ أكتوبر • ٢ / ٤ مهام',
          desc: 'تعتمد على التخطيط • راجع تدفق المهام أولاً.',
          isCurrent: true,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          textSecColor: textSecColor,
          primaryColor: primaryColor,
          isDark: isDark,
          onTap: () => setState(() => _selectedPhaseDetail = 1),
        ),
        const SizedBox(height: 12),

        // Phase 3 Card
        _buildPhaseCard(
          title: 'التحسين والإطلاق',
          status: 'لم تبدأ',
          dateAndTasks: '٢١ - ٣١ أكتوبر • ٠ / ٤ مهام',
          desc: 'تعتمد على اكتمال جلسة الاختبار.',
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          textSecColor: textSecColor,
          primaryColor: primaryColor,
          isDark: isDark,
          onTap: () => setState(() => _selectedPhaseDetail = 1),
        ),
      ],
    );
  }

  Widget _buildPhaseCard({
    required String title,
    required String status,
    required String dateAndTasks,
    required String desc,
    bool isCompleted = false,
    bool isCurrent = false,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecColor,
    required Color primaryColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? primaryColor.withValues(alpha: 0.6) : borderColor,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? (isDark ? const Color(0xFF1D3B35) : const Color(0xFFE2F3EF))
                      : (isCurrent
                          ? (isDark ? const Color(0xFF28564E) : const Color(0xFFC7E6DE))
                          : (isDark ? AppColors.darkSurface2 : const Color(0xFFEFF3F1))),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isCompleted || isCurrent ? primaryColor : textSecColor,
                  ),
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(dateAndTasks, style: TextStyle(fontSize: 12, color: textSecColor)),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(desc, style: TextStyle(fontSize: 12.5, color: textSecColor)),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Icon(Icons.arrow_back_rounded, size: 16, color: primaryColor),
                const SizedBox(width: 4),
                Text('تفاصيل المرحلة', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: primaryColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tab 4: النشاط (Page 24)
  Widget _buildActivityTab(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color textSecColor,
    Color textMutedColor,
    Color primaryColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter row: [الكل] [أحمد] [المساعد]
        Row(
          children: [
            _buildActivityFilterChip('المساعد', isDark, surfaceColor, borderColor, textColor, primaryColor),
            const SizedBox(width: 8),
            _buildActivityFilterChip('أحمد', isDark, surfaceColor, borderColor, textColor, primaryColor),
            const SizedBox(width: 8),
            _buildActivityFilterChip('الكل', isDark, surfaceColor, borderColor, textColor, primaryColor),
          ],
        ),
        const SizedBox(height: 18),

        // Section: النهارده، ١٦ أكتوبر ٢٠٢٦
        Align(
          alignment: Alignment.centerRight,
          child: Text('النهارده، ١٦ أكتوبر ٢٠٢٦', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecColor)),
        ),
        const SizedBox(height: 10),

        _buildTimelineItem(
          icon: Icons.calendar_today_outlined,
          title: 'أحمد حدّث موعد المراجعة',
          subtitle: 'مراجعة تدفق المهام وتجربة المستخدم',
          time: '١:٠٥ ص',
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          textSecColor: textSecColor,
        ),
        const SizedBox(height: 8),
        _buildTimelineItem(
          icon: Icons.auto_awesome_rounded,
          title: 'المساعد اقترح خطوة تالية',
          subtitle: 'اقتراح فقط • في انتظار تأكيد أحمد',
          time: '٩:٥٠ ص',
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          textSecColor: textSecColor,
          iconColor: AppColors.darkSecondary,
        ),
        const SizedBox(height: 8),
        _buildTimelineItem(
          icon: Icons.flag_outlined,
          title: 'أحمد بدأ مرحلة التجربة والاختبار',
          subtitle: 'المرحلة جارية • ٢ من ٤ مهام مكتملة',
          time: '٩:٣٠ ص',
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          textSecColor: textSecColor,
        ),

        const SizedBox(height: 18),
        // Section: امبارح، ١٥ أكتوبر
        Align(
          alignment: Alignment.centerRight,
          child: Text('امبارح، ١٥ أكتوبر', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecColor)),
        ),
        const SizedBox(height: 10),
        _buildTimelineItem(
          icon: Icons.check_circle_outline_rounded,
          title: 'أحمد أكمل تجهيز سيناريوهات الاختبار',
          subtitle: '٤:٢٠ م • اتحدّث تقدم المشروع إلى ٥٠٪',
          time: '',
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          textSecColor: textSecColor,
          iconColor: primaryColor,
        ),
      ],
    );
  }

  Widget _buildActivityFilterChip(String label, bool isDark, Color surfaceColor, Color borderColor, Color textColor, Color primaryColor) {
    final active = _activityFilter == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activityFilter = label),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: active
                ? (isDark ? const Color(0xFF1F3530) : const Color(0xFFC7E6DE))
                : surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? primaryColor : borderColor),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? primaryColor : textColor)),
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecColor,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          if (time.isNotEmpty)
            Text(time, style: TextStyle(fontSize: 11.5, color: textSecColor)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: textSecColor)),
            ],
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 20, color: iconColor ?? textColor),
        ],
      ),
    );
  }

  // Tab 5: التحليلات (Page 26)
  Widget _buildAnalyticsTab(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color textSecColor,
    Color textMutedColor,
    Color primaryColor,
    bool isDark,
  ) {
    // Project-specific metrics and calendar heatmap (matching Page 26)
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: Icon(Icons.chevron_right_rounded, color: textSecColor), onPressed: () {}),
              Text('أكتوبر ٢٠٢٦', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor)),
              IconButton(icon: Icon(Icons.chevron_left_rounded, color: textSecColor), onPressed: () {}),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['سبت', 'أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'].map((w) => Expanded(
              child: Center(
                child: Text(w, style: TextStyle(fontSize: 11, color: textMutedColor)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 10),

          // Mini Calendar Grid for October
          for (final row in [
            [0, 0, 0, 0, 0, 1, 2],
            [3, 4, 5, 6, 7, 8, 9],
            [10, 11, 12, 13, 14, 15, 16],
            [17, 18, 19, 20, 21, 22, 23],
            [24, 25, 26, 27, 28, 29, 30],
            [31, 0, 0, 0, 0, 0, 0],
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                children: row.map((d) {
                  if (d == 0) return const Expanded(child: SizedBox(height: 38));
                  final isDone = d == 15 || d == 16;
                  final isPast = d <= 16;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDone
                            ? (isDark ? const Color(0xFF28564E) : const Color(0xFF90D0C3))
                            : (d > 16 ? Colors.transparent : (isDark ? AppColors.darkSurface2 : const Color(0xFFEFF3F1))),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: d == 16 ? primaryColor : borderColor.withValues(alpha: 0.4),
                          width: d == 16 ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$d', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                          Text(isPast ? (isDone ? '✓' : '٠') : '—', style: TextStyle(fontSize: 9, color: textMutedColor)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 16),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 12),
          Text('الجمعة ١٦ أكتوبر • النهارده: ٣ مهام مكتملة في المشروع', style: TextStyle(fontSize: 12, color: textSecColor)),
        ],
      ),
    );
  }
}
