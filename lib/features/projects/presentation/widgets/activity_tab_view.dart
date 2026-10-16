import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

enum ActivityActor { user, ai }

class ActivityEventItem {
  final String id;
  final ActivityActor actor;
  final String title;
  final String description;
  final String timestamp;
  final IconData icon;

  ActivityEventItem({
    required this.id,
    required this.actor,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
  });
}

/// تبويب النشاط (Activity Tab)
class ActivityTabView extends StatefulWidget {
  const ActivityTabView({super.key});

  @override
  State<ActivityTabView> createState() => _ActivityTabViewState();
}

class _ActivityTabViewState extends State<ActivityTabView> {
  int _selectedFilter = 0; // 0: الكل, 1: أنا, 2: المساعد

  late List<ActivityEventItem> _events;

  @override
  void initState() {
    super.initState();
    _events = [
      ActivityEventItem(
        id: '1',
        actor: ActivityActor.user,
        title: 'أنهيت إعداد قاعدة البيانات وتجهيز الجداول',
        description: 'تم إنشاء الجداول المحلية باستخدام SQLite وضبط النماذج الأساسية.',
        timestamp: 'اليوم، 02:15 م',
        icon: Icons.check_circle_outline_rounded,
      ),
      ActivityEventItem(
        id: '2',
        actor: ActivityActor.ai,
        title: 'تم اقتراح ترتيب جديد للمهام',
        description: 'بناءً على وتيرة إنجازك لمهام الواجهات، تم إعادة ترتيب أولوية مرحلة المصادقة لتوفير ساعة تركيز.',
        timestamp: 'اليوم، 11:30 ص',
        icon: Icons.auto_awesome_rounded,
      ),
      ActivityEventItem(
        id: '3',
        actor: ActivityActor.ai,
        title: 'اكتشاف عائق: تأخر اعتماد التصميم النهائي',
        description: 'تأخر اعتماد نسخة التصميم النهائية من العميل أثر على موعد بدء ربط الـ API.',
        timestamp: 'أمس، 04:00 م',
        icon: Icons.warning_amber_rounded,
      ),
      ActivityEventItem(
        id: '4',
        actor: ActivityActor.user,
        title: 'أضفت مهمة: اختبار استجابة الشاشات على الآيباد',
        description: 'أضيفت إلى مرحلة الاختبار والإطلاق التجريبي بتقدير 1.5 ساعة.',
        timestamp: 'أمس، 01:10 م',
        icon: Icons.add_task_rounded,
      ),
      ActivityEventItem(
        id: '5',
        actor: ActivityActor.ai,
        title: 'اكتمال التقسيم التلقائي لمرحلة الاختبار',
        description: 'تم تحويل هدف الاختبار إلى 4 خطوات عملية محددة المدة والأولويات.',
        timestamp: 'منذ يومين، 10:00 ص',
        icon: Icons.psychology_alt_rounded,
      ),
      ActivityEventItem(
        id: '6',
        actor: ActivityActor.user,
        title: 'بدأت مشروع تطبيق Flutter',
        description: 'تحديد الهدف الأساسي: إطلاق أول نسخة تجريبية من التطبيق بنجاح.',
        timestamp: '١ سبتمبر ٢٠٢٦',
        icon: Icons.flag_circle_outlined,
      ),
    ];
  }

  List<ActivityEventItem> get _filteredEvents {
    if (_selectedFilter == 1) {
      return _events.where((e) => e.actor == ActivityActor.user).toList();
    }
    if (_selectedFilter == 2) {
      return _events.where((e) => e.actor == ActivityActor.ai).toList();
    }
    return _events;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayedEvents = _filteredEvents;

    return Column(
      children: [
        // 1. الفلاتر العلوية: (الكل، أنا، المساعد)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: AppColors.surface,
          child: Row(
            children: [
              Text(
                'تصفية السجل:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              _buildFilterChip('الكل', 0),
              const SizedBox(width: 8),
              _buildFilterChip('أنا 👤', 1),
              const SizedBox(width: 8),
              _buildFilterChip('الذكاء الاصطناعي 🌿', 2),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),

        // 2. الخط الزمني (Timeline)
        Expanded(
          child: displayedEvents.isEmpty
              ? Center(
                  child: Text(
                    'لا يوجد نشاط مسجل في هذا القسم',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    20,
                    16,
                    20,
                    MediaQuery.of(context).padding.bottom + 100,
                  ),
                  itemCount: displayedEvents.length,
                  itemBuilder: (context, i) {
                    final event = displayedEvents[i];
                    final isLast = i == displayedEvents.length - 1;
                    return _buildTimelineItem(event, isLast, theme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(ActivityEventItem event, bool isLast, ThemeData theme) {
    final isAi = event.actor == ActivityActor.ai;
    final badgeColor = isAi ? AppColors.primaryDark : AppColors.focus;
    final badgeBg = isAi ? AppColors.primarySoft : AppColors.focusSoft;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline Column with Icon Node and line
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeBg,
                shape: BoxShape.circle,
                border: Border.all(color: badgeColor, width: 1.5),
              ),
              child: Icon(event.icon, size: 16, color: badgeColor),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 80,
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 14),

        // Event Details Card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isAi ? AppColors.surface : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAi ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
                width: isAi ? 1.2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isAi ? 'الذكاء الاصطناعي' : 'أنت',
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      event.timestamp,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
