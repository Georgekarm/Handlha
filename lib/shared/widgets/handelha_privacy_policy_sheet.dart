import 'package:flutter/material.dart';

import '../../app/theme/app_theme_extension.dart';

/// نافذة مبسطة وحديثة لملخص الخصوصية وشروط الاستخدام في «هندلها».
class HandelhaPrivacyPolicySheet extends StatelessWidget {
  const HandelhaPrivacyPolicySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HandelhaPrivacyPolicySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    final items = isEn
        ? const [
            (
              icon: Icons.lock_outline_rounded,
              title: 'Your data stays private',
              body:
                  'Your tasks, projects, and notes are stored securely on your device and are never sold or shared.',
            ),
            (
              icon: Icons.mic_none_rounded,
              title: 'Microphone only when you tap',
              body:
                  'Voice access is used solely when you press the mic button to speak with the assistant.',
            ),
            (
              icon: Icons.notifications_none_rounded,
              title: 'Smart reminders on your terms',
              body:
                  'Notifications keep you on track, and you can adjust quiet hours or turn them off anytime.',
            ),
            (
              icon: Icons.tune_rounded,
              title: 'Full control anytime',
              body:
                  'Export your backup, clear chat history, or delete your account whenever you wish from Settings.',
            ),
          ]
        : const [
            (
              icon: Icons.lock_outline_rounded,
              title: 'بياناتك محفوظة بأمان',
              body:
                  'مهامك ومشاريعك ومحادثاتك بتتحفظ على جهازك بخصوصية تامة ومش بتتشارك مع أي طرف خارجي.',
            ),
            (
              icon: Icons.mic_none_rounded,
              title: 'المايك عند ضغطك بس',
              body:
                  'بنستخدم الميكروفون وقت ما تضغط على زر التحدث الصوتي مع المساعد ومش بنحتفظ بأي تسجيلات.',
            ),
            (
              icon: Icons.notifications_none_rounded,
              title: 'تنبيهات على راحتك',
              body:
                  'تذكيرات المهام وجلسات التركيز تحت تحكمك الكامل، وتقدر تضبط ساعات الهدوء أو توقفها في أي وقت.',
            ),
            (
              icon: Icons.tune_rounded,
              title: 'تحكم كامل في حسابك',
              body:
                  'تقدر تحفظ نسخة من بياناتك أو تمسح سجل المحادثات أو تحذف الحساب بالكامل من الإعدادات.',
            ),
          ];

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.primarySoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: colors.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn
                                ? 'Privacy & Terms'
                                : 'الخصوصية وشروط الاستخدام',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEn
                                ? 'A simple summary of how Handelha respects your data.'
                                : 'ملخص سريع وبسيط لطريقة تعامل «هندلها» مع بياناتك.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: colors.textMuted),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.surfaceSoft,
                        minimumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          _PrivacyRowItem(
                            icon: items[i].icon,
                            title: items[i].title,
                            body: items[i].body,
                          ),
                          if (i != items.length - 1)
                            Divider(
                              height: 20,
                              color: colors.divider.withValues(alpha: 0.7),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isEn ? 'Got it' : 'تمام، فهمت',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyRowItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PrivacyRowItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: colors.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
