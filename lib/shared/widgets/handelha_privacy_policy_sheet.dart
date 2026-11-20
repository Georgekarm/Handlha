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
              title: 'Your data stays private & under your control',
              body:
                  'Your tasks, projects, study records, and notes are stored in protected app storage on your device and synced with your personal Firebase / Cloud Firestore account when cloud sync is active. Your data is never sold to third parties.',
            ),
            (
              icon: Icons.mic_none_rounded,
              title: 'Microphone & Speech Recognition only when you tap',
              body:
                  'Voice access (RECORD_AUDIO) is used strictly when you press the mic button to speak with the assistant. Android SpeechRecognizer may process speech via the system speech provider to convert it to text. No background audio is ever recorded.',
            ),
            (
              icon: Icons.notifications_none_rounded,
              title: 'Smart reminders on your terms',
              body:
                  'Notifications and exact alarms keep you on track for tasks and exams, and you can adjust quiet hours or turn them off anytime in Settings.',
            ),
            (
              icon: Icons.workspace_premium_outlined,
              title: 'Subscriptions & Google Play Billing',
              body:
                  'Subscriptions are processed via Google Play Billing and verified through RevenueCat. Plans renew automatically unless cancelled at least 24 hours before the end of the billing period in Google Play Subscriptions.',
            ),
            (
              icon: Icons.tune_rounded,
              title: 'Full control & permanent account deletion',
              body:
                  'You can export a complete JSON backup, clear assistant chat history, or permanently delete your account and all local & cloud data directly from Settings at any time.',
            ),
          ]
        : const [
            (
              icon: Icons.lock_outline_rounded,
              title: 'بياناتك محفوظة بأمان وخصوصية',
              body:
                  'مهامك ومشاريعك وسجل دراستك ومحادثاتك بتتحفظ بأمان داخل مساحة التطبيق على جهازك، وتتم مزامنتها مع حسابك السحابي المشفّر (Firebase / Cloud Firestore) عند تفعيل المزامنة، ولا يتم بيعها لأي طرف خارجي.',
            ),
            (
              icon: Icons.mic_none_rounded,
              title: 'المايك والتعرّف على الصوت عند ضغطك بس',
              body:
                  'بنستخدم إذن الميكروفون لحظة ضغطك على زر التحدث الصوتي فقط؛ وقد يستخدم محرك التعرّف على الكلام في نظام Android اتصال الشبكة لتحويل صوتك لنص، بدون أي تسجيل في الخلفية أو حفظ للتسجيلات.',
            ),
            (
              icon: Icons.notifications_none_rounded,
              title: 'تنبيهات ومنبهات على راحتك',
              body:
                  'تذكيرات المهام وجلسات التركيز والامتحانات تحت تحكمك الكامل، وتقدر تضبط ساعات الهدوء أو توقفها في أي وقت من الإعدادات.',
            ),
            (
              icon: Icons.workspace_premium_outlined,
              title: 'الاشتراكات والدفع عبر Google Play',
              body:
                  'تتم معالجة الاشتراكات عبر Google Play Billing والتحقق من صلاحية الباقة عبر خدمة RevenueCat، وتتجدد تلقائيًا ما لم يتم إلغاؤها من إعدادات اشتراكات Google Play قبل ٢٤ ساعة من التجديد.',
            ),
            (
              icon: Icons.tune_rounded,
              title: 'تحكم كامل وحذف فوري للحساب والبيانات',
              body:
                  'تقدر تصدّر نسخة احتياطية كاملة من بياناتك (JSON)، أو تمسح سجل المحادثات، أو تحذف حسابك وجميع بياناته المحلية والسحابية نهائيًا وبشكل فوري من الإعدادات.',
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
