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
  bool _loggingOut = false;
  bool _taskReminders = true;
  bool _focusReminders = true;
  bool _dailySummary = false;

  Future<void> _logout() async {
    final confirmed = await _confirm(
      title: 'تسجيل الخروج؟',
      message: 'تقدر ترجع لحسابك في أي وقت بتسجيل الدخول من جديد.',
      confirmLabel: 'تسجيل الخروج',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) setState(() => _loggingOut = false);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _confirm(
      title: 'حذف الحساب',
      message: 'حذف الحساب إجراء نهائي. هل أنت متأكد من رغبتك في المتابعة؟',
      confirmLabel: 'متابعة',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    _message('تم استلام طلب حذف الحساب وسيتم مراجعته.');
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) => showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: destructive ? AppColors.danger : AppColors.primaryStrong,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  void _showTonePicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اختار أسلوب هندلها', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final tone in const ['ودودة ومصرية هادئة', 'مختصرة ومباشرة', 'رسمية'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryStrong),
                  title: Text(tone),
                  trailing: tone == 'ودودة ومصرية هادئة'
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _message('تم اختيار: $tone');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authNotifierProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final avatarUrl = user?.avatarUrl;
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : 'حساب هندلها';

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعداداتك'),
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 29,
                  backgroundColor: isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft,
                  backgroundImage: avatarUrl == null || avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(name.substring(0, 1), style: const TextStyle(color: AppColors.primaryStrong, fontSize: 22, fontWeight: FontWeight.w800))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(user?.email ?? 'إدارة حسابك وتفضيلاتك', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const _SectionTitle('أسلوب هندلها'),
          _SettingsCard(children: [
            _SettingsRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'نبرة المساعد',
              subtitle: 'ودودة ومصرية هادئة',
              onTap: _showTonePicker,
            ),
            const _RowDivider(),
            _SettingsRow(
              icon: Icons.translate_rounded,
              title: 'اللغة واللهجة',
              subtitle: 'العربية المصرية',
              onTap: () => _message('العربية المصرية هي اللغة الحالية.'),
            ),
          ]),
          const SizedBox(height: 24),
          const _SectionTitle('المظهر'),
          _ThemeChoiceCard(
            selected: themeMode,
            onSelected: (mode) => ref.read(themeModeProvider.notifier).setMode(mode),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('التنبيهات'),
          _SettingsCard(children: [
            _SettingsRow(
              icon: Icons.nightlight_outlined,
              title: 'ساعات الهدوء',
              subtitle: '١٠ مساءً – ٨ صباحًا',
              onTap: () => context.push('/notifications'),
            ),
            const _RowDivider(),
            _SwitchRow(
              icon: Icons.notifications_none_rounded,
              title: 'تذكير بالمهام القادمة',
              value: _taskReminders,
              onChanged: (value) => setState(() => _taskReminders = value),
            ),
            const _RowDivider(),
            _SwitchRow(
              icon: Icons.self_improvement_rounded,
              title: 'تذكير بجلسات التركيز',
              value: _focusReminders,
              onChanged: (value) => setState(() => _focusReminders = value),
            ),
            const _RowDivider(),
            _SwitchRow(
              icon: Icons.done_all_rounded,
              title: 'ملخص الإنجاز اليومي',
              value: _dailySummary,
              onChanged: (value) => setState(() => _dailySummary = value),
            ),
          ]),
          const SizedBox(height: 24),
          const _SectionTitle('الخصوصية والبيانات'),
          _SettingsCard(children: [
            _SettingsRow(
              icon: Icons.download_outlined,
              title: 'تصدير بياناتي',
              onTap: () => _message('جاري تجهيز بياناتك للتصدير.'),
            ),
            const _RowDivider(),
            _SettingsRow(
              icon: Icons.verified_user_outlined,
              title: 'الخصوصية وحماية البيانات',
              onTap: () => _message('سياسة الخصوصية'),
            ),
          ]),
          const SizedBox(height: 24),
          _SettingsCard(children: [
            _SettingsRow(
              icon: Icons.logout_rounded,
              title: _loggingOut ? 'جارٍ تسجيل الخروج…' : 'تسجيل الخروج',
              destructive: false,
              onTap: _loggingOut ? null : _logout,
            ),
            const _RowDivider(),
            _SettingsRow(
              icon: Icons.delete_outline_rounded,
              title: 'حذف الحساب',
              destructive: true,
              onTap: _deleteAccount,
            ),
          ]),
          const SizedBox(height: 23),
          Center(
            child: Text(
              'هندلها • من الزحمة للخطوة الجاية • v1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.title, this.subtitle, this.onTap, this.destructive = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = destructive ? (isDark ? AppColors.darkDanger : AppColors.danger) : (isDark ? AppColors.darkPrimary : AppColors.primaryStrong);
    return ListTile(
      minVerticalPadding: 9,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: destructive ? color : null, fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_left_rounded, size: 21, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.title, required this.value, required this.onChanged});
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
        secondary: Icon(icon, color: AppColors.primaryStrong),
        title: Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
      );
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) => Divider(height: 1, indent: 58, endIndent: 16, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkDivider : AppColors.divider);
}

class _ThemeChoiceCard extends StatelessWidget {
  const _ThemeChoiceCard({required this.selected, required this.onSelected});
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onSelected;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final entry in const [
            (ThemeMode.system, 'تلقائي', Icons.brightness_auto_rounded),
            (ThemeMode.light, 'فاتح', Icons.light_mode_outlined),
            (ThemeMode.dark, 'داكن', Icons.dark_mode_outlined),
          ]) ...[
            Expanded(
              child: _ThemeChoice(
                mode: entry.$1,
                label: entry.$2,
                icon: entry.$3,
                selected: selected == entry.$1,
                onTap: () => onSelected(entry.$1),
              ),
            ),
            if (entry.$1 != ThemeMode.dark) const SizedBox(width: 9),
          ],
        ],
      );
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({required this.mode, required this.label, required this.icon, required this.selected, required this.onTap});
  final ThemeMode mode;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 7),
        decoration: BoxDecoration(
          color: selected ? (isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft) : (isDark ? AppColors.darkSurface : AppColors.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border), width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primaryStrong : AppColors.textSecondary, size: 22),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
