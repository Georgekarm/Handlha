import 'package:flutter/material.dart';

import '../../app/theme/app_theme_extension.dart';
import '../../core/cloud/firebase_cloud_service.dart';
import '../../features/subscriptions/data/subscription_repository.dart';

/// نافذة مبسطة وصادقة لملخص الخصوصية وشروط الاستخدام في «هندلها»،
/// تعكس بدقة المسارات المفعّلة فعليًا في النسخة الحالية.
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
    final cloudEnabled = FirebaseCloudService.instance.isEnabled;
    final billingEnabled = SubscriptionConfig.isStoreBillingConfigured;

    final items = isEn
        ? [
            (
              icon: Icons.lock_outline_rounded,
              title: cloudEnabled
                  ? 'Local storage + optional cloud snapshot'
                  : 'Local-first storage on your device only',
              body: cloudEnabled
                  ? 'Your tasks, projects, focus sessions, and study records are stored in protected local app storage. When signed into a cloud account, JSON workspace snapshots are synced with your Firebase / Cloud Firestore account on sign-in/sign-out or manual sync. Your data is never sold.'
                  : 'In this local-first build, all your tasks, projects, focus sessions, grades, and reminders are stored strictly on your device. No automatic cloud sync or external account server is active.',
            ),
            (
              icon: Icons.psychology_outlined,
              title: 'On-device assistant text processing vs. system speech-to-text',
              body:
                  'Typed assistant messages are analyzed locally on your device without sending your text to an external LLM API. Voice input (RECORD_AUDIO) activates only when you tap the mic and uses Android SpeechRecognizer, which may use a network connection through your system speech provider to transcribe speech into text.',
            ),
            (
              icon: Icons.notifications_none_rounded,
              title: 'Transparent reminders & alarm permissions',
              body:
                  'Notifications and alarms respect your quiet hours and Android OS permissions. If notification or exact-alarm permissions are denied, Handelha explicitly shows whether a reminder is approximate or not scheduled.',
            ),
            if (billingEnabled)
              (
                icon: Icons.workspace_premium_outlined,
                title: 'Subscriptions & Google Play Billing',
                body:
                    'Subscriptions are processed via Google Play Billing and verified through RevenueCat. Plans renew automatically unless cancelled at least 24 hours before the end of the billing period in Google Play Subscriptions.',
              )
            else
              (
                icon: Icons.check_circle_outline_rounded,
                title: 'No active in-app billing in this build',
                body:
                    'Store billing is not configured in this build. You will not be charged and no payment methods are collected.',
              ),
            (
              icon: Icons.tune_rounded,
              title: 'Full backup, restore & permanent deletion',
              body:
                  'You can export a complete JSON backup of your workspace, restore it cleanly anytime, clear assistant chat history, or permanently delete your local profile and all stored data from Settings.',
            ),
          ]
        : [
            (
              icon: Icons.lock_outline_rounded,
              title: cloudEnabled
                  ? 'حفظ محلي + لقطة سحابية اختيارية'
                  : 'حفظ محلي على جهازك فقط',
              body: cloudEnabled
                  ? 'مهامك ومشاريعك وجلساتك ودرجاتك محفوظة داخل مساحة التطبيق المحمية على جهازك، ويتم رفع/جلب لقطة JSON لحسابك في Firebase / Cloud Firestore عند الدخول أو الخروج أو المزامنة اليدوية. لا يتم بيع بياناتك لأي طرف خارجي.'
                  : 'في هذه النسخة المحلية بالكامل، كل مهامك ومشاريعك وجلسات تركيزك ودرجاتك وتنبيهاتك محفوظة على جهازك فقط، ولا توجد مزامنة سحابية تلقائية أو خادم خارجي نشط.',
            ),
            (
              icon: Icons.psychology_outlined,
              title: 'معالجة نص المساعد محليًا مقابل التعرّف الصوتي للنظام',
              body:
                  'الرسائل المكتوبة للمساعد تُعالج محليًا على جهازك بدون إرسال نصوصك إلى LLM خارجي. أما الإدخال الصوتي (الميكروفون) فيعمل فقط لحظة ضغطك على زر المايك ويعتمد على محرك التعرّف على الكلام في Android (SpeechRecognizer)، والذي قد يستخدم اتصال الشبكة لتحويل صوتك إلى نص.',
            ),
            (
              icon: Icons.notifications_none_rounded,
              title: 'تنبيهات ومنبهات بشفافية كاملة للأذونات',
              body:
                  'التذكيرات والمنبهات تحترم ساعات الهدوء وأذونات نظام Android. ولو تم رفض إذن الإشعارات أو المنبه الدقيق، يوضح لك التطبيق صراحة إن كان التذكير تقريبيًا أو لم يُجدول بدل إظهار نجاح وهمي.',
            ),
            if (billingEnabled)
              (
                icon: Icons.workspace_premium_outlined,
                title: 'الاشتراكات والدفع عبر Google Play',
                body:
                    'تتم معالجة الاشتراكات عبر Google Play Billing والتحقق من صلاحية الباقة عبر خدمة RevenueCat، وتتجدد تلقائيًا ما لم يتم إلغاؤها من إعدادات اشتراكات Google Play قبل ٢٤ ساعة من التجديد.',
              )
            else
              (
                icon: Icons.check_circle_outline_rounded,
                title: 'لا توجد فوترة مفعّلة في هذه النسخة',
                body:
                    'خدمة الدفع غير مهيّأة في هذه النسخة؛ لا يتم تحصيل أي رسوم ولا طلب أي بيانات دفع.',
              ),
            (
              icon: Icons.tune_rounded,
              title: 'نسخ احتياطي واستعادة كاملة وحذف نهائي',
              body:
                  'تقدر تصدّر نسخة احتياطية كاملة (JSON) وتستعيدها بالكامل في أي وقت، أو تمسح سجل المحادثات، أو تحذف ملفك المحلي وكل بياناته نهائيًا من الإعدادات.',
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
