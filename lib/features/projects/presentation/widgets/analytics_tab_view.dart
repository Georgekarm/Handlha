import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import 'smart_add_task_sheet.dart';

enum AnalyticsDataState { full, partial, empty }

/// تبويب التحليلات (Analytics Tab) مع دعم الحالات الثلاث
class AnalyticsTabView extends StatefulWidget {
  const AnalyticsTabView({super.key});

  @override
  State<AnalyticsTabView> createState() => _AnalyticsTabViewState();
}

class _AnalyticsTabViewState extends State<AnalyticsTabView> {
  AnalyticsDataState _currentState = AnalyticsDataState.full;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // State Switcher (بيانات كاملة / جزئية / لا توجد بيانات)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'حالة البيانات:',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('كاملة', style: TextStyle(fontSize: 11)),
                        selected: _currentState == AnalyticsDataState.full,
                        selectedColor: AppColors.primarySoft,
                        onSelected: (_) => setState(() => _currentState = AnalyticsDataState.full),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('جزئية', style: TextStyle(fontSize: 11)),
                        selected: _currentState == AnalyticsDataState.partial,
                        selectedColor: AppColors.primarySoft,
                        onSelected: (_) => setState(() => _currentState = AnalyticsDataState.partial),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('فارغة', style: TextStyle(fontSize: 11)),
                        selected: _currentState == AnalyticsDataState.empty,
                        selectedColor: AppColors.primarySoft,
                        onSelected: (_) => setState(() => _currentState = AnalyticsDataState.empty),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Render view according to state
          switch (_currentState) {
            AnalyticsDataState.full => _buildFullDataState(theme),
            AnalyticsDataState.partial => _buildPartialDataState(theme),
            AnalyticsDataState.empty => _buildEmptyDataState(theme),
          },
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // الحالة الأولى: بيانات كاملة (Full Data)
  // ---------------------------------------------------------------------------
  Widget _buildFullDataState(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. أرقام بارزة (KPI Cards)
        Row(
          children: [
            Expanded(
              child: _KpiStatCard(
                title: 'نسبة الإنجاز الإجمالية',
                value: '62%',
                subtitle: 'ماشي حسب الخطة',
                icon: Icons.pie_chart_outline_rounded,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiStatCard(
                title: 'المهام المكتملة',
                value: '18 / 29',
                subtitle: '8 متبقية • 3 متأخرة',
                icon: Icons.task_alt_rounded,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _KpiStatCard(
          title: 'الوقت المنفذ في المشروع',
          value: '15س 20د',
          subtitle: 'من أصل 24 ساعة مخططة • باقي 8س 40د',
          icon: Icons.timer_outlined,
          color: AppColors.focus,
          isFullWidth: true,
        ),

        const SizedBox(height: 20),

        // 2. الرسم البياني الخطي (Line Chart): مقارنة التقدم الفعلي بالخطة المتوقعة
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مقارنة التقدم بمرور الوقت',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      _ChartLegendItem(label: 'الفعلي', color: AppColors.primaryDark, isDashed: false),
                      const SizedBox(width: 12),
                      _ChartLegendItem(label: 'المتوقع', color: AppColors.textMuted, isDashed: true),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Canvas Custom Line Chart
              SizedBox(
                height: 170,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ProgressLineChartPainter(),
                ),
              ),
              const SizedBox(height: 8),
              // Weeks axis labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('أسبوع 1', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  Text('أسبوع 2', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  Text('أسبوع 3', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  Text('أسبوع 4 (الآن)', style: TextStyle(fontSize: 10, color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                  Text('أسبوع 6', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  Text('أسبوع 8', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 3. رسوم بيانية تفصيلية: توزيع المهام حسب الحالة والتقدم حسب المرحلة
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'توزيع المهام حسب الحالة',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              // Segmented horizontal distribution bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 18,
                  child: Row(
                    children: [
                      // Completed (18/29 = 62%)
                      Expanded(
                        flex: 62,
                        child: Container(color: AppColors.success),
                      ),
                      // In Progress (8/29 = 28%)
                      Expanded(
                        flex: 28,
                        child: Container(color: AppColors.warning),
                      ),
                      // Delayed (3/29 = 10%)
                      Expanded(
                        flex: 10,
                        child: Container(color: AppColors.danger),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _StatBadgeMini(label: 'مكتملة (62%)', color: AppColors.success),
                  _StatBadgeMini(label: 'قيد التنفيذ (28%)', color: AppColors.warning),
                  _StatBadgeMini(label: 'متأخرة (10%)', color: AppColors.danger),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 14),

              // التقدم والمخطط مقابل الفعلي لكل مرحلة
              Text(
                'المخطط مقابل الفعلي لكل مرحلة (ساعات العمل)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _PhaseComparisonRow(phase: 'التخطيط', actualHours: '5س', plannedHours: '4س', percent: 1.0),
              const SizedBox(height: 10),
              _PhaseComparisonRow(phase: 'التصميم', actualHours: '7س', plannedHours: '6س', percent: 0.75),
              const SizedBox(height: 10),
              _PhaseComparisonRow(phase: 'التطوير', actualHours: '9س', plannedHours: '10س', percent: 0.50),
              const SizedBox(height: 10),
              _PhaseComparisonRow(phase: 'الاختبار', actualHours: '2س', plannedHours: '4س', percent: 0.20),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 4. قسم "أسباب التأخير"
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_off_outlined, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'أسباب التأخير والعوائق المرصودة',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DelayReasonCard(
                title: 'اعتماديات منتظرة وقرارات معلقة',
                detail: 'تأخر اعتماد نسخة التصميم النهائية من العميل أوقف بدء ربط واجهات تسجيل الدخول لمدة 4 أيام.',
                impact: '+4 أيام تأخير',
              ),
              const SizedBox(height: 10),
              _DelayReasonCard(
                title: 'تقدير وقت أقل من اللازم',
                detail: 'استغرقت مراجعة الواجهات وتوحيد نظام الألوان وقتاً إضافياً غير محسوب في التخطيط الأولي.',
                impact: '+3 ساعات إضافية',
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 5. بطاقة "ملاحظة ذكية" (Smart AI Insight)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primarySoft.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملاحظة ذكية مبنية على تحليلاتك:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '«لاحظت إن المهام اللي تقديرها أكبر من ساعة بتتأخر بنسبة 35% مقارنة بغيرها. نصيحتي الهادئة نقسم أي مهمة كبيرة لخطوات مركزة ما تزيدش عن 45 دقيقة.»',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // الحالة الثانية: بيانات جزئية (Partial Data)
  // ---------------------------------------------------------------------------
  Widget _buildPartialDataState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.query_stats_rounded,
              color: AppColors.info,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'لسه بنجمع صورة أوضح عن الشغل',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'بيتم حالياً عرض ملخص نوعي بسيط لتجنب عرض نسب غير دقيقة قبل اكتمال مهام كافية في المراحل الأولى.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Progress collecting bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('اكتمال بيانات المشروع:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    Text('40%', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.40,
                    minHeight: 6,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'أكمل مهمتين إضافيتين لفتح الرسم البياني الخطي ومعدل المقارنة التنبؤي.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // الحالة الثالثة: لا توجد بيانات (Empty Data)
  // ---------------------------------------------------------------------------
  Widget _buildEmptyDataState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: AppColors.textMuted,
              size: 42,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'ابدأ الشغل علشان التحليلات تظهر هنا',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'مفيش بيانات كفاية لسه... مع أول مهام تنجزها سيبدأ رصد مسارك وإعطاء نصائح هادية ومفيدة.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => SmartAddTaskBottomSheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة أول مهمة +'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isFullWidth;

  const _KpiStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDashed;

  const _ChartLegendItem({required this.label, required this.color, required this.isDashed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _StatBadgeMini extends StatelessWidget {
  final String label;
  final Color color;

  const _StatBadgeMini({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _PhaseComparisonRow extends StatelessWidget {
  final String phase;
  final String actualHours;
  final String plannedHours;
  final double percent;

  const _PhaseComparisonRow({
    required this.phase,
    required this.actualHours,
    required this.plannedHours,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(phase, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            Text('الفعلي: $actualHours / المخطط: $plannedHours', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(
              percent >= 1.0 ? AppColors.success : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DelayReasonCard extends StatelessWidget {
  final String title;
  final String detail;
  final String impact;

  const _DelayReasonCard({required this.title, required this.detail, required this.impact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  impact,
                  style: const TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter for the smooth Line Chart comparing Actual vs Expected
class _ProgressLineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 0.8;

    // Draw horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Expected line points (from left to right in RTL, canvas origin is top-left)
    // In RTL, we draw from width to 0
    final expectedPoints = [
      Offset(size.width, size.height * 0.95),
      Offset(size.width * 0.8, size.height * 0.80),
      Offset(size.width * 0.6, size.height * 0.65),
      Offset(size.width * 0.4, size.height * 0.45),
      Offset(size.width * 0.2, size.height * 0.25),
      Offset(0, size.height * 0.05),
    ];

    final expectedPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final expectedPath = Path()..moveTo(expectedPoints[0].dx, expectedPoints[0].dy);
    for (int i = 1; i < expectedPoints.length; i++) {
      expectedPath.lineTo(expectedPoints[i].dx, expectedPoints[i].dy);
    }
    canvas.drawPath(expectedPath, expectedPaint);

    // Actual progress points up to current week (Week 4: 62% progress)
    final actualPoints = [
      Offset(size.width, size.height * 0.95),
      Offset(size.width * 0.8, size.height * 0.82),
      Offset(size.width * 0.6, size.height * 0.58),
      Offset(size.width * 0.4, size.height * 0.38), // Week 4
    ];

    // Gradient fill under the actual curve
    final fillPath = Path()..moveTo(actualPoints[0].dx, size.height);
    fillPath.lineTo(actualPoints[0].dx, actualPoints[0].dy);
    for (int i = 1; i < actualPoints.length; i++) {
      fillPath.lineTo(actualPoints[i].dx, actualPoints[i].dy);
    }
    fillPath.lineTo(actualPoints.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.25),
          AppColors.primary.withValues(alpha: 0.01),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Actual line stroke
    final actualPaint = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final actualPath = Path()..moveTo(actualPoints[0].dx, actualPoints[0].dy);
    for (int i = 1; i < actualPoints.length; i++) {
      actualPath.lineTo(actualPoints[i].dx, actualPoints[i].dy);
    }
    canvas.drawPath(actualPath, actualPaint);

    // Draw active dot at current point
    final dotPaint = Paint()..color = AppColors.primaryDark;
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(actualPoints.last, 6, dotPaint);
    canvas.drawCircle(actualPoints.last, 3, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
