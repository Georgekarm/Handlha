import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/theme_controller.dart';
import '../../authentication/presentation/auth_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _assistantTone = 'هادي ومشجّع';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final surface2 = isDark ? AppColors.darkSurface2 : const Color(0xFFF3F7F5);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    final currentThemeMode = ref.watch(themeModeProvider);

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
                  icon: Icon(Icons.tune_rounded, color: textSecColor),
                  onPressed: () {},
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'على طريقتك',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'الإعدادات',
                      style: TextStyle(fontSize: 12.5, color: textSecColor),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded, color: textSecColor, size: 26),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Profile Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text('الملف الشخصي', style: TextStyle(fontSize: 12, color: textSecColor)),
                          const SizedBox(width: 14),
                          Text(
                            'أحمد',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ahmed@handelha.app',
                        style: TextStyle(fontSize: 13, color: textSecColor),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: surface2,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_outline_rounded, color: primaryColor, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: التجربة اللي تناسبك
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'التجربة اللي تناسبك',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  // نبرة المساعد
                  _buildSettingRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'نبرة المساعد',
                    trailing: Text(_assistantTone, style: TextStyle(fontSize: 13, color: textSecColor)),
                    textColor: textColor,
                    textSecColor: textSecColor,
                    borderColor: borderColor,
                    onTap: () => _pickTone(context),
                  ),
                  Divider(color: borderColor, height: 1),

                  // المظهر (فاتح / داكن / النظام)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('المظهر', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildThemeSegment('النظام', currentThemeMode == ThemeMode.system, () {
                              ref.read(themeModeProvider.notifier).setMode(ThemeMode.system);
                            }, isDark, primaryColor, borderColor, textColor),
                            const SizedBox(width: 8),
                            _buildThemeSegment('داكن', currentThemeMode == ThemeMode.dark, () {
                              ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
                            }, isDark, primaryColor, borderColor, textColor),
                            const SizedBox(width: 8),
                            _buildThemeSegment('فاتح', currentThemeMode == ThemeMode.light, () {
                              ref.read(themeModeProvider.notifier).setMode(ThemeMode.light);
                            }, isDark, primaryColor, borderColor, textColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(color: borderColor, height: 1),

                  // الإشعارات
                  _buildSettingRow(
                    icon: Icons.notifications_none_rounded,
                    title: 'الإشعارات',
                    trailing: Text(_notificationsEnabled ? 'مفعّلة' : 'متوقفة', style: TextStyle(fontSize: 13, color: textSecColor)),
                    textColor: textColor,
                    textSecColor: textSecColor,
                    borderColor: borderColor,
                    onTap: () => setState(() => _notificationsEnabled = !_notificationsEnabled),
                  ),
                  Divider(color: borderColor, height: 1),

                  // وقت الهدوء
                  _buildSettingRow(
                    icon: Icons.nightlight_round_outlined,
                    title: 'وقت الهدوء',
                    trailing: Text('١٠:٠٠ م - ٨:٠٠ ص', style: TextStyle(fontSize: 13, color: textSecColor)),
                    textColor: textColor,
                    textSecColor: textSecColor,
                    borderColor: borderColor,
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: الخصوصية والبيانات
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'الخصوصية والبيانات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _buildSettingRow(
                    icon: Icons.info_outline_rounded,
                    title: 'عن هندلها',
                    trailing: Text('الإصدار ١.٠', style: TextStyle(fontSize: 13, color: textSecColor)),
                    textColor: textColor,
                    textSecColor: textSecColor,
                    borderColor: borderColor,
                    onTap: () {},
                  ),
                  Divider(color: borderColor, height: 1),
                  _buildSettingRow(
                    icon: Icons.file_download_outlined,
                    title: 'تصدير بياناتي',
                    textColor: textColor,
                    textSecColor: textSecColor,
                    borderColor: borderColor,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تصدير نسخة من بياناتك بنجاح.'), behavior: SnackBarBehavior.floating),
                      );
                    },
                  ),
                  Divider(color: borderColor, height: 1),
                  _buildSettingRow(
                    icon: Icons.logout_rounded,
                    title: 'تسجيل الخروج',
                    textColor: textColor,
                    textSecColor: textSecColor,
                    borderColor: borderColor,
                    onTap: () async {
                      await ref.read(authNotifierProvider.notifier).signOut();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                  Divider(color: borderColor, height: 1),
                  _buildSettingRow(
                    icon: Icons.delete_outline_rounded,
                    title: 'حذف الحساب',
                    titleColor: AppColors.salmonBadge,
                    textColor: textColor,
                    textSecColor: textSecColor,
                    borderColor: borderColor,
                    onTap: () => _showDeleteAccountModal(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSegment(String label, bool active, VoidCallback onTap, bool isDark, Color primaryColor, Color borderColor, Color textColor) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: active
                ? (isDark ? const Color(0xFF1F3530) : const Color(0xFFC7E6DE))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? primaryColor : borderColor,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? primaryColor : textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    Widget? trailing,
    Color? titleColor,
    required Color textColor,
    required Color textSecColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            ?trailing,
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: titleColor ?? textColor,
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 20, color: titleColor ?? textSecColor),
          ],
        ),
      ),
    );
  }

  void _pickTone(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('نبرة المساعد', textAlign: TextAlign.right, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                for (final tone in ['هادي ومشجّع', 'مختصر ومباشر'])
                  ListTile(
                    title: Text(tone, textAlign: TextAlign.right),
                    trailing: tone == _assistantTone ? const Icon(Icons.check_rounded, color: AppColors.darkPrimary) : null,
                    onTap: () {
                      setState(() => _assistantTone = tone);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Page 35: Delete Account Confirmation
  void _showDeleteAccountModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DeleteAccountSheet(),
    );
  }
}

class DeleteAccountSheet extends StatefulWidget {
  const DeleteAccountSheet({super.key});

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    final isConfirmed = _confirmCtrl.text.trim() == 'حذف';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A2B28),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.salmonBadge, size: 32),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'متأكد يا أحمد؟',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'حذف الحساب هيشيل مهامك ومشاريعك وسجل محادثاتك نهائيًا. مش هتقدر ترجعهم بعد التأكيد.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textSecColor, height: 1.45),
              ),
              const SizedBox(height: 14),

              Center(
                child: Text(
                  'صدّر بياناتك الأول',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ),
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '«للتأكيد، اكتب «حذف',
                  style: TextStyle(fontSize: 12.5, color: textSecColor, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmCtrl,
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'حذف',
                  prefixIcon: Icon(Icons.edit_outlined, color: textSecColor, size: 18),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('لا، خلّي حسابي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white)),
              ),
              const SizedBox(height: 10),

              OutlinedButton(
                onPressed: isConfirmed
                    ? () {
                        Navigator.pop(context);
                        context.go('/login');
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.salmonBadge,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: isConfirmed ? AppColors.salmonBadge : borderColor),
                ),
                child: const Text('تأكيد الحذف النهائي', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
