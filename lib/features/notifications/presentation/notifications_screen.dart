import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

enum NotificationCategory { reminder, encouragement, focus, important }

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime time;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.time,
    this.isRead = false,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _quietHoursEnabled = true;

  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      title: 'خطوة صغيرة قادمة',
      body: 'فاضل نص ساعة على موعد مراجعة العرض. جاهز تبدأ بهدوء؟',
      category: NotificationCategory.reminder,
      time: DateTime.now().subtract(const Duration(minutes: 20)),
    ),
    NotificationItem(
      id: '2',
      title: 'الله ينور عليك ',
      body: 'خلصت مهمتين أساسيتين في أول النهار. استراحة 5 دقائق تستحقها!',
      category: NotificationCategory.encouragement,
      time: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: true,
    ),
    NotificationItem(
      id: '3',
      title: 'جلسة تركيز مقترحة',
      body: 'فترة ما بعد الظهر مناسبة لجلسة تركيز هادئة مدتها 25 دقيقة.',
      category: NotificationCategory.focus,
      time: DateTime.now().subtract(const Duration(hours: 4)),
      isRead: true,
    ),
    NotificationItem(
      id: '4',
      title: 'مهمة تحتاج إعادة ترتيب',
      body: 'مفيش مشكلة، نعيد ترتيب موعد مهمة "مكالمة المهندس" على قد وقتك المتاح.',
      category: NotificationCategory.important,
      time: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];

  int _selectedTab = 0; // 0=الكل, 1=تذكير, 2=تركيز

  List<NotificationItem> get _filtered {
    if (_selectedTab == 0) return _notifications;
    final cat = [
      null,
      NotificationCategory.reminder,
      NotificationCategory.focus,
    ][_selectedTab];
    return _notifications.where((n) => n.category == cat).toList();
  }

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تعليم كل التنبيهات كـ مقروءة بنجاح'),
        backgroundColor: AppColors.primaryDark,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(
      () => setState(() => _selectedTab = _tabController.index),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final quietHoursLabel = _quietHoursEnabled ? 'مفعّلة' : 'متوقفة';

    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      appBar: AppBar(
            automaticallyImplyLeading: true,
        title: Row(
          children: [
            const Text('تنبيهاتك'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkPrimarySoft
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              style: TextButton.styleFrom(foregroundColor: primaryColor),
              child: const Text('تعليم الكل كمقروء'),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            labelColor: primaryColor,
            unselectedLabelColor: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
            indicatorColor: primaryColor,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'الكل'),
              Tab(text: 'تذكير'),
              Tab(text: 'تركيز'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // شريط ساعات الهدوء (Quiet Hours)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.nightlight_round_outlined,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ساعات الهدوء: $quietHoursLabel',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'مش هتوصلك إشعارات بين 10:00 م و7:00 ص',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _quietHoursEnabled,
                  activeThumbColor: primaryColor,
                  onChanged: (v) => setState(() => _quietHoursEnabled = v),
                ),
              ],
            ),
          ),

          // قائمة التنبيهات
          Expanded(
            child: _filtered.isEmpty
                ? _EmptyNotifView()
                : ListView.builder(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      16,
                      8,
                      16,
                      MediaQuery.of(context).padding.bottom + 100,
                    ),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) => _NotificationCard(
                      notif: _filtered[i],
                      onTap: () {
                        setState(() {
                          _filtered[i].isRead = true;
                        });
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// بطاقة التنبيه بألوان الهوية الهادئة (Calm Notification Card)
// ---------------------------------------------------------------------------
class _NotificationCard extends StatelessWidget {
  final NotificationItem notif;
  final VoidCallback onTap;

  const _NotificationCard({required this.notif, required this.onTap});

  // ألوان الحالات حسب نظام Calm Productivity
  Color _badgeBgColor(bool isDark) {
    if (isDark) {
      return switch (notif.category) {
        NotificationCategory.reminder => AppColors.darkWarning.withValues(alpha: 0.18),
        NotificationCategory.encouragement => AppColors.darkSuccess.withValues(alpha: 0.18),
        NotificationCategory.focus => AppColors.darkSecondary.withValues(alpha: 0.18),
        NotificationCategory.important => AppColors.darkDanger.withValues(alpha: 0.18),
      };
    }
    return switch (notif.category) {
      NotificationCategory.reminder => AppColors.warningSoft,
      NotificationCategory.encouragement => AppColors.successSoft,
      NotificationCategory.focus => AppColors.focusSoft,
      NotificationCategory.important => AppColors.dangerSoft,
    };
  }

  Color _badgeTextColor(bool isDark) {
    if (isDark) {
      return switch (notif.category) {
        NotificationCategory.reminder => AppColors.darkWarning,
        NotificationCategory.encouragement => AppColors.darkSuccess,
        NotificationCategory.focus => AppColors.darkSecondary,
        NotificationCategory.important => AppColors.darkDanger,
      };
    }
    return switch (notif.category) {
      NotificationCategory.reminder => AppColors.warning,
      NotificationCategory.encouragement => AppColors.success,
      NotificationCategory.focus => AppColors.focus,
      NotificationCategory.important => AppColors.danger,
    };
  }

  IconData _icon() {
    return switch (notif.category) {
      NotificationCategory.reminder => Icons.notifications_none_rounded,
      NotificationCategory.encouragement => Icons.favorite_border_rounded,
      NotificationCategory.focus => Icons.spa_outlined,
      NotificationCategory.important => Icons.info_outline_rounded,
    };
  }

  String _categoryLabel() {
    return switch (notif.category) {
      NotificationCategory.reminder => 'تذكير لطيف',
      NotificationCategory.encouragement => 'تشجيع',
      NotificationCategory.focus => 'تركيز',
      NotificationCategory.important => 'تنبيه مهم',
    };
  }

  String _timeLabel() {
    final diff = DateTime.now().difference(notif.time);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'البارحة';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.isRead
                ? borderColor
                : primaryColor.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : AppColors.textPrimary)
                  .withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _badgeBgColor(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon(), color: _badgeTextColor(isDark), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _badgeBgColor(isDark),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _categoryLabel(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _badgeTextColor(isDark),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeLabel(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: notif.isRead
                          ? FontWeight.w500
                          : FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textSecondary,
                      height: 1.4,
                    ),
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

// ---------------------------------------------------------------------------
// الحالة الفارغة (Empty State)
// ---------------------------------------------------------------------------
class _EmptyNotifView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primaryDark,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'مفيش تنبيهات جديدة',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'كل شيء هادئ ومنظم. يومك ماشي بسلاسة',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
