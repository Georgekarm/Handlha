import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class ProjectSettingsScreen extends StatefulWidget {
  final String projectId;
  final String initialTitle;
  final String initialGoal;

  const ProjectSettingsScreen({
    super.key,
    this.projectId = '1',
    this.initialTitle = 'مشروع تطبيق Flutter',
    this.initialGoal = 'إطلاق أول نسخة تجريبية من التطبيق',
  });

  @override
  State<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends State<ProjectSettingsScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _goalCtrl;
  late DateTime _startDate;
  late DateTime _endDate;
  int _weeklyHours = 12;
  int _selectedColor = 0;

  static const _projectColors = <Color>[
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    Color(0xFF8FA8C7),
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _goalCtrl = TextEditingController(text: widget.initialGoal);
    _startDate = DateTime(2026, 9, 1);
    _endDate = DateTime(2026, 10, 31);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime date) => MaterialLocalizations.of(context).formatMediumDate(date);

  Future<void> _chooseDate({required bool start}) async {
    final current = start ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: start ? 'موعد بداية المشروع' : 'الموعد المستهدف',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  void _save() {
    Navigator.of(context).pop({
      'title': _titleCtrl.text.trim(),
      'goal': _goalCtrl.text.trim(),
      'start': _startDate,
      'end': _endDate,
      'weeklyHours': _weeklyHours,
      'color': _projectColors[_selectedColor].toARGB32(),
    });
  }

  Future<void> _showProjectAction({required bool deleting}) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(deleting ? 'حذف المشروع؟' : 'أرشفة المشروع؟'),
        content: Text(deleting
            ? 'هذا الإجراء لا يمكن التراجع عنه. هل تريد المتابعة؟'
            : 'سيتم نقل المشروع إلى الأرشيف ويمكن استعادته لاحقًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: deleting ? AppColors.danger : AppColors.primaryStrong),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(deleting ? 'حذف المشروع' : 'أرشفة'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(deleting ? 'تم حذف المشروع' : 'تمت أرشفة المشروع'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات المشروع'),
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
        actions: [
          TextButton(onPressed: _save, child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 10, 18, 36),
        children: [
          Text('خلّي تفاصيل المشروع واضحة من البداية.', style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          const SizedBox(height: 22),
          const _SectionTitle(title: 'البيانات الأساسية', subtitle: 'الاسم والهدف اللي شغال عشانه المشروع'),
          _Panel(
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'اسم المشروع', prefixIcon: Icon(Icons.folder_outlined)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _goalCtrl,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'الهدف من المشروع', prefixIcon: Icon(Icons.flag_outlined), alignLabelWithHint: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle(title: 'لون المشروع', subtitle: 'اختار لون يساعدك تميّزه بسرعة'),
          _Panel(
            child: Row(
              children: List.generate(_projectColors.length, (index) {
                final selected = index == _selectedColor;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 15),
                  child: InkWell(
                    onTap: () => setState(() => _selectedColor = index),
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _projectColors[index],
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? (isDark ? Colors.white : AppColors.textPrimary) : Colors.transparent, width: 2.5),
                      ),
                      child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 22) : null,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle(title: 'الوقت والجهد', subtitle: 'مواعيد مرنة تساعدك تخطط من غير ضغط'),
          _Panel(
            child: Column(
              children: [
                _DateSettingRow(
                  icon: Icons.calendar_today_outlined,
                  title: 'تاريخ البداية',
                  value: _dateLabel(_startDate),
                  onTap: () => _chooseDate(start: true),
                ),
                const _ThinDivider(),
                _DateSettingRow(
                  icon: Icons.event_outlined,
                  title: 'الموعد المستهدف',
                  value: _dateLabel(_endDate),
                  onTap: () => _chooseDate(start: false),
                ),
                const _ThinDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: AppColors.primaryStrong),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('الوقت المتاح أسبوعيًا', style: TextStyle(fontWeight: FontWeight.w600))),
                      DropdownButton<int>(
                        value: _weeklyHours,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(14),
                        items: const [6, 8, 12, 16, 20, 30, 40]
                            .map((hours) => DropdownMenuItem(value: hours, child: Text('$hours ساعة')))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _weeklyHours = value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const _SectionTitle(title: 'إدارة المشروع', subtitle: 'إجراءات إضافية على هذا المشروع'),
          _Panel(
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.archive_outlined,
                  title: 'أرشفة المشروع',
                  subtitle: 'إخفاؤه من المشاريع النشطة',
                  onTap: () => _showProjectAction(deleting: false),
                ),
                const _ThinDivider(),
                _ActionRow(
                  icon: Icons.delete_outline_rounded,
                  title: 'حذف المشروع',
                  subtitle: 'حذف نهائي لكل تفاصيل المشروع',
                  destructive: true,
                  onTap: () => _showProjectAction(deleting: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 3, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: child,
    );
  }
}

class _DateSettingRow extends StatelessWidget {
  const _DateSettingRow({required this.icon, required this.title, required this.value, required this.onTap});
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryStrong),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left_rounded, size: 19, color: AppColors.textMuted),
            ],
          ),
        ),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.title, required this.subtitle, required this.onTap, this.destructive = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: destructive ? color : null, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();
  @override
  Widget build(BuildContext context) => Divider(height: 1, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkDivider : AppColors.divider);
}
