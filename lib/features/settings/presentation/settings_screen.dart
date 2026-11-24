import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/locale/language_controller.dart';
import '../../../app/mode/student_mode_controller.dart';
import '../../../app/theme/app_theme_extension.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../core/cloud/cloud_sync_engine.dart';
import '../../../core/cloud/firebase_cloud_service.dart';
import '../../../core/database/handelha_sqlite_store.dart';
import '../../../core/database/local_backup_service.dart';
import '../../../core/database/shared_preferences_conversation_store.dart';
import '../../../core/result/result.dart';
import '../../../core/telemetry/local_core_loop_telemetry.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../../shared/widgets/handelha_bottom_nav.dart';
import '../../../shared/widgets/handelha_date_time_picker.dart';
import '../../../shared/widgets/handelha_feedback.dart';
import '../../../shared/widgets/handelha_header.dart';
import '../../../shared/widgets/handelha_privacy_policy_sheet.dart';
import '../../../shared/widgets/handelha_segmented_switch.dart';
import '../../assistant/data/user_energy_preferences.dart';
import '../../assistant/presentation/assistant_providers.dart';
import '../../onboarding/presentation/energy_preferences_sheet.dart';
import '../../authentication/domain/app_user.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../../notifications/alarm_reminder_store.dart';
import '../../notifications/local_notification_service.dart';
import '../../notifications/notification_preferences.dart';
import '../../projects/presentation/project_providers.dart';
import '../../subscriptions/data/subscription_repository.dart';
import '../../subscriptions/domain/subscription_models.dart';
import '../../subscriptions/presentation/subscription_providers.dart';
import '../../tasks/presentation/task_providers.dart';

