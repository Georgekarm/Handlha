import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/locale/language_controller.dart';
import '../../../app/mode/student_mode_controller.dart';
import '../../../app/theme/app_theme_extension.dart';
import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../../shared/widgets/handelha_feedback.dart';
import '../../../shared/widgets/handelha_header.dart';
import '../../../shared/widgets/handelha_privacy_policy_sheet.dart';
import '../domain/subscription_models.dart';
import 'subscription_providers.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  static const _studentIndigo = Color(0xFF4F46E5);
  static const _studentTeal = Color(0xFF0D9488);

  late SubscriptionPlanTrack _selectedTrack;
  String? _pendingPlanId;

  @override
  void initState() {
    super.initState();
    final sub = ref.read(subscriptionProvider).value;
    final studentActive =
        (sub?.isStudent ?? false) || ref.read(isStudentModeActiveProvider);
    _selectedTrack =
        studentActive ? SubscriptionPlanTrack.student : SubscriptionPlanTrack.pro;
  }

  Future<void> _handlePlanAction({
    required _PlanDisplayItem plan,
    required AppLanguage appLang,
  }) async {
    setState(() => _pendingPlanId = plan.id);
    try {
      await ref.read(subscriptionProvider.notifier).selectPlan(
            track: _selectedTrack,
            planId: plan.liveOffer?.identifier ?? plan.id,
            planTitle: plan.title,
            planPrice: plan.priceLabel,
            isAnnual: plan.isAnnual,
          );
      if (!mounted) return;
      final updated = ref.read(subscriptionProvider).value;
      if (updated != null && updated.message != null) {
        HandelhaFeedback.showInfo(context, updated.message!);
      } else if (updated?.isPro == true) {
        final planName =
            updated!.resolvedPlanTitle(isEnglish: appLang.isEnglish);
        final categoryName = updated.categoryLabel(isEnglish: appLang.isEnglish);
        HandelhaFeedback.showSuccess(
          context,
          appLang.isEnglish
              ? 'Subscribed to $planName ($categoryName)'
              : 'تم اشتراكك بنجاح في: $planName ($categoryName)',
        );
      }
    } finally {
      if (mounted) setState(() => _pendingPlanId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final appLang = ref.watch(appLanguageProvider);
    final isEn = appLang.isEnglish;
    final subAsync = ref.watch(subscriptionProvider);
    final state = subAsync.value ??
        const SubscriptionState(
          status: SubscriptionStatus.unknown,
          tier: SubscriptionTier.free,
        );
    final isStudentMode = ref.watch(isStudentModeActiveProvider);
    final isStudentSelected = _selectedTrack == SubscriptionPlanTrack.student;

    final liveTrackOffers =
        state.offers.where((o) => o.track == _selectedTrack).toList();
    final plans = _buildTrackPlans(
      track: _selectedTrack,
      liveOffers: liveTrackOffers,
      isEn: isEn,
    );

    return Scaffold(
      body: HandelhaAmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HandelhaHeader(
                  title: isEn ? 'Subscription Plans' : 'خطط الاشتراك',
                  subtitle: isEn
                      ? 'Choose between Student Plans and regular Pro Plans'
                      : 'باقات مخصصة للطلاب وباقات Pro العادية فقط',
                ),
                const SizedBox(height: 6),

                if (state.isPro) ...[
                  _ActiveSubscriptionCard(
                    state: state,
                    isEn: isEn,
                    onCancelLocal: state.isLocalActivation
                        ? () async {
                            await ref
                                .read(subscriptionProvider.notifier)
                                .cancelLocalPlan();
                            if (!context.mounted) return;
                            HandelhaFeedback.showInfo(
                              context,
                              appLang.tr(
                                'تم الرجوع إلى الحساب المجاني.',
                                'Switched back to the Free account tier.',
                              ),
                            );
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  _FreeClassificationBanner(isEn: isEn),
                  const SizedBox(height: 14),
                ],

                // Switcher strictly between ONLY Student & Regular Pro plans
                _PlanTrackSwitcher(
                  selected: _selectedTrack,
                  activeTrack: state.isPro
                      ? (state.isStudent
                          ? SubscriptionPlanTrack.student
                          : SubscriptionPlanTrack.pro)
                      : null,
                  isEn: isEn,
                  onChanged: (next) => setState(() => _selectedTrack = next),
                ),
                const SizedBox(height: 16),

                // Distinct Hero Card (custom Student geometry vs Executive Pro)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: isStudentSelected
                      ? _StudentTrackHeroCard(
                          key: const ValueKey('student_hero'),
                          isEn: isEn,
                          isStudentModeEnabled: isStudentMode,
                        )
                      : _ProTrackHeroCard(
                          key: const ValueKey('pro_hero'),
                          isEn: isEn,
                        ),
                ),
                const SizedBox(height: 18),

                // Two options inside the selected track (Monthly / Yearly)
                Text(
                  isStudentSelected
                      ? (isEn
                          ? 'Student Plans (Special Pricing)'
                          : 'خطط الطلاب (أسعار مخفّضة للطلاب)')
                      : (isEn
                          ? 'Regular Pro Plans'
                          : 'خطط Pro المتاحة'),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                for (var i = 0; i < plans.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final plan = plans[i];
                      final isCurrentPlan = state.isPlanActive(plan.id) ||
                          (plan.liveOffer != null &&
                              state.isPlanActive(plan.liveOffer!.identifier));
                      return _TrackPlanCard(
                        plan: plan,
                        isStudentTrack: isStudentSelected,
                        isCurrentPlan: isCurrentPlan,
                        hasOtherSubscription: state.isPro && !isCurrentPlan,
                        isEn: isEn,
                        isBusy: _pendingPlanId != null &&
                            _pendingPlanId == plan.id,
                        onTap: _pendingPlanId != null || isCurrentPlan
                            ? null
                            : () => _handlePlanAction(
                                  plan: plan,
                                  appLang: appLang,
                                ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 20),

                // Track-specific features (highlighting Student-only perks vs Pro)
                Text(
                  isStudentSelected
                      ? (isEn
                          ? 'Included in Student Plans Only'
                          : 'مزايا خاصة بباقات الطلاب فقط')
                      : (isEn ? 'Included in Regular Pro' : 'مزايا باقة Pro العادية'),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                if (isStudentSelected) ...[
                  _StudentPerkTile(
                    icon: Icons.fact_check_rounded,
                    badgeTag: isEn ? 'Student Only' : 'للطلاب فقط',
                    title: isEn
                        ? 'Exam Grades & Semester Record'
                        : 'تسجيل تقديرات الامتحانات وسجل الدرجات',
                    subtitle: isEn
                        ? 'Save quizzes, midterms, and final scores in your Progress tab.'
                        : 'تظهر في صفحة «إنجازك» لتسجيل نتائج الكويزات والميدتيرم والفاينل.',
                  ),
                  const SizedBox(height: 10),
                  _StudentPerkTile(
                    icon: Icons.workspace_premium_rounded,
                    badgeTag: isEn ? 'Student Only' : 'للطلاب فقط',
                    title: isEn
                        ? 'Exam Hero Milestone & Natural Motivation'
                        : 'أوسمة التفوق الدراسي وتشجيع مصري طبيعي',
                    subtitle: isEn
                        ? 'Warm, realistic encouragement tuned for exam weeks and finals.'
                        : 'رسائل تشجيع حقيقية وبسيطة من غير ردود مصطنعة بعد كل امتحان.',
                  ),
                  const SizedBox(height: 10),
                  _StudentPerkTile(
                    icon: Icons.school_rounded,
                    badgeTag: isEn ? 'Exclusive Look' : 'تصميم مخصص',
                    title: isEn
                        ? 'Distinctive Student Mode Shapes & Theme'
                        : 'أشكال وشعارات وضع الطالب المميزة',
                    subtitle: isEn
                        ? 'Special academic crests, badges, and indigo-teal highlights across Progress.'
                        : 'بطاقات وأوسمة بأشكال هندسية وشعار أكاديمي خاص بوضع الطالب.',
                  ),
                  const SizedBox(height: 10),
                  _StudentPerkTile(
                    icon: Icons.all_inclusive_rounded,
                    badgeTag: isEn ? 'Full Pro' : 'كل مزايا Pro',
                    title: isEn
                        ? 'All Pro AI Study Planning & Focus Insights'
                        : 'كل مميزات Pro للتخطيط وتقسيم المذاكرة',
                    subtitle: isEn
                        ? 'Break down courses into study blocks and track focus sessions.'
                        : 'تقسيم المواد لمهام صغيرة ومتابعة جلسات التركيز اليومية.',
                  ),
                ] else ...[
                  _ProPerkTile(
                    icon: Icons.auto_awesome_rounded,
                    title: isEn
                        ? 'Smart Task & Project Breakdown'
                        : 'تقسيم ذكي للمهام والمشروعات',
                    subtitle: isEn
                        ? 'Convert large goals into calm, scheduled daily actions.'
                        : 'حوّل أي مشروع أو هدف كبير لخطوات مرتّبة على وقتك وطاقتك.',
                  ),
                  const SizedBox(height: 10),
                  _ProPerkTile(
                    icon: Icons.insights_rounded,
                    title: isEn
                        ? 'Deep Productivity & Focus Analytics'
                        : 'تحليلات عميقة للإنتاجية والتركيز',
                    subtitle: isEn
                        ? 'Track active hours, peak focus windows, and multi-month streaks.'
                        : 'اعرف ساعات ذروتك وتطوّر إنجازك على مدار الأسابيع والشهور.',
                  ),
                  const SizedBox(height: 10),
                  _ProPerkTile(
                    icon: Icons.bolt_rounded,
                    title: isEn
                        ? 'Higher Assistant Capacity'
                        : 'سعة أكبر مع المساعد الشخصي هندلها',
                    subtitle: isEn
                        ? 'Extended scheduling and priority daily organization.'
                        : 'حدود أعلى لتنظيم يومك صوتيًا ونصيًا بدون قيود اليومية.',
                  ),
                ],

                const SizedBox(height: 20),

                // Quick Student Mode toggle card on Student track for immediate preview
                if (isStudentSelected) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _studentIndigo.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.tune_rounded,
                              color: _studentIndigo,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isEn
                                    ? 'Student Mode Preview'
                                    : 'حالة وضع الطالب حاليًا',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isStudentMode
                                    ? _studentTeal.withValues(alpha: 0.14)
                                    : c.surfaceSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isStudentMode
                                    ? (isEn ? 'Active' : 'مفعّل')
                                    : (isEn ? 'Off' : 'غير مفعّل'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: isStudentMode
                                      ? _studentTeal
                                      : c.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isStudentMode
                              ? (isEn
                                  ? 'Student Mode shapes and exam grade logging are visible in Your Progress tab.'
                                  : 'وضع الطالب شغّال — تقديرات الامتحانات وأشكال الطلاب ظاهرة في تبويب «إنجازك».')
                              : (isEn
                                  ? 'Enable Student Mode to unlock exam grade tracking and Student shapes in Your Progress.'
                                  : 'شغّل وضع الطالب عشان تظهرلك أشكال الطلاب وتقديرات الامتحانات في «إنجازك».'),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            if (state.isStudent && isStudentMode) {
                              context.go('/tracking');
                              return;
                            }
                            final next = !isStudentMode;
                            await ref
                                .read(studentModeControllerProvider.notifier)
                                .setStudentMode(next);
                            if (!context.mounted) return;
                            HandelhaFeedback.showSuccess(
                              context,
                              next
                                  ? (isEn
                                      ? 'Student Mode is now active'
                                      : 'تم تفعيل وضع الطالب')
                                  : (isEn
                                      ? 'Switched back to Standard Mode'
                                      : 'تم الرجوع للوضع العادي'),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _studentIndigo,
                            side: BorderSide(
                              color: _studentIndigo.withValues(alpha: 0.45),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            isStudentMode
                                ? Icons.check_circle_outline_rounded
                                : Icons.school_rounded,
                            size: 18,
                          ),
                          label: Text(
                            state.isStudent
                                ? (isEn
                                    ? 'Open Progress (Student View)'
                                    : 'افتح «إنجازك» بوضع الطالب')
                                : isStudentMode
                                    ? (isEn
                                        ? 'Turn Off Student Mode'
                                        : 'إيقاف وضع الطالب مؤقتًا')
                                    : (isEn
                                        ? 'Enable Student Mode Now'
                                        : 'تفعيل وضع الطالب دلوقتي'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Google Play Billing Disclosure & Terms
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border.withValues(alpha: 0.7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 16,
                            color: c.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isEn
                                  ? 'Google Play Billing & Auto-Renewal Terms'
                                  : 'شروط الدفع والتجديد التلقائي عبر Google Play',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isEn
                            ? 'Subscriptions are billed securely via your Google Play account and renew automatically at the end of each billing cycle (monthly or yearly) unless canceled at least 24 hours before renewal in Google Play > Subscriptions.'
                            : 'تتم معالجة الاشتراكات بأمان عبر حسابك في Google Play، وتتجدد تلقائيًا في نهاية كل دورة فوترة (شهرية أو سنوية) ما لم تقم بإلغاء الاشتراك قبل ٢٤ ساعة على الأقل من موعد التجديد من خلال متجر Google Play > الاشتراكات.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.5,
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () =>
                              HandelhaPrivacyPolicySheet.show(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                            Icons.policy_outlined,
                            size: 15,
                            color: c.primary,
                          ),
                          label: Text(
                            isEn
                                ? 'Privacy Policy & Terms of Use'
                                : 'سياسة الخصوصية وشروط الاستخدام',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: c.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Footer actions (Restore Purchases & Store Refresh)
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: state.isLoadingData
                            ? null
                            : () async {
                                await ref
                                    .read(subscriptionProvider.notifier)
                                    .restorePurchases();
                                if (!context.mounted) return;
                                final msg = ref
                                    .read(subscriptionProvider)
                                    .value
                                    ?.message;
                                HandelhaFeedback.showInfo(
                                  context,
                                  msg ??
                                      (isEn
                                          ? 'Checked previous purchases.'
                                          : 'تمت مراجعة المشتريات السابقة.'),
                                );
                              },
                        icon: Icon(Icons.restore_rounded,
                            size: 18, color: c.primary),
                        label: Text(
                          isEn ? 'Restore Purchases' : 'استعادة المشتريات',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.primary,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => ref
                            .read(subscriptionProvider.notifier)
                            .refreshSubscription(),
                        icon: Icon(Icons.refresh_rounded,
                            size: 18, color: c.textSecondary),
                        label: Text(
                          isEn ? 'Refresh Store' : 'تحديث الباقات',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_PlanDisplayItem> _buildTrackPlans({
    required SubscriptionPlanTrack track,
    required List<SubscriptionOffer> liveOffers,
    required bool isEn,
  }) {
    if (liveOffers.isNotEmpty) {
      return liveOffers
          .map(
            (offer) => _PlanDisplayItem(
              id: offer.identifier,
              title: offer.title,
              subtitle: offer.description,
              priceLabel: offer.price,
              periodLabel: offer.periodLabel,
              comparePriceLabel: track == SubscriptionPlanTrack.student
                  ? (offer.isAnnual
                      ? (isEn ? 'Pro 699 EGP' : 'سعر Pro: ٦٩٩ ج.م')
                      : (isEn ? 'Pro 89 EGP' : 'سعر Pro: ٨٩ ج.م'))
                  : null,
              badgeLabel: offer.isAnnual
                  ? (track == SubscriptionPlanTrack.student
                      ? (isEn ? 'Student Best Value' : 'أفضل قيمة للطلاب')
                      : (isEn ? 'Best Value' : 'أفضل توفير'))
                  : (track == SubscriptionPlanTrack.student
                      ? (isEn ? 'Student Discount' : 'خصم الطلاب ٤٥٪')
                      : null),
              isAnnual: offer.isAnnual,
              isHighlighted: offer.isAnnual,
              liveOffer: offer,
            ),
          )
          .toList();
    }

    if (track == SubscriptionPlanTrack.student) {
      return [
        _PlanDisplayItem(
          id: 'student_yearly',
          title: isEn ? 'Student Yearly' : 'باقة الطلاب السنوية',
          subtitle: isEn
              ? 'Full academic year • ~33 EGP / month'
              : 'سنة دراسية كاملة • حوالي ٣٣ ج.م شهريًا',
          priceLabel: isEn ? '399 EGP' : '٣٩٩ ج.م',
          periodLabel: isEn ? 'per year' : 'في السنة',
          comparePriceLabel: isEn ? 'Pro 699 EGP' : '٦٩٩ ج.م',
          badgeLabel: isEn ? 'Save 43% • Student' : 'توفير ٤٣٪ • للطلاب فقط',
          isAnnual: true,
          isHighlighted: true,
        ),
        _PlanDisplayItem(
          id: 'student_monthly',
          title: isEn ? 'Student Monthly' : 'باقة الطلاب الشهرية',
          subtitle: isEn
              ? 'Flexible monthly student rate'
              : 'مرونة شهرية بسعر مخفّض عن باقة Pro العادية',
          priceLabel: isEn ? '49 EGP' : '٤٩ ج.م',
          periodLabel: isEn ? 'per month' : 'في الشهر',
          comparePriceLabel: isEn ? 'Pro 89 EGP' : '٨٩ ج.م',
          badgeLabel: isEn ? 'Student Rate' : 'سعر الطالب',
          isAnnual: false,
          isHighlighted: false,
        ),
      ];
    }

    return [
      _PlanDisplayItem(
        id: 'pro_yearly',
        title: isEn ? 'Pro Yearly' : 'باقة Pro السنوية',
        subtitle: isEn
            ? 'Full year access • ~58 EGP / month'
            : 'اشتراك سنوي كامل • حوالي ٥٨ ج.م شهريًا',
        priceLabel: isEn ? '699 EGP' : '٦٩٩ ج.م',
        periodLabel: isEn ? 'per year' : 'في السنة',
        comparePriceLabel: null,
        badgeLabel: isEn ? 'Best Value' : 'الأكثر توفيرًا',
        isAnnual: true,
        isHighlighted: true,
      ),
      _PlanDisplayItem(
        id: 'pro_monthly',
        title: isEn ? 'Pro Monthly' : 'باقة Pro الشهرية',
        subtitle: isEn
            ? 'Standard monthly Pro plan'
            : 'اشتراك شهري لخطط العمل والتنظيم اليومي',
        priceLabel: isEn ? '89 EGP' : '٨٩ ج.م',
        periodLabel: isEn ? 'per month' : 'في الشهر',
        comparePriceLabel: null,
        badgeLabel: null,
        isAnnual: false,
        isHighlighted: false,
      ),
    ];
  }
}

class _PlanDisplayItem {
  final String id;
  final String title;
  final String subtitle;
  final String priceLabel;
  final String periodLabel;
  final String? comparePriceLabel;
  final String? badgeLabel;
  final bool isAnnual;
  final bool isHighlighted;
  final SubscriptionOffer? liveOffer;

  const _PlanDisplayItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.periodLabel,
    this.comparePriceLabel,
    this.badgeLabel,
    this.isAnnual = false,
    this.isHighlighted = false,
    this.liveOffer,
  });
}

class _PlanTrackSwitcher extends StatelessWidget {
  const _PlanTrackSwitcher({
    required this.selected,
    required this.isEn,
    required this.onChanged,
    this.activeTrack,
  });

  final SubscriptionPlanTrack selected;
  final SubscriptionPlanTrack? activeTrack;
  final bool isEn;
  final ValueChanged<SubscriptionPlanTrack> onChanged;

  static const _studentIndigo = Color(0xFF4F46E5);
  static const _studentTeal = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isStudent = selected == SubscriptionPlanTrack.student;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isStudent
              ? _studentIndigo.withValues(alpha: 0.3)
              : c.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(SubscriptionPlanTrack.student),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  gradient: isStudent
                      ? const LinearGradient(
                          colors: [_studentIndigo, _studentTeal],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_rounded,
                      size: 18,
                      color: isStudent ? Colors.white : c.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isEn ? 'Student Plans' : 'باقات الطلاب',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isStudent ? Colors.white : c.textPrimary,
                        ),
                      ),
                    ),
                    if (activeTrack == SubscriptionPlanTrack.student) ...[
                      const SizedBox(width: 5),
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: isStudent ? Colors.white : _studentTeal,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(SubscriptionPlanTrack.pro),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: !isStudent ? c.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: !isStudent ? c.textOnPrimary : c.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isEn ? 'Pro Plans' : 'باقات Pro العادية',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: !isStudent ? c.textOnPrimary : c.textPrimary,
                        ),
                      ),
                    ),
                    if (activeTrack == SubscriptionPlanTrack.pro) ...[
                      const SizedBox(width: 5),
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: !isStudent ? c.textOnPrimary : c.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentTrackHeroCard extends StatelessWidget {
  const _StudentTrackHeroCard({
    super.key,
    required this.isEn,
    required this.isStudentModeEnabled,
  });

  final bool isEn;
  final bool isStudentModeEnabled;

  static const _studentIndigo = Color(0xFF4F46E5);
  static const _studentTeal = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: CustomPaint(
        painter: const _StudentHeroPatternPainter(),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [_studentIndigo, Color(0xFF3730A3), _studentTeal],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(6),
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.32),
                      ),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                              topRight: Radius.circular(4),
                              bottomLeft: Radius.circular(4),
                            ),
                          ),
                          child: Text(
                            isEn ? 'STUDENT EDITION • 45% OFF' : 'باقة الطلاب • خصم ٤٥٪',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _studentIndigo,
                            ),
                          ),
                        ),
                        if (isStudentModeEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isEn ? 'Student Mode Active' : 'وضع الطالب مفعّل',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isEn
                    ? 'Designed for Study Weeks & Exams'
                    : 'مصممة خصيصًا للدراسة وأوقات الامتحانات',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isEn
                    ? 'Unlocks Student-only exam grade logging, academic badges, and lower student pricing — starting at 49 EGP instead of 89 EGP.'
                    : 'سعر أقل للطلاب يبدأ من ٤٩ ج.م بدل ٨٩ ج.م، مع شكل خاص بوضع الطالب ومزايا تسجيل الامتحانات والدراسة.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentHeroPatternPainter extends CustomPainter {
  const _StudentHeroPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.22),
      42,
      ringPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.22),
      64,
      ringPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.14, size.height * 0.92),
      36,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StudentHeroPatternPainter oldDelegate) => false;
}

class _ProTrackHeroCard extends StatelessWidget {
  const _ProTrackHeroCard({super.key, required this.isEn});

  final bool isEn;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.primary.withValues(alpha: 0.35), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: c.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Handelha Pro' : 'باقة Pro العادية',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn
                          ? 'Work, Projects & Deep Productivity'
                          : 'للشغل اليومي وإدارة المشروعات والإنتاجية',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isEn
                ? 'Full access to smart task breakdown, deep time insights, and extended daily assistant planning.'
                : 'تشمل تقسيم المشروعات والمهام الذكي، وتحليلات الأداء العميقة، وسعة أكبر مع المساعد الشخصي هندلها.',
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackPlanCard extends StatelessWidget {
  const _TrackPlanCard({
    required this.plan,
    required this.isStudentTrack,
    required this.isEn,
    required this.isBusy,
    required this.onTap,
    this.isCurrentPlan = false,
    this.hasOtherSubscription = false,
  });

  final _PlanDisplayItem plan;
  final bool isStudentTrack;
  final bool isCurrentPlan;
  final bool hasOtherSubscription;
  final bool isEn;
  final bool isBusy;
  final VoidCallback? onTap;

  static const _studentIndigo = Color(0xFF4F46E5);
  static const _studentTeal = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final accentColor = isStudentTrack ? _studentIndigo : c.primary;

    final cardRadius = isStudentTrack
        ? const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
          )
        : BorderRadius.circular(20);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: cardRadius,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: cardRadius,
            border: Border.all(
              color: isCurrentPlan
                  ? (isStudentTrack ? _studentTeal : c.primary)
                  : plan.isHighlighted
                      ? accentColor
                      : c.border.withValues(alpha: 0.85),
              width: (isCurrentPlan || plan.isHighlighted) ? 2.0 : 1.0,
            ),
            gradient: isStudentTrack && (plan.isHighlighted || isCurrentPlan)
                ? LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      _studentIndigo.withValues(alpha: 0.08),
                      c.surface,
                      _studentTeal.withValues(alpha: 0.06),
                    ],
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isCurrentPlan || plan.badgeLabel != null) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (isCurrentPlan)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isStudentTrack
                                        ? _studentTeal
                                        : c.primary,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    isEn ? 'Current Plan ✓' : 'خطتك الحالية ✓',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              if (plan.badgeLabel != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isStudentTrack
                                        ? const LinearGradient(
                                            colors: [
                                              _studentIndigo,
                                              _studentTeal,
                                            ],
                                          )
                                        : null,
                                    color:
                                        isStudentTrack ? null : c.primarySoft,
                                    borderRadius: isStudentTrack
                                        ? const BorderRadius.only(
                                            topLeft: Radius.circular(10),
                                            bottomRight: Radius.circular(10),
                                            topRight: Radius.circular(3),
                                            bottomLeft: Radius.circular(3),
                                          )
                                        : BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    plan.badgeLabel!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isStudentTrack
                                          ? Colors.white
                                          : c.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          plan.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        plan.priceLabel,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                        ),
                      ),
                      Text(
                        plan.periodLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                        ),
                      ),
                      if (plan.comparePriceLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          plan.comparePriceLabel!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: c.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: (isCurrentPlan || (isStudentTrack && plan.isHighlighted))
                      ? (isCurrentPlan
                          ? null
                          : const LinearGradient(
                              colors: [_studentIndigo, _studentTeal],
                            ))
                      : null,
                  color: isCurrentPlan
                      ? (isStudentTrack
                          ? _studentTeal.withValues(alpha: 0.14)
                          : c.primary.withValues(alpha: 0.14))
                      : (isStudentTrack && plan.isHighlighted)
                          ? null
                          : plan.isHighlighted
                              ? accentColor
                              : accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isCurrentPlan
                            ? (isEn
                                ? 'Subscribed to This Plan ✓'
                                : 'أنت مشترك في هذه الخطة ✓')
                            : hasOtherSubscription
                                ? (isEn
                                    ? 'Switch to This Plan'
                                    : 'التحويل لهذه الخطة')
                                : isStudentTrack
                                    ? (isEn
                                        ? 'Choose Student Plan'
                                        : 'اختار باقة الطلاب')
                                    : (isEn ? 'Choose Pro Plan' : 'اختار باقة Pro'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isCurrentPlan
                              ? (isStudentTrack ? _studentTeal : c.primary)
                              : plan.isHighlighted
                                  ? Colors.white
                                  : accentColor,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentPerkTile extends StatelessWidget {
  const _StudentPerkTile({
    required this.icon,
    required this.badgeTag,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String badgeTag;
  final String title;
  final String subtitle;

  static const _studentIndigo = Color(0xFF4F46E5);
  static const _studentTeal = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(8),
        ),
        border: Border.all(color: _studentIndigo.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_studentIndigo, _studentTeal],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _studentIndigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeTag,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _studentIndigo,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProPerkTile extends StatelessWidget {
  const _ProPerkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeClassificationBanner extends StatelessWidget {
  const _FreeClassificationBanner({required this.isEn});

  final bool isEn;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.surfaceSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.badge_outlined,
              size: 18,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'Account Tier: Free' : 'تصنيف الحساب الحالي: مجاني',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEn
                      ? 'Pick either Student Category or Regular Pro Category below.'
                      : 'حدد تصنيفك من باقات الطلاب أو باقات Pro العادية بالأسفل.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: c.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveSubscriptionCard extends StatelessWidget {
  const _ActiveSubscriptionCard({
    required this.state,
    required this.isEn,
    this.onCancelLocal,
  });

  final SubscriptionState state;
  final bool isEn;
  final VoidCallback? onCancelLocal;

  static const _studentIndigo = Color(0xFF4F46E5);
  static const _studentTeal = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isStudent = state.isStudent;
    final planName = state.resolvedPlanTitle(isEnglish: isEn);
    final categoryLabel = state.categoryLabel(isEnglish: isEn);
    final expiryStr =
        state.expirationDate?.toLocal().toString().split(' ').first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isStudent
            ? const LinearGradient(colors: [_studentIndigo, _studentTeal])
            : null,
        color: isStudent ? null : c.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: isStudent
            ? null
            : Border.all(color: c.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isStudent ? Icons.school_rounded : Icons.verified_rounded,
                color: isStudent ? Colors.white : c.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isStudent
                            ? Colors.white.withValues(alpha: 0.18)
                            : c.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        categoryLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isStudent ? Colors.white : c.primary,
                        ),
                      ),
                    ),
                    if (onCancelLocal != null)
                      TextButton(
                        onPressed: onCancelLocal,
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isStudent ? Colors.white : c.textSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          isEn ? 'Reset to Free' : 'إلغاء الاشتراك',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isEn
                ? 'Active Plan: $planName'
                : 'أنت مشترك حاليًا في: $planName',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isStudent ? Colors.white : c.textPrimary,
            ),
          ),
          if (state.activePlanPrice != null || expiryStr != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (state.activePlanPrice != null &&
                    state.activePlanPrice!.trim().isNotEmpty)
                  state.activePlanPrice!.trim(),
                if (expiryStr != null)
                  isEn ? 'Valid until $expiryStr' : 'صالح حتى $expiryStr',
              ].join(' • '),
              style: TextStyle(
                fontSize: 12,
                color: isStudent
                    ? Colors.white.withValues(alpha: 0.9)
                    : c.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
