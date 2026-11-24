import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handelha/app/theme/app_theme.dart';
import 'package:handelha/core/telemetry/local_core_loop_telemetry.dart';
import 'package:handelha/core/telemetry/pilot_cohort_evaluator.dart';
import 'package:handelha/core/telemetry/unit_economics_calculator.dart';
import 'package:handelha/features/authentication/domain/app_user.dart';
import 'package:handelha/features/authentication/presentation/auth_providers.dart';
import 'package:handelha/features/assistant/presentation/chat_screen.dart';
import 'package:handelha/features/assistant/presentation/chat_session_controller.dart';
import 'package:handelha/features/assistant/presentation/assistant_providers.dart';
import 'package:handelha/features/subscriptions/data/local_subscription_store.dart';
import 'package:handelha/features/subscriptions/data/revenuecat_subscription_repository.dart';
import 'package:handelha/features/subscriptions/data/subscription_repository.dart';
import 'package:handelha/features/subscriptions/domain/subscription_models.dart';
import 'package:handelha/features/subscriptions/presentation/subscription_providers.dart';
import 'package:handelha/features/subscriptions/presentation/subscription_screen.dart';
import 'package:handelha/features/tasks/domain/task.dart';
import 'package:handelha/features/tasks/presentation/task_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBillingGateway implements BillingGateway {
  BillingCustomerSnapshot currentCustomer = const BillingCustomerSnapshot();
  List<SubscriptionOffer> liveOffers = const [
    SubscriptionOffer(
      identifier: 'handelha_pro_monthly',
      title: 'Handelha Pro شهري',
      description: 'مرونة شهرية',
      price: '89 EGP',
      periodLabel: 'شهري',
      isAnnual: false,
      track: SubscriptionPlanTrack.pro,
    ),
    SubscriptionOffer(
      identifier: 'handelha_pro_yearly',
      title: 'Handelha Pro سنوي',
      description: 'اشتراك سنوي',
      price: '699 EGP',
      periodLabel: 'سنوي',
      isAnnual: true,
      track: SubscriptionPlanTrack.pro,
    ),
  ];
  BillingPurchaseResult Function(String id)? onPurchase;
  void Function(BillingCustomerSnapshot)? _listener;
  bool configured = false;
  bool disposed = false;

  void pushCustomerUpdate(BillingCustomerSnapshot next) {
    currentCustomer = next;
    _listener?.call(next);
  }

  @override
  Future<void> configure({
    required String apiKey,
    String? appUserId,
    required void Function(BillingCustomerSnapshot snapshot) onCustomerUpdated,
  }) async {
    configured = true;
    _listener = onCustomerUpdated;
  }

  @override
  Future<void> logIn(String appUserId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<BillingCustomerSnapshot> getCustomerSnapshot() async => currentCustomer;

  @override
  Future<List<SubscriptionOffer>> getOffers() async => liveOffers;

  @override
  Future<BillingPurchaseResult> purchaseIdentifier(String identifier) async {
    if (onPurchase != null) return onPurchase!(identifier);
    return const BillingPurchaseResult(errorMessage: 'Unhandled purchase');
  }

  @override
  Future<BillingCustomerSnapshot> restorePurchases() async => currentCustomer;

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _ExpiredRepo implements SubscriptionRepository {
  @override
  Future<SubscriptionState> load(String? appUserId) async =>
      SubscriptionState(
        status: SubscriptionStatus.expired,
        tier: SubscriptionTier.free,
        expirationDate: DateTime(2026, 10, 1),
      );

  @override
  Future<SubscriptionState> purchase(String productIdentifier) => load(null);

  @override
  Future<SubscriptionState> selectPlan({
    required String? appUserId,
    required SubscriptionPlanTrack track,
    required String planId,
    required String planTitle,
    required String planPrice,
    required bool isAnnual,
  }) =>
      load(appUserId);

  @override
  Future<SubscriptionState> cancelLocalPlan(String? appUserId) =>
      load(appUserId);

  @override
  Future<SubscriptionState> restore(String? appUserId) => load(appUserId);

  @override
  Future<void> dispose() async {}
}

class _StaticAuth extends AuthNotifier {
  _StaticAuth(this._user);
  final AppUser _user;
  @override
  Future<AppUser?> build() async => _user;
}

class _EmptyToday extends TodayTasksNotifier {
  @override
  Future<List<Task>> build() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 3 & 4 — Telemetry Schema v2 & Right-Censored Cohort Evaluator', () {
    test('stores pilot segment, baseline, latency, activation Day 0, and D1/D7/D28 math without PII', () async {
      const uid = 'pilot-u1';
      final t = LocalCoreLoopTelemetry.instance;
      await t.setConsent(uid, true);
      await t.setPilotMetadata(
        uid,
        cohortTag: 'students_pilot @#\$ 01',
        segment: PilotSegment.student,
        baselineCompletionRate: 0.40,
      );

      final day0 = DateTime(2026, 10, 1, 9, 0);
      final day8 = DateTime(2026, 10, 9, 10, 0);
      final day30 = DateTime(2026, 10, 31, 11, 0);

      await t.recordEvent(uid, 'preview_shown', now: day0);
      await t.recordEvent(uid, 'confirm_latency', latencyMs: 4200, now: day0);
      await t.recordEvent(uid, 'draft_confirmed', now: day0);
      await t.recordEvent(uid, 'task_created', now: day0);
      await t.recordEvent(uid, 'task_created', now: day8);
      await t.recordEvent(uid, 'task_completed', now: day8);
      await t.recordEvent(uid, 'task_completed', now: day30);

      final snap = await t.load(uid);
      expect(snap.cohortTag, 'students_pilot01');
      expect(snap.segment, PilotSegment.student);
      expect(snap.baselineCompletionRate, 0.40);
      expect(snap.firstActivatedAt, '2026-10-01');
      expect(snap.avgConfirmLatencyMs, 4200);
      expect(snap.tasksCreated, 2);
      expect(snap.tasksCompleted, 2);
      expect(snap.commitmentCompletionRate, 1.0);
      expect(snap.distinctActiveWeeks, 3);
      expect(snap.isCohortEligibleForDay(28, DateTime(2026, 10, 20)), isFalse);
      expect(snap.isCohortEligibleForDay(28, DateTime(2026, 10, 31)), isTrue);
      expect(snap.retainedOnOrAfterDay(1), isTrue);
      expect(snap.retainedOnOrAfterDay(7), isTrue);
      expect(snap.retainedOnOrAfterDay(28), isTrue);

      final exported = snap.toAnonymousJson();
      expect(PilotCohortEvaluator.validateAnonymousPayload(exported), isNull);
      expect(jsonEncode(exported), isNot(contains(uid)));
    });

    test('PilotCohortEvaluator rejects PII leaks & unconsented snapshots and computes GO / ITERATE / STOP gates accurately', () {
      final asOf = DateTime(2026, 11, 23);

      // 1. Privacy validator rejects PII and unconsented exports
      expect(
        PilotCohortEvaluator.validateAnonymousPayload({
          'consentGranted': false,
          'previewsShown': 5,
        }),
        isNotNull,
      );
      expect(
        PilotCohortEvaluator.validateAnonymousPayload({
          'consentGranted': true,
          'email': 'leak@example.com',
        }),
        contains('email'),
      );
      expect(
        PilotCohortEvaluator.validateAnonymousPayload({
          'consentGranted': true,
          'nested': {'title': 'private task text'},
        }),
        contains('title'),
      );

      Map<String, dynamic> mkUser({
        required String seg,
        required String day0,
        required List<String> days,
        required int created,
        required int completed,
        int previews = 10,
        int confirmed = 8,
        int edited = 2,
        double baseline = 0.45,
        Map<String, int> alarms = const {'exactScheduled': 5},
      }) =>
          {
            'schema': 2,
            'consentGranted': true,
            'segment': seg,
            'baselineCompletionRate': baseline,
            'firstActivatedAt': day0,
            'previewsShown': previews,
            'draftsConfirmed': confirmed,
            'draftsEdited': edited,
            'draftsCancelled': 1,
            'confirmLatencyTotalMs': 3500 * confirmed,
            'confirmLatencySamples': confirmed,
            'voiceInputsUsed': 2,
            'textInputsUsed': 8,
            'tasksCreated': created,
            'tasksCompleted': completed,
            'alarmOutcomes': alarms,
            'activeDays': days,
          };

      // 2. GO cohort: 10 mature users (40% D28 >= 25%, completion 70% vs 45% baseline = +55.6% lift, clean alarms) + 1 leaked PII snapshot rejected
      final goSnapshots = <Map<String, dynamic>>[
        // 4 retained at D28
        for (var i = 0; i < 4; i++)
          mkUser(
            seg: 'student',
            day0: '2026-10-15',
            days: ['2026-10-15', '2026-10-23', '2026-11-18'],
            created: 10,
            completed: 8,
          ),
        // 6 churned before D28
        for (var i = 0; i < 6; i++)
          mkUser(
            seg: 'freelancer',
            day0: '2026-10-15',
            days: ['2026-10-15', '2026-10-17'],
            created: 10,
            completed: 6,
          ),
        // 2 brand-new users (not eligible for D28 yet -> right-censored!)
        for (var i = 0; i < 2; i++)
          mkUser(
            seg: 'student',
            day0: '2026-11-20',
            days: ['2026-11-20', '2026-11-22'],
            created: 5,
            completed: 4,
          ),
        // 1 invalid leaked snapshot -> must be rejected
        {'consentGranted': true, 'email': 'bad@example.com'},
      ];

      final goReport = PilotCohortEvaluator.evaluate(
        goSnapshots,
        asOf: asOf,
        minActivatedForDecision: 10,
        minD28EligibleForDecision: 10,
      );
      expect(goReport.validSnapshots, 12);
      expect(goReport.rejectedSnapshots, 1);
      expect(goReport.d28Eligible, 10);
      expect(goReport.d28Retained, 4);
      expect(goReport.d28RetentionRate, closeTo(0.40, 0.001));
      expect(goReport.relativeCompletionLift, greaterThan(0.20));
      expect(goReport.decision, PilotGateDecision.go);
      expect(goReport.bySegment.keys, containsAll(['student', 'freelancer']));
      expect(goReport.toMarkdownReport(), contains('`go`'));

      // 3. STOP cohort: D28 = 0% (< 10%)
      final stopSnapshots = [
        for (var i = 0; i < 10; i++)
          mkUser(
            seg: 'student',
            day0: '2026-10-01',
            days: ['2026-10-01'],
            created: 4,
            completed: 1,
          ),
      ];
      final stopReport = PilotCohortEvaluator.evaluate(
        stopSnapshots,
        asOf: asOf,
        minActivatedForDecision: 10,
        minD28EligibleForDecision: 10,
      );
      expect(stopReport.decision, PilotGateDecision.stopOrPivot);

      // 4. INSUFFICIENT DATA cohort: only 3 users
      final smallReport = PilotCohortEvaluator.evaluate(
        stopSnapshots.take(3).toList(),
        asOf: asOf,
        minActivatedForDecision: 10,
        minD28EligibleForDecision: 10,
      );
      expect(smallReport.decision, PilotGateDecision.insufficientData);
    });
  });

  group('Phase 5 — RevenueCat Billing Lifecycle & Honest Paywall States', () {
    test('covers unconfigured fail-closed, purchase success, user cancel, restore active/empty, expiry revocation, and Student guard', () async {
      const uid = 'billing-user-1';

      // A. Unconfigured build -> fail-closed & wipes stale local fake upgrade
      await LocalSubscriptionStore.saveForUser(
        uid,
        StoredSubscriptionRecord(
          userId: uid,
          category: UserSubscriptionCategory.regularPro,
          tier: SubscriptionTier.pro,
          activePlanId: 'pro_monthly',
          subscribedAt: DateTime(2026, 11, 1),
          isLocalActivation: true,
        ),
      );
      final unconfiguredRepo = RevenueCatSubscriptionRepository(
        storeBillingOverride: false,
      );
      final loadedUnconf = await unconfiguredRepo.load(uid);
      expect(loadedUnconf.isPro, isFalse);
      expect(loadedUnconf.status, SubscriptionStatus.free);

      final deniedSelect = await unconfiguredRepo.selectPlan(
        appUserId: uid,
        track: SubscriptionPlanTrack.pro,
        planId: 'handelha_pro_monthly',
        planTitle: 'Pro Monthly',
        planPrice: '89 EGP',
        isAnnual: false,
      );
      expect(deniedSelect.isPro, isFalse);
      expect(deniedSelect.message, contains('Google Play'));

      // B. Configured build with injectable BillingGateway
      final gateway = _FakeBillingGateway();
      final updates = <SubscriptionState>[];
      final repo = RevenueCatSubscriptionRepository(
        gateway: gateway,
        storeBillingOverride: true,
        studentVerificationOverride: false,
        apiKeyOverride: 'goog_test_key',
        onCustomerInfoChanged: updates.add,
      );

      // B1. Student track stays gated when academic verification is false
      final studentBlocked = await repo.selectPlan(
        appUserId: uid,
        track: SubscriptionPlanTrack.student,
        planId: 'student_yearly',
        planTitle: 'Student Yearly',
        planPrice: '399 EGP',
        isAnnual: true,
      );
      expect(studentBlocked.isPro, isFalse);
      expect(studentBlocked.message, contains('التحقق الأكاديمي'));

      // B2. User cancels purchase -> explicit cancellation message, stays free
      gateway.onPurchase = (_) => const BillingPurchaseResult(userCancelled: true);
      final cancelled = await repo.selectPlan(
        appUserId: uid,
        track: SubscriptionPlanTrack.pro,
        planId: 'handelha_pro_monthly',
        planTitle: 'Pro Monthly',
        planPrice: '89 EGP',
        isAnnual: false,
      );
      expect(cancelled.isPro, isFalse);
      expect(cancelled.message, contains('إلغاء عملية الشراء'));

      // B3. Purchase succeeds -> active Pro with isLocalActivation == false
      final expiry = DateTime(2026, 12, 23);
      final activeSnapshot = BillingCustomerSnapshot(
        activeEntitlements: {
          SubscriptionConfig.entitlementId: BillingEntitlementSnapshot(
            entitlementId: SubscriptionConfig.entitlementId,
            isActive: true,
            productIdentifier: 'handelha_pro_monthly',
            expirationDate: expiry,
          ),
        },
        allEntitlements: {
          SubscriptionConfig.entitlementId: BillingEntitlementSnapshot(
            entitlementId: SubscriptionConfig.entitlementId,
            isActive: true,
            productIdentifier: 'handelha_pro_monthly',
            expirationDate: expiry,
          ),
        },
      );
      gateway.onPurchase = (_) {
        gateway.currentCustomer = activeSnapshot;
        return BillingPurchaseResult(customer: activeSnapshot);
      };

      final purchased = await repo.selectPlan(
        appUserId: uid,
        track: SubscriptionPlanTrack.pro,
        planId: 'handelha_pro_monthly',
        planTitle: 'Pro Monthly',
        planPrice: '89 EGP',
        isAnnual: false,
      );
      expect(purchased.isPro, isTrue);
      expect(purchased.isLocalActivation, isFalse);
      expect(purchased.canUse(PremiumFeature.premiumAssistant), isTrue);
      expect(purchased.expirationDate, expiry);

      // B4. Restore with active entitlement returns success message
      final restoredActive = await repo.restore(uid);
      expect(restoredActive.isPro, isTrue);
      expect(restoredActive.message, contains('استعادة اشتراكك'));

      // B5. Background subscription expiry revokes Pro immediately -> expired status
      final expiredSnapshot = BillingCustomerSnapshot(
        activeEntitlements: const {},
        allEntitlements: {
          SubscriptionConfig.entitlementId: BillingEntitlementSnapshot(
            entitlementId: SubscriptionConfig.entitlementId,
            isActive: false,
            productIdentifier: 'handelha_pro_monthly',
            expirationDate: DateTime(2026, 11, 20),
          ),
        },
      );
      gateway.pushCustomerUpdate(expiredSnapshot);
      await Future<void>.delayed(Duration.zero);

      final loadedAfterExpiry = await repo.load(uid);
      expect(loadedAfterExpiry.status, SubscriptionStatus.expired);
      expect(loadedAfterExpiry.isPro, isFalse);
      expect(loadedAfterExpiry.canUse(PremiumFeature.premiumAssistant), isFalse);

      // B6. Restore when no entitlement exists returns honest empty message
      gateway.currentCustomer = const BillingCustomerSnapshot();
      final restoredEmpty = await repo.restore(uid);
      expect(restoredEmpty.isPro, isFalse);
      expect(restoredEmpty.message, contains('لم يتم العثور على اشتراك نشط'));

      await repo.dispose();
      expect(gateway.disposed, isTrue);
    });

    testWidgets(
      'SubscriptionScreen renders honest unconfigured preview banner & expired state banner',
      (tester) async {
        // 1. Default unconfigured preview shows honest Google Play notice
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('unconfigured_sub_scope'),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Directionality(
                textDirection: TextDirection.rtl,
                child: SubscriptionScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('الدفع عبر Google Play غير مفعّل في هذا البناء'),
          findsOneWidget,
        );

        // 2. Expired subscription shows explicit expiry banner
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('expired_sub_scope'),
            overrides: [
              subscriptionRepositoryProvider.overrideWithValue(_ExpiredRepo()),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Directionality(
                textDirection: TextDirection.rtl,
                child: SubscriptionScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('انتهت صلاحية اشتراكك السابق'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ChatScreen token sheet hides unconfigured upgrade CTA and shows honest free pilot message',
      (tester) async {
        final session = ChatSessionController();
        final fakeUser = AppUser(
          id: 'chat-pilot-u',
          email: 'u@example.com',
          displayName: 'مستخدم',
          usageType: OnboardingUsageType.study,
          tone: AssistantTone.friendly,
          focusHours: const [9],
          onboardingComplete: true,
          createdAt: DateTime(2026, 11, 22),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authNotifierProvider.overrideWith(() => _StaticAuth(fakeUser)),
              todayTasksProvider.overrideWith(_EmptyToday.new),
              chatSessionProvider.overrideWith((ref) => session),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(body: ChatScreen()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('التوكنز اليومية'));
        await tester.pumpAndSettle();

        expect(
          find.text('اشترك في هندلها Pro لتوكنز غير محدودة'),
          findsNothing,
        );
        expect(
          find.textContaining('الدفع عبر Google Play غير مفعّل حاليًا'),
          findsOneWidget,
        );
      },
    );
  });

  group('Phase 5 — Unit Economics & Channel Gate Calculator', () {
    test('blocks paid scaling whenever Phase 4b D28 retention gate has not passed', () {
      final report = UnitEconomicsCalculator.evaluate(
        const UnitEconomicsInput(
          channelName: 'meta_ads_test',
          currency: 'EGP',
          phase4bD28GatePassed: false,
          channelSpend: 1000,
          installedUsers: 200,
          activatedUsers: 120,
          retainedD28Users: 40,
          paidSubscribers: 20,
          grossPricePerPeriod: 89,
        ),
      );
      expect(
        report.decision,
        MonetizationGateDecision.blockedByPhase4bRetention,
      );
    });

    test('computes net contribution after Play fees, refunds, CAC, payback, and Go/Stop verdicts accurately', () {
      // 1. STOP when contribution margin does not cover CAC
      final badChannel = UnitEconomicsCalculator.evaluate(
        const UnitEconomicsInput(
          channelName: 'expensive_ads',
          currency: 'EGP',
          phase4bD28GatePassed: true,
          channelSpend: 10000,
          installedUsers: 100,
          activatedUsers: 50,
          retainedD28Users: 15,
          paidSubscribers: 5,
          refundedSubscribers: 1,
          grossPricePerPeriod: 89,
          googlePlayFeeRate: 0.15,
          monthlySupportCostPerPaidUser: 5,
          expectedPaidLifetimeMonths: 3,
        ),
      );
      expect(badChannel.netPaidSubscribers, 4);
      expect(badChannel.netRevenuePerPeriod, closeTo(75.65, 0.01));
      expect(badChannel.decision, MonetizationGateDecision.stopDoNotScale);

      // 2. GO when Phase 4b passed, LTV:CAC >= 2x, payback <= 6 mo, >= 5 net paid
      final healthyChannel = UnitEconomicsCalculator.evaluate(
        const UnitEconomicsInput(
          channelName: 'egyptian_uni_telegram',
          currency: 'EGP',
          phase4bD28GatePassed: true,
          channelSpend: 1200,
          installedUsers: 250,
          activatedUsers: 150,
          retainedD28Users: 45,
          paidSubscribers: 15,
          refundedSubscribers: 1,
          grossPricePerPeriod: 89,
          googlePlayFeeRate: 0.15,
          monthlySupportCostPerPaidUser: 5,
          expectedPaidLifetimeMonths: 4,
        ),
      );
      expect(healthyChannel.netPaidSubscribers, 14);
      expect(healthyChannel.monthlyNetContributionPerPaidUser, closeTo(70.65, 0.01));
      expect(healthyChannel.contributionLtv, closeTo(282.6, 0.1));
      expect(healthyChannel.cacPerPaidCustomer, closeTo(85.71, 0.1));
      expect(healthyChannel.ltvToCacRatio, greaterThan(3.0));
      expect(healthyChannel.paybackMonths, lessThan(2.0));
      expect(healthyChannel.decision, MonetizationGateDecision.goScaleChannel);
      expect(
        healthyChannel.toMarkdownReport(),
        contains('`goScaleChannel`'),
      );
    });
  });
}
