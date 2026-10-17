import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _tabIndex = 0; // 0: الكل, 1: غير المقروءة ٢

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            // Top App Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.done_all_rounded, color: textSecColor),
                  onPressed: () {},
                ),
                Column(
                  children: [
                    Text(
                      'الإشعارات',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                    ),
                    Text(
                      'تذكير في وقته، مش طول الوقت',
                      style: TextStyle(fontSize: 12, color: textSecColor),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded, color: textSecColor, size: 26),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Tabs: [الكل] [غير المقروءة ٢]
            Row(
              children: [
                Expanded(
                  child: _buildNotificationTab('غير المقروءة ٢', _tabIndex == 1, () {
                    setState(() => _tabIndex = 1);
                  }, isDark, surfaceColor, borderColor, primaryColor, textColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildNotificationTab('الكل', _tabIndex == 0, () {
                    setState(() => _tabIndex = 0);
                  }, isDark, surfaceColor, borderColor, primaryColor, textColor),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Date & Clear Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {},
                  child: Text('مسح الكل', style: TextStyle(fontSize: 12.5, color: textSecColor, fontWeight: FontWeight.bold)),
                ),
                Text(
                  'النهارده، ١٦ أكتوبر',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textSecColor),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Notification Card 1: خطوتك الأولى جاهزة
            _buildNotificationCard(
              icon: Icons.access_time_rounded,
              title: 'خطوتك الأولى جاهزة',
              subtitle: 'مراجعة تدفق المهام وتجربة المستخدم • تبدأ ١٢:٠٠ م',
              timeAndStatus: 'من ٥ دقائق • غير مقروء',
              isUnread: true,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              textSecColor: textSecColor,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 10),

            // Notification Card 2: باقي ١٥ يوم على إطلاق هندلها
            _buildNotificationCard(
              icon: Icons.folder_outlined,
              title: 'باقي ١٥ يوم على إطلاق هندلها',
              subtitle: 'المشروع على المسار • ٦ من ١٢ مهمة مكتملة',
              timeAndStatus: '٩:٠٠ ص • غير مقروء',
              isUnread: true,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              textSecColor: textSecColor,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 10),

            // Notification Card 3: جلسة امبارح كانت خطوة كويسة
            if (_tabIndex == 0) ...[
              _buildNotificationCard(
                icon: Icons.timer_outlined,
                title: 'جلسة امبارح كانت خطوة كويسة',
                subtitle: '٢٥ دقيقة تركيز. اختار خطوة مناسبة لطاقتك النهارده.',
                timeAndStatus: '٨:٣٠ ص • مقروء',
                isUnread: false,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                textColor: textColor,
                textSecColor: textSecColor,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 18),
            ],

            // Info Card: ليه الإشعار ده؟
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.assistantPurpleSoft : const Color(0xFFF3F0FA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'ليه الإشعار ده؟',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.auto_awesome_rounded, color: AppColors.darkSecondary, size: 18),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'بنقترح التذكير حسب الموعد اللي اخترته وأولوية المهمة، من غير إضافة مهام أو تغيير خطتك.',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12.5, color: textSecColor, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Quiet Hours Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'وقت الهدوء: ١٠:٠٠ م - ٨:٠٠ ص',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textSecColor),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.nightlight_round_outlined, color: textSecColor, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Demo button to test permission modal (Page 33)
            Center(
              child: TextButton.icon(
                onPressed: () => _showPermissionModal(context),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('معاينة طلب إذن الإشعارات'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTab(
    String label,
    bool active,
    VoidCallback onTap,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color primaryColor,
    Color textColor,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? (isDark ? const Color(0xFF1F3530) : const Color(0xFFC7E6DE))
              : surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? primaryColor : borderColor),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? primaryColor : textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String timeAndStatus,
    required bool isUnread,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecColor,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUnread)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
            ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12.5, color: textSecColor),
              ),
              const SizedBox(height: 6),
              Text(
                timeAndStatus,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: textSecColor),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 22, color: primaryColor),
        ],
      ),
    );
  }

  // Page 33: Notification Permission Modal
  void _showPermissionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final bgColor = isDark ? AppColors.darkSurface : Colors.white;
        final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
        final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
        final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
        final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface2 : const Color(0xFFEFF5F3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_none_rounded, color: primaryColor, size: 36),
                  ),
                ),
                const SizedBox(height: 18),

                Text(
                  'نفتكرك في الوقت المناسب؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                ),
                const SizedBox(height: 10),
                Text(
                  'اسمح بالإشعارات عشان مواعيد المهام وجلسات التركيز. تقدر تغيّر اختيارك في أي وقت من إعدادات الموبايل.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: textSecColor, height: 1.45),
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface2 : const Color(0xFFF4F8F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.nightlight_round_outlined, size: 20, color: primaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'وقت الهدوء محفوظ: من ١٠:٠٠ م لـ ٨:٠٠ ص • مش هنبعت تذكيرات في الفترة دي.',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 12, color: textColor, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('السماح بالإشعارات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white)),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textSecColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: borderColor),
                  ),
                  child: const Text('مش دلوقتي', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