/// شاشة الإعدادات.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  NotificationPreferences _notifPrefs = const NotificationPreferences();
  String? _loadedUserId;
  bool _isSyncing = false;
  int _pendingOutboxCount = 0;

  Future<void> _loadNotifPrefs(String userId) async {
    final prefs = await LocalNotificationPreferences.load(userId);
    final pending = HandelhaSqliteStore.isNativeMobilePlatform
        ? await HandelhaSqliteStore.instance.pendingOutboxCount(userId)
        : HandelhaSqliteStore.instance.cachedPendingOutboxCount(userId);
    if (!mounted) return;
    setState(() {
      _notifPrefs = prefs;
      _pendingOutboxCount = pending;
      _loadedUserId = userId;
    });
  }

  Future<void> _syncNow(String userId) async {
    if (_isSyncing) return;
    final appLang = ref.read(appLanguageProvider);
    setState(() => _isSyncing = true);
    try {
      final res = await CloudSyncEngine.instance.syncUser(userId);
      final pending =
          await HandelhaSqliteStore.instance.pendingOutboxCount(userId);
      ref.invalidate(allTasksProvider);
      ref.invalidate(projectsProvider);
      ref.invalidate(focusSessionsProvider);
      if (!mounted) return;
      setState(() {
        _pendingOutboxCount = pending;
        _isSyncing = false;
      });
      if (res is Success<SyncRunSummary>) {
        final s = res.data;
        if (s.isClean) {
          HandelhaFeedback.showSuccess(
            context,
            appLang.tr(
              'تمت المزامنة (رفع ${ArabicFormatters.toArabicDigits(s.pushedCount)} • تحديث ${ArabicFormatters.toArabicDigits(s.pulledCount)})',
              'Synced (pushed ${s.pushedCount} • pulled ${s.pulledCount})',
            ),
          );
        } else {
          HandelhaFeedback.showError(
            context,
            s.lastError ??
                appLang.tr(
                  'تعذّر إتمام بعض عمليات المزامنة وسيتم إعادة المحاولة تلقائيًا.',
                  'Some items could not sync yet and will retry automatically.',
                ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _toggleNotifications(String userId, bool enabled) async {
    final updated = _notifPrefs.copyWith(enabled: enabled);
    setState(() => _notifPrefs = updated);
    await LocalNotificationPreferences.save(userId, updated);
    if (enabled) {
      final tasks = ref.read(allTasksProvider).value ?? const [];
      await LocalNotificationService.instance.rescheduleTasks(tasks);
    } else {
      await LocalNotificationService.instance.cancelAll();
    }
  }

  Future<void> _showQuietHoursSheet(String userId) async {
    final c = context.appColors;
    var startTime = TimeOfDay(
      hour: _notifPrefs.quietHoursStartMinutes ~/ 60,
      minute: _notifPrefs.quietHoursStartMinutes % 60,
    );
    var endTime = TimeOfDay(
      hour: _notifPrefs.quietHoursEndMinutes ~/ 60,
      minute: _notifPrefs.quietHoursEndMinutes % 60,
    );
    final appLang = ref.read(appLanguageProvider);
    final isEn = appLang.isEnglish;

    String formatTod(TimeOfDay tod) {
      final now = DateTime.now();
      return ArabicFormatters.timeOfDayAr(
        DateTime(now.year, now.month, now.day, tod.hour, tod.minute),
      );
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: c.border.withValues(alpha: 0.7)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.nights_stay_rounded,
                        color: c.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        appLang.tr(
                          'أوقات الهدوء والتذكير',
                          'Quiet Hours & Reminders',
                        ),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _QuietTimeTile(
                  icon: Icons.bedtime_outlined,
                  label: appLang.tr('تبدأ ساعات الهدوء', 'Quiet starts'),
                  timeLabel: formatTod(startTime),
                  onTap: () async {
                    final picked = await HandelhaDateTimePicker.showTimeSheet(
                      ctx,
                      initialTime: startTime,
                      title: isEn ? 'Start Quiet Hours' : 'بداية وقت الهدوء',
                    );
                    if (picked != null) {
                      setSheetState(() => startTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                _QuietTimeTile(
                  icon: Icons.wb_sunny_outlined,
                  label: appLang.tr('تنتهي ساعات الهدوء', 'Quiet ends'),
                  timeLabel: formatTod(endTime),
                  onTap: () async {
                    final picked = await HandelhaDateTimePicker.showTimeSheet(
                      ctx,
                      initialTime: endTime,
                      title: isEn ? 'End Quiet Hours' : 'نهاية وقت الهدوء',
                    );
                    if (picked != null) {
                      setSheetState(() => endTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    appLang.tr('حفظ ساعات الهدوء', 'Save Quiet Hours'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved == true) {
      final next = _notifPrefs.copyWith(
        quietHoursStartMinutes: startTime.hour * 60 + startTime.minute,
        quietHoursEndMinutes: endTime.hour * 60 + endTime.minute,
      );
      setState(() => _notifPrefs = next);
      await LocalNotificationPreferences.save(userId, next);
      if (next.enabled) {
        final tasks = ref.read(allTasksProvider).value ?? const [];
        await LocalNotificationService.instance.rescheduleTasks(tasks);
      }
      if (mounted) {
        HandelhaFeedback.showSuccess(
          context,
          appLang.tr(
            'تم تحديث ساعات الهدوء بنجاح!',
            'Quiet hours updated!',
          ),
        );
      }
    }
  }

  Future<void> _openAccountSheet(AppUser user) async {
    final c = context.appColors;
    final appLang = ref.read(appLanguageProvider);
    final subState = ref.read(subscriptionProvider).value;
    final category = subState?.isPro == true
        ? subState!.category
        : user.subscriptionCategory;
    final planName = subState?.isPro == true
        ? subState!.resolvedPlanTitle(isEnglish: appLang.isEnglish)
        : (user.activePlanId != null
            ? SubscriptionState(
                status: SubscriptionStatus.active,
                tier: category == UserSubscriptionCategory.student
                    ? SubscriptionTier.student
                    : SubscriptionTier.pro,
                activePlanId: user.activePlanId,
              ).resolvedPlanTitle(isEnglish: appLang.isEnglish)
            : appLang.tr('الباقة المجانية', 'Free Plan'));
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: c.border.withValues(alpha: 0.7)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.manage_accounts_rounded,
                      color: c.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      appLang.tr(
                        'إدارة الحساب والبيانات الشخصية',
                        'Account & Personal Data',
                      ),
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border.withValues(alpha: 0.75)),
                ),
                child: Text(
                  appLang.isEnglish
                      ? 'Name: ${ArabicFormatters.trData(user.displayName ?? user.firstName)}\nEmail: ${user.email ?? '—'}\nTier: ${category.label(isEnglish: true)}\nCurrent Plan: $planName'
                      : 'الاسم: ${user.displayName ?? user.firstName}\nالبريد: ${user.email ?? '—'}\nالتصنيف: ${category.label(isEnglish: false)}\nالخطة الحالية: $planName',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: c.textSecondary,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _confirmDeleteAccount(user);
                },
                child: Text(
                  appLang.tr(
                    'حذف الحساب وكل بياناته نهائيًا',
                    'Delete Account & All Data Permanently',
                  ),
                  style: TextStyle(
                    color: c.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPrivacySheet(AppUser user) async {
    final c = context.appColors;
    final appLang = ref.read(appLanguageProvider);
    final isExcluded = LocalCoreLoopTelemetry.isExcludedAccount(user.id);
    final initialSnap = isExcluded
        ? const CoreLoopTelemetrySnapshot(consentGranted: false)
        : await LocalCoreLoopTelemetry.instance.load(user.id);
    var telemetryEnabled = initialSnap.consentGranted;
    PilotSegment? selectedSegment = initialSnap.segment;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: c.border.withValues(alpha: 0.7)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: c.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      appLang.tr(
                        'خصوصيتك تحت سيطرتك',
                        'Your Privacy Under Your Control',
                      ),
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                appLang.tr(
                  'كل مهامك ومحادثاتك محفوظة على جهازك فقط.',
                  'All your tasks and conversations stay locally on your device only.',
                ),
                style: TextStyle(fontSize: 13.5, color: c.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 19,
                          color: c.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appLang.tr(
                                  'مقاييس جودة المساعد (مجهولة ومغلقة افتراضيًا)',
                                  'Anonymous Core-Loop Counters (Opt-In)',
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isExcluded
                                    ? appLang.tr(
                                        'حساب المعاينة مستبعد تلقائيًا من أي قياسات.',
                                        'Preview QA accounts are automatically excluded from telemetry.',
                                      )
                                    : appLang.tr(
                                        'تحسب فقط معدلات التأكيد والتعديل والإلغاء بدون أي نصوص مهام أو بيانات شخصية.',
                                        'Counts confirm/edit/cancel rates only — zero task text or PII stored.',
                                      ),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: c.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: telemetryEnabled,
                          onChanged: isExcluded
                              ? null
                              : (val) async {
                                  await LocalCoreLoopTelemetry.instance
                                      .setConsent(user.id, val);
                                  setSheetState(() => telemetryEnabled = val);
                                },
                        ),
                      ],
                    ),
                    if (telemetryEnabled && !isExcluded) ...[
                      const SizedBox(height: 8),
                      Text(
                        appLang.tr(
                          'فئتك (اختياري ومجهول للتجربة):',
                          'Anonymous pilot segment (optional):',
                        ),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final seg in PilotSegment.values)
                            ChoiceChip(
                              label: Text(
                                switch (seg) {
                                  PilotSegment.student =>
                                    appLang.tr('طالب', 'Student'),
                                  PilotSegment.freelancer =>
                                    appLang.tr('مستقل', 'Freelancer'),
                                  PilotSegment.employee =>
                                    appLang.tr('موظف', 'Employee'),
                                  PilotSegment.other =>
                                    appLang.tr('أخرى', 'Other'),
                                },
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              selected: selectedSegment == seg,
                              onSelected: (_) async {
                                await LocalCoreLoopTelemetry.instance
                                    .setPilotMetadata(user.id, segment: seg);
                                setSheetState(() => selectedSegment = seg);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final snap = await LocalCoreLoopTelemetry.instance
                              .load(user.id);
                          final pretty = const JsonEncoder.withIndent('  ')
                              .convert(snap.toAnonymousJson());
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (!mounted) return;
                          await HandelhaDialog.showCustom<void>(
                            context,
                            builder: (dCtx) {
                              final dc = dCtx.appColors;
                              return Dialog(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                insetPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 24,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: dc.surface,
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(color: dc.border),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        appLang.tr(
                                          'ملخص المقاييس المجهول (JSON)',
                                          'Anonymous Metrics Export (JSON)',
                                        ),
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          color: dc.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        height: 220,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: dc.surfaceSoft,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(color: dc.border),
                                        ),
                                        child: SingleChildScrollView(
                                          child: SelectableText(
                                            pretty,
                                            textDirection: TextDirection.ltr,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: dc.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  Navigator.of(dCtx).pop(),
                                              child: Text(
                                                appLang.tr('إغلاق', 'Close'),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: FilledButton.icon(
                                              onPressed: () async {
                                                await Clipboard.setData(
                                                  ClipboardData(text: pretty),
                                                );
                                                if (!dCtx.mounted) return;
                                                Navigator.of(dCtx).pop();
                                                if (mounted) {
                                                  HandelhaFeedback.showSuccess(
                                                    context,
                                                    appLang.tr(
                                                      'تم نسخ الملخص المجهول!',
                                                      'Anonymous metrics copied!',
                                                    ),
                                                  );
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.copy_rounded,
                                                size: 16,
                                              ),
                                              label: Text(
                                                appLang.tr('نسخ', 'Copy'),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.data_object_rounded, size: 17),
                        label: Text(
                          appLang.tr(
                            'تصدير ملخص المقاييس المجهول (JSON)',
                            'Export Anonymous Metrics (JSON)',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  HandelhaPrivacyPolicySheet.show(context);
                },
                icon: const Icon(Icons.policy_outlined),
                label: Text(
                  appLang.tr(
                    'عرض سياسة الخصوصية وشروط الاستخدام',
                    'View Privacy Policy & Terms of Use',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  final res = await LocalBackupService.instance.exportForUser(
                    user.id,
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (res is Success<String> && mounted) {
                    var preview = res.data;
                    try {
                      preview = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(jsonDecode(res.data));
                    } catch (_) {}
                    HandelhaDialog.showCustom<void>(
                      context,
                      builder: (dCtx) {
                        final dc = dCtx.appColors;
                        return Dialog(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          insetPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: dc.surface,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: dc.border),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: dc.primarySoft,
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Icon(
                                        Icons.data_object_rounded,
                                        color: dc.primary,
                                        size: 19,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        appLang.tr(
                                          'نسخة احتياطية (JSON)',
                                          'Backup (JSON)',
                                        ),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: dc.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: 240,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: dc.surfaceSoft,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: dc.border),
                                  ),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      preview,
                                      textDirection: TextDirection.ltr,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: dc.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.of(dCtx).pop(),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        child: Text(appLang.tr('إغلاق', 'Close')),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: preview),
                                          );
                                          if (!dCtx.mounted) return;
                                          Navigator.of(dCtx).pop();
                                          if (mounted) {
                                            HandelhaFeedback.showSuccess(
                                              context,
                                              appLang.tr(
                                                'تم نسخ النسخة الاحتياطية!',
                                                'Backup copied to clipboard!',
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          size: 17,
                                        ),
                                        label: Text(appLang.tr('نسخ', 'Copy')),
                                        style: FilledButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
                icon: const Icon(Icons.download_outlined),
                label: Text(
                  appLang.tr(
                    'تصدير نسخة احتياطية (JSON)',
                    'Export Backup (JSON)',
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _openRestoreBackupDialog(user);
                },
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(
                  appLang.tr(
                    'استعادة نسخة احتياطية (JSON)',
                    'Restore Backup (JSON)',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await SharedPreferencesConversationStore.clearForUser(user.id);
                  await ref.read(chatSessionProvider).newConversation();
                  if (mounted) {
                    HandelhaFeedback.showSuccess(
                      context,
                      appLang.tr(
                        'تم مسح سجل المحادثات.',
                        'Chat history cleared.',
                      ),
                    );
                  }
                },
                icon: Icon(Icons.delete_sweep_outlined, color: c.danger),
                label: Text(
                  appLang.tr(
                    'مسح سجل محادثات المساعد',
                    'Clear Assistant Chat History',
                  ),
                  style: TextStyle(color: c.danger),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.danger.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _confirmDeleteAccount(user);
                },
                icon: Icon(Icons.person_remove_outlined, color: c.danger, size: 18),
                label: Text(
                  appLang.tr(
                    'حذف الحساب وكل بياناته نهائيًا',
                    'Delete Account & All Data Permanently',
                  ),
                  style: TextStyle(
                    color: c.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }

  Future<void> _openRestoreBackupDialog(AppUser user) async {
    final appLang = ref.read(appLanguageProvider);
    final controller = TextEditingController();
    String? errorText;
    BackupRestoreSummary? preview;
    bool restoring = false;

    await HandelhaDialog.showCustom<void>(
      context,
      builder: (dCtx) {
        final dc = dCtx.appColors;
        return StatefulBuilder(
          builder: (dCtx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: dc.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: dc.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: dc.primarySoft,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.restore_page_outlined,
                            color: dc.primary,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            appLang.tr(
                              'استعادة نسخة احتياطية (JSON)',
                              'Restore Backup (JSON)',
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: dc.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      appLang.tr(
                        'الصق نص النسخة الاحتياطية (JSON) للمعاينة قبل الاستعادة الكاملة والآمنة.',
                        'Paste your JSON backup to preview its contents before safe atomic restore.',
                      ),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: dc.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      maxLines: 5,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(fontSize: 11.5, color: dc.textPrimary),
                      decoration: InputDecoration(
                        hintText: '{"schema": 2, "product": "handelha", ...}',
                        filled: true,
                        fillColor: dc.surfaceSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: dc.border),
                        ),
                      ),
                      onChanged: (raw) {
                        if (raw.trim().isEmpty) {
                          setDialogState(() {
                            preview = null;
                            errorText = null;
                          });
                          return;
                        }
                        final check = LocalBackupService.instance.validateBackup(
                          userId: user.id,
                          backupJson: raw,
                        );
                        setDialogState(() {
                          switch (check) {
                            case Success<BackupRestoreSummary>(data: final s):
                              preview = s;
                              errorText = null;
                            case Failure<BackupRestoreSummary>(failure: final f):
                              preview = null;
                              errorText = f.message;
                          }
                        });
                      },
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: dc.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (preview != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: dc.primarySoft.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          appLang.isEnglish
                              ? 'Valid v${preview!.schemaVersion} backup: ${preview!.tasksCount} tasks, ${preview!.projectsCount} projects, ${preview!.focusSessionsCount} focus sessions, ${preview!.examGradesCount} grades, ${preview!.alarmRemindersCount} alarms.'
                              : 'نسخة صالحة (إصدار ${preview!.schemaVersion}): ${preview!.tasksCount} مهام، ${preview!.projectsCount} مشاريع، ${preview!.focusSessionsCount} جلسات تركيز، ${preview!.examGradesCount} درجات، ${preview!.alarmRemindersCount} منبهات.',
                          style: TextStyle(
                            fontSize: 12,
                            color: dc.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: restoring
                                ? null
                                : () => Navigator.of(dCtx).pop(),
                            child: Text(appLang.tr('إلغاء', 'Cancel')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: (preview == null || restoring)
                                ? null
                                : () async {
                                    setDialogState(() => restoring = true);
                                    final res = await LocalBackupService.instance
                                        .restoreForUser(
                                      userId: user.id,
                                      backupJson: controller.text,
                                    );
                                    if (!dCtx.mounted) return;
                                    setDialogState(() => restoring = false);
                                    switch (res) {
                                      case Failure<BackupRestoreSummary>(
                                          failure: final f
                                        ):
                                        setDialogState(
                                          () => errorText = f.message,
                                        );
                                      case Success<BackupRestoreSummary>(
                                          data: final summary
                                        ):
                                        Navigator.of(dCtx).pop();
                                        ref.invalidate(todayTasksProvider);
                                        ref.invalidate(allTasksProvider);
                                        ref.invalidate(projectsProvider);
                                        ref.invalidate(focusSessionsProvider);
                                        ref.invalidate(
                                          userEnergyPreferencesProvider,
                                        );
                                        ref.invalidate(alarmReminderProvider);
                                        await _loadNotifPrefs(user.id);
                                        if (mounted) {
                                          HandelhaFeedback.showSuccess(
                                            context,
                                            appLang.isEnglish
                                                ? 'Restored ${summary.tasksCount} tasks, ${summary.projectsCount} projects, and ${summary.focusSessionsCount} focus sessions.'
                                                : 'تمت استعادة ${summary.tasksCount} مهام و${summary.projectsCount} مشاريع و${summary.focusSessionsCount} جلسات تركيز بنجاح!',
                                          );
                                        }
                                    }
                                  },
                            child: Text(
                              restoring
                                  ? appLang.tr('جاري الاستعادة...', 'Restoring...')
                                  : appLang.tr('استعادة الآن', 'Restore Now'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _confirmDeleteAccount(AppUser user) async {
    final appLang = ref.read(appLanguageProvider);
    final confirmed = await HandelhaDialog.confirm(
      context,
      icon: Icons.person_remove_outlined,
      title: appLang.tr('حذف الحساب نهائيًا؟', 'Delete Account Permanently?'),
      message: appLang.tr(
        'سيتم مسح جميع المهام والمشروعات والجلسات والمحادثات والتنبيهات المرتبطة بهذا الحساب نهائيًا من الجهاز ولا يمكن التراجع عن هذا الإجراء.',
        'All tasks, projects, focus sessions, conversations, and reminders linked to this account will be permanently erased from this device. This action cannot be undone.',
      ),
      confirmLabel: appLang.tr('حذف نهائي', 'Delete Forever'),
      cancelLabel: appLang.tr('إلغاء', 'Cancel'),
      isDanger: true,
    );
    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).deleteAccount();
    }
  }

  Future<void> _confirmSignOut() async {
    final appLang = ref.read(appLanguageProvider);
    final confirmed = await HandelhaDialog.confirm(
      context,
      icon: Icons.logout_rounded,
      title: appLang.tr('تسجيل الخروج؟', 'Sign Out?'),
      message: appLang.tr(
        'تقدر ترجع تدخل تاني في أي وقت ومهامك هتفضل محفوظة.',
        'You can sign back in anytime and your tasks will remain saved.',
      ),
      confirmLabel: appLang.tr('تسجيل الخروج', 'Sign Out'),
      cancelLabel: appLang.tr('خليك', 'Stay'),
    );
    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;
    final user = ref.watch(authNotifierProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final appLang = ref.watch(appLanguageProvider);
    final energyPrefs = ref.watch(userEnergyPreferencesProvider);
    final isStudentMode = ref.watch(isStudentModeActiveProvider);
    final subState = ref.watch(subscriptionProvider).value;
    final hasStudentSub = subState?.isStudent ?? false;
    final accountCategory = subState?.isPro == true
        ? subState!.category
        : (user?.subscriptionCategory ?? UserSubscriptionCategory.free);
    final isEn = appLang.isEnglish;

    if (user != null && _loadedUserId != user.id) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadNotifPrefs(user.id),
      );
    }

    final isFriendlyTone = (user?.tone ?? AssistantTone.friendly) ==
        AssistantTone.friendly;

    return Scaffold(
      extendBody: true,
      body: HandelhaAmbientBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 114),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HandelhaHeader(
                  title: appLang.tr('الإعدادات', 'Settings'),
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),

                // Account card
                Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: user == null ? null : () => _openAccountSheet(user),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 22,
                                color: c.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  ArabicFormatters.trData(
                                    user?.displayName ??
                                        user?.firstName ??
                                        appLang.tr(
                                          'مستخدم هندلها',
                                          'Handelha User',
                                        ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accountCategory ==
                                              UserSubscriptionCategory.student
                                          ? const Color(0xFF4F46E5)
                                              .withValues(alpha: 0.14)
                                          : accountCategory ==
                                                  UserSubscriptionCategory
                                                      .regularPro
                                              ? c.primarySoft
                                              : c.surfaceSoft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      accountCategory.shortBadge(
                                        isEnglish: isEn,
                                      ),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: accountCategory ==
                                                UserSubscriptionCategory.student
                                            ? const Color(0xFF4F46E5)
                                            : accountCategory ==
                                                    UserSubscriptionCategory
                                                        .regularPro
                                                ? c.primary
                                                : c.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            appLang.tr('إدارة الحساب والبيانات الشخصية', 'Account & Personal Data'),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Energy & Productivity Profile Card
                Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => EnergyPreferencesWizardSheet.show(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: c.primarySoft,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              Icons.bolt_rounded,
                              color: c.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appLang.tr(
                                    'بصمة طاقتك وتقسيم التاسكات والمشاريع ⚡',
                                    'Energy Profile & Task Breakdown ⚡',
                                  ),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  appLang.isEnglish
                                      ? '${energyPrefs.peakLabelEn} • ${energyPrefs.preferredSessionMinutes}m blocks'
                                      : '${energyPrefs.peakLabelAr} • جلسات ${ArabicFormatters.toArabicDigits(energyPrefs.preferredSessionMinutes)} د',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: c.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isEn
                                ? Icons.chevron_right_rounded
                                : Icons.chevron_left_rounded,
                            color: c.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // وضع الاستخدام (الوضع العادي / وضع الطالب)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appLang.tr('وضع التطبيق', 'App Mode'),
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (isStudentMode)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF0D9488)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          appLang.tr('وضع الطالب', 'Student'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  appLang.tr(
                    'تقديرات الامتحانات وأوسمة الدراسة بتظهر بس لما تختار وضع الطالب.',
                    'Exam grades and academic badges only appear when Student Mode is active.',
                  ),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                HandelhaSegmentedSwitch<bool>(
                  selected: isStudentMode,
                  onChanged: (next) async {
                    if (hasStudentSub && !next) {
                      HandelhaFeedback.showInfo(
                        context,
                        appLang.tr(
                          'وضع الطالب مفعّل تلقائيًا مع اشتراك الطلاب الحالي.',
                          'Student Mode stays active with your current Student plan.',
                        ),
                      );
                      return;
                    }
                    await ref
                        .read(studentModeControllerProvider.notifier)
                        .setStudentMode(next);
                    if (!context.mounted) return;
                    HandelhaFeedback.showSuccess(
                      context,
                      next
                          ? appLang.tr(
                              'تم تفعيل وضع الطالب — ميزات الامتحانات والتقديرات بقت ظاهرة دلوقتي',
                              'Student Mode enabled — exam grade features are now active',
                            )
                          : appLang.tr(
                              'تم التبديل للوضع العادي',
                              'Switched to Standard Mode',
                            ),
                    );
                  },
                  options: [
                    HandelhaSegmentOption(
                      value: false,
                      label: appLang.tr('الوضع العادي', 'Standard'),
                      icon: Icons.person_outline_rounded,
                    ),
                    HandelhaSegmentOption(
                      value: true,
                      label: appLang.tr('وضع الطالب', 'Student'),
                      icon: Icons.school_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // لغة التطبيق والمساعد (عربي مصري / English)
                Text(
                  appLang.tr('لغة التطبيق والمساعد', 'App & Assistant Language'),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                HandelhaSegmentedSwitch<AppLanguage>(
                  selected: appLang,
                  options: const [
                    HandelhaSegmentOption(
                      value: AppLanguage.arEg,
                      label: 'عربي مصري',
                      icon: Icons.translate_rounded,
                    ),
                    HandelhaSegmentOption(
                      value: AppLanguage.en,
                      label: 'English',
                      icon: Icons.language_rounded,
                    ),
                  ],
                  onChanged: (lang) =>
                      ref.read(appLanguageProvider.notifier).setLanguage(lang),
                ),
                const SizedBox(height: 18),
                // المظهر (Theme 3-way)
                Text(
                  appLang.tr('المظهر', 'Appearance'),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? c.surfaceSoft : const Color(0xFFE1E8E4),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ThemeOptionPill(
                          label: appLang.tr('فاتح', 'Light'),
                          selected: themeMode == ThemeMode.light,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setMode(ThemeMode.light),
                        ),
                      ),
                      Expanded(
                        child: _ThemeOptionPill(
                          label: appLang.tr('داكن', 'Dark'),
                          selected: themeMode == ThemeMode.dark,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setMode(ThemeMode.dark),
                        ),
                      ),
                      Expanded(
                        child: _ThemeOptionPill(
                          label: appLang.tr('تلقائي', 'Auto'),
                          selected: themeMode == ThemeMode.system,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setMode(ThemeMode.system),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Notification card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: user == null
                              ? null
                              : () => _showQuietHoursSheet(user.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.notifications_none_rounded,
                                    size: 21,
                                    color: c.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      appLang.tr('فكّرني باللي يهمّني', 'Remind me of what matters'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Builder(
                                builder: (_) {
                                  String fmtTime(int mins, bool isEn) {
                                    final h24 = (mins ~/ 60) % 24;
                                    final m = mins % 60;
                                    final isPm = h24 >= 12;
                                    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
                                    final mm = m == 0
                                        ? ''
                                        : ':${m.toString().padLeft(2, '0')}';
                                    if (isEn) {
                                      final enMm =
                                          ':${m.toString().padLeft(2, '0')}';
                                      return '$h12$enMm ${isPm ? 'PM' : 'AM'}';
                                    }
                                    final arTime = ArabicFormatters.toArabicDigits(
                                      '$h12$mm',
                                    );
                                    return '$arTime ${isPm ? 'بالليل' : 'الصبح'}';
                                  }

                                  final startLabel = fmtTime(
                                    _notifPrefs.quietHoursStartMinutes,
                                    appLang.isEnglish,
                                  );
                                  final endLabel = fmtTime(
                                    _notifPrefs.quietHoursEndMinutes,
                                    appLang.isEnglish,
                                  );
                                  return Text(
                                    appLang.isEnglish
                                        ? 'From $endLabel to $startLabel'
                                        : 'من $endLabel لـ $startLabel',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: c.textSecondary,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Switch(
                        value: _notifPrefs.enabled,
                        onChanged: user == null
                            ? null
                            : (v) => _toggleNotifications(user.id, v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Storage & Sync Status (strictly truthful about active mode)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.primarySoft,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          FirebaseCloudService.instance.isEnabled
                              ? Icons.cloud_sync_outlined
                              : Icons.phonelink_lock_rounded,
                          color: c.primary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              FirebaseCloudService.instance.isEnabled
                                  ? appLang.tr(
                                      'حالة المزامنة السحابية',
                                      'Cloud Sync Status',
                                    )
                                  : appLang.tr(
                                      'التخزين محلي على جهازك',
                                      'Local-First Storage',
                                    ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (_) {
                                final syncStatus =
                                    FirebaseCloudService.instance.lastSyncStatus;
                                final isLocalGuest =
                                    user?.id.startsWith('local_') ?? false;
                                final sqliteActive =
                                    HandelhaSqliteStore.instance.isOpen;
                                final engineLine = sqliteActive
                                    ? appLang.tr(
                                        'محرك التخزين: SQLite محلي منظّم',
                                        'Storage engine: Normalized local SQLite',
                                      )
                                    : appLang.tr(
                                        'التخزين محلي على هذا الجهاز فقط.',
                                        'Stored locally on this device only.',
                                      );
                                final statusText = isLocalGuest
                                    ? appLang.tr(
                                        '$engineLine. إنت شغال حاليًا بدون حساب — تقدر تربط حساب في أي وقت بدون ما تفقد ولا مهمة.',
                                        '$engineLine. You are using a local workspace — link an account anytime without losing a single task.',
                                      )
                                    : !FirebaseCloudService.instance.isEnabled
                                        ? appLang.tr(
                                            '$engineLine. كل بياناتك محفوظة محليًا على الجهاز فقط. استخدم التصدير والاستعادة (JSON) من قسم الخصوصية لحفظ نسختك.',
                                            '$engineLine. All workspace data stays on this device. Use Export & Restore (JSON) in Privacy anytime.',
                                          )
                                        : (syncStatus.lastError != null
                                            ? syncStatus.lastError!
                                            : (syncStatus.lastSyncedAt != null
                                                ? appLang.tr(
                                                    'آخر مزامنة ناجحة: ${syncStatus.lastSyncedAt!.toLocal()}',
                                                    'Last synced: ${syncStatus.lastSyncedAt!.toLocal()}',
                                                  )
                                                : appLang.tr(
                                                    'المزامنة السحابية التزايدية (Delta Sync) مفعّلة لكل مهمة ومشروع.',
                                                    'Per-item incremental cloud delta sync is enabled.',
                                                  )));
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: syncStatus.lastError != null &&
                                                !isLocalGuest
                                            ? c.danger
                                            : c.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                    if (_pendingOutboxCount > 0 &&
                                        FirebaseCloudService.instance.isEnabled &&
                                        !isLocalGuest) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        appLang.tr(
                                          'بانتظار المزامنة: ${ArabicFormatters.toArabicDigits(_pendingOutboxCount)} تعديلات',
                                          'Pending sync: $_pendingOutboxCount changes',
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: c.primary,
                                        ),
                                      ),
                                    ],
                                    if (isLocalGuest) ...[
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            context.push('/signup?link=true'),
                                        icon: const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          appLang.tr(
                                            'ربط بحساب لحفظ ومزامنة بياناتك',
                                            'Link Account to Back Up & Sync',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ] else if (FirebaseCloudService
                                            .instance.isEnabled &&
                                        user != null) ...[
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        onPressed: _isSyncing
                                            ? null
                                            : () => _syncNow(user.id),
                                        icon: _isSyncing
                                            ? SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: c.primary,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.sync_rounded,
                                                size: 16,
                                              ),
                                        label: Text(
                                          appLang.tr(
                                            _isSyncing
                                                ? 'جاري المزامنة...'
                                                : 'مزامنة الآن',
                                            _isSyncing
                                                ? 'Syncing...'
                                                : 'Sync Now',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Handelha Pro subscription — shown ONLY when store billing is configured
                // or the user already holds a verified active subscription.
                if (SubscriptionConfig.isStoreBillingConfigured ||
                    subState?.isPro == true) ...[
                  Material(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => context.push('/subscription'),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: c.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                color: c.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appLang.tr(
                                      'باقات الطلاب و Pro',
                                      'Student & Pro Plans',
                                    ),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subState?.isPro == true
                                        ? (isEn
                                            ? 'Active: ${subState!.resolvedPlanTitle(isEnglish: true)} • ${subState.category.shortBadge(isEnglish: true)}'
                                            : 'مشترك حاليًا في: ${subState!.resolvedPlanTitle(isEnglish: false)} • ${subState.category.shortBadge(isEnglish: false)}')
                                        : appLang.tr(
                                            'باقات الطلاب بشكل وسعر خاص، وباقات Pro العادية',
                                            'Special Student pricing & visuals, or regular Pro plans',
                                          ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: subState?.isPro == true
                                          ? c.primary
                                          : c.textSecondary,
                                      fontWeight: subState?.isPro == true
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              appLang.isEnglish
                                  ? Icons.chevron_right_rounded
                                  : Icons.chevron_left_rounded,
                              color: c.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // نبرة المساعد
                Text(
                  appLang.tr('نبرة المساعد', 'Assistant Tone'),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                HandelhaSegmentedSwitch<AssistantTone>(
                  selected: isFriendlyTone
                      ? AssistantTone.friendly
                      : AssistantTone.brief,
                  onChanged: (tone) => ref
                      .read(authNotifierProvider.notifier)
                      .updateAssistantTone(tone),
                  options: [
                    HandelhaSegmentOption(
                      value: AssistantTone.friendly,
                      label: appLang.tr('ودود ومشجّع', 'Friendly & Encouraging'),
                    ),
                    HandelhaSegmentOption(
                      value: AssistantTone.brief,
                      label: appLang.tr('مختصر وعملي', 'Brief & Practical'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Privacy card
                Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: user == null ? null : () => _openPrivacySheet(user),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 21,
                                color: c.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  appLang.tr('خصوصيتك تحت سيطرتك', 'Your Privacy Under Your Control'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            appLang.tr('إدارة بياناتك وسجل محادثاتك', 'Manage your data & chat history'),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: TextButton(
                    onPressed: _confirmSignOut,
                    child: Text(
                      appLang.tr('تسجيل الخروج', 'Sign Out'),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: c.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appLang.tr(
                    'هندلها • الإصدار ${ArabicFormatters.toArabicDigits('1.0')}',
                    'Handelha • Version 1.0',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const HandelhaBottomNav(currentIndex: 0),
    );
  }
}

class _ThemeOptionPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? c.primary : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _QuietTimeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String timeLabel;
  final VoidCallback onTap;

  const _QuietTimeTile({
    required this.icon,
    required this.label,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border.withValues(alpha: 0.75)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: c.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  timeLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: c.primary,
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
