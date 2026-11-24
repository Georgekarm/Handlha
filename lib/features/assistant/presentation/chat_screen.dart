import 'dart:async';

import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/locale/language_controller.dart';
import '../../../app/theme/app_theme_extension.dart';
import '../../../core/telemetry/local_core_loop_telemetry.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/handelha_feedback.dart';
import '../../../shared/widgets/handelha_header.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/project_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_providers.dart';
import '../../onboarding/presentation/energy_preferences_sheet.dart';
import '../../subscriptions/data/subscription_repository.dart';
import '../data/user_energy_preferences.dart';
import 'assistant_providers.dart';
import 'token_balance_provider.dart';
import 'widgets/secretary_message_widgets.dart';

/// شاشة مساعد هندلها الذكي.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  /// SharedPreferences flag tracking whether the user acknowledged the honest
  /// Android SpeechRecognizer (network-capable STT) vs local text NLU notice.
  static const String voiceSttDisclosureKey = 'handelha_voice_stt_disclosed_v1';

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  bool _lastIsSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _composerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isZeroCostDraftControlAction(String text) {
    final t = text.trim();
    if (t.startsWith('تعديل المسودة |') || t.startsWith('EDIT_DRAFT |')) {
      return true;
    }
    return RegExp(
      r'^(?:اعتمد|اعتمدها|اعتمدهم|احفظ|تأكيد\s+الحذف|تاكيد\s+الحذف|إلغاء|الغاء|تراجع|confirm|approve|cancel|confirm\s+delete)$',
      caseSensitive: false,
    ).hasMatch(t);
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty) return;
    // Never charge tokens for confirming, editing, or cancelling a staged draft
    // or tapping a quick-reply action card (prevents double-charging & deadlocks).
    final isFreeControlAction =
        preset != null || _isZeroCostDraftControlAction(text);
    if (!isFreeControlAction) {
      final hasTokens =
          await ref.read(tokenBalanceProvider.notifier).consumeTextToken();
      if (!hasTokens) {
        if (mounted) _showTokenRefillSheet(context);
        return;
      }
    }
    if (preset == null) {
      _messageController.clear();
      unawaited(
        LocalCoreLoopTelemetry.instance.recordEvent(
          ref.read(authNotifierProvider).value?.id,
          'text_input',
        ),
      );
    }
    await ref.read(chatSessionProvider).send(text);
    _scrollToBottom();
  }

  Future<void> _handleVoiceTap() async {
    final session = ref.read(chatSessionProvider);
    if (session.assistantState == AssistantState.listening ||
        session.isVoiceBusy) {
      await session.toggleVoice();
      return;
    }
    final acknowledged = await _ensureVoiceSttDisclosure();
    if (!acknowledged || !mounted) return;
    final tokenState = ref.read(tokenBalanceProvider);
    if (!tokenState.canSendVoice) {
      if (mounted) _showTokenRefillSheet(context);
      return;
    }
    await session.toggleVoice();
    if (session.assistantState == AssistantState.listening) {
      await ref.read(tokenBalanceProvider.notifier).consumeVoiceToken();
      unawaited(
        LocalCoreLoopTelemetry.instance.recordEvent(
          ref.read(authNotifierProvider).value?.id,
          'voice_input',
        ),
      );
    }
  }

  Future<bool> _ensureVoiceSttDisclosure() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(ChatScreen.voiceSttDisclosureKey) == true) {
        return true;
      }
      if (!mounted) return false;
      final appLang = ref.read(appLanguageProvider);
      final accepted = await HandelhaDialog.showCustom<bool>(
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
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: dc.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: dc.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.mic_none_rounded,
                          color: dc.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          appLang.tr(
                            'تنبيه شفاف عن الإدخال الصوتي',
                            'Transparent Voice Input Notice',
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
                  Text(
                    appLang.tr(
                      '• الكتابة النصية في المساعد تُحلَّل محليًا ١٠٠٪ على جهازك بدون إرسالها لأي نموذج خارجي.\n'
                      '• الإدخال الصوتي يستخدم خدمة التعرّف على الكلام المدمجة في نظام Android (SpeechRecognizer)، والتي قد تعتمد على الإنترنت وفقًا لإعدادات جهازك.',
                      '• Typed messages are analyzed 100% locally on your device without calling any external LLM.\n'
                      '• Voice input uses Android system SpeechRecognizer, which may use the network depending on your device settings.',
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: dc.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.of(dCtx).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      appLang.tr(
                        'استخدم الكتابة بدلًا من ذلك',
                        'Use Text Instead',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(dCtx).pop(true),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.mic_rounded, size: 18),
                    label: Text(
                      appLang.tr(
                        'فهمت، استخدم الميكروفون',
                        'Understood, Use Microphone',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (accepted == true) {
        await prefs.setBool(ChatScreen.voiceSttDisclosureKey, true);
        return true;
      }
      if (mounted) {
        _composerFocusNode.requestFocus();
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  void _launchFocusSession({
    String? taskId,
    required String title,
  }) {
    unawaited(
      LocalCoreLoopTelemetry.instance.recordEvent(
        ref.read(authNotifierProvider).value?.id,
        'focus_started',
      ),
    );
    context.push(
      '/focus-session',
      extra: {
        if (taskId != null && taskId.isNotEmpty) 'id': taskId,
        'title': title,
      },
    );
  }

  String _extractCreatedTitleOrFallback(String content, bool isEn) {
    final mAr = RegExp(r'«([^»]+)»').firstMatch(content);
    if (mAr != null && (mAr.group(1)?.trim().isNotEmpty ?? false)) {
      return mAr.group(1)!.trim();
    }
    final mEn = RegExp(r'"([^"]+)"').firstMatch(content);
    if (mEn != null && (mEn.group(1)?.trim().isNotEmpty ?? false)) {
      return mEn.group(1)!.trim();
    }
    return isEn ? 'Focus Step' : 'خطوة تركيز';
  }

  void _showTokenRefillSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TokenRefillBottomSheet(),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String? _voiceBannerLabel(AssistantState state, bool isEn) => switch (state) {
        AssistantState.listening =>
          isEn ? 'Listening now...' : 'بسمعك دلوقتي...',
        AssistantState.transcribing =>
          isEn ? 'Transcribing your voice...' : 'بحوّل كلامك لنص...',
        AssistantState.thinking =>
          isEn ? 'Thinking of the best next step...' : 'بفكّر في أفضل خطوة...',
        AssistantState.executing =>
          isEn ? 'Working on your request...' : 'بنفّذ طلبك...',
        AssistantState.speaking =>
          isEn ? 'Assistant is speaking...' : 'المساعد بيتكلم...',
        AssistantState.error => isEn
            ? 'Voice input encountered an issue, please try again.'
            : 'حصلت مشكلة في الصوت، تقدر تحاول تاني.',
        AssistantState.idle => null,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = ref.watch(chatSessionProvider);
    final user = ref.watch(authNotifierProvider).value;
    final appLang = ref.watch(appLanguageProvider);
    final tokenState = ref.watch(tokenBalanceProvider);
    final energyPrefs = ref.watch(userEnergyPreferencesProvider);
    final todayTasks = ref.watch(todayTasksProvider).value ?? const <Task>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final projectMap = {for (final p in projects) p.id: p.title};

    final topOpenTask = todayTasks
        .where((t) => !t.isCompleted && !t.isCancelled)
        .firstOrNull;
    final voiceStatus =
        _voiceBannerLabel(session.assistantState, appLang.isEnglish);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    if (session.messages.length != _lastMessageCount ||
        session.isSending != _lastIsSending) {
      _lastMessageCount = session.messages.length;
      _lastIsSending = session.isSending;
      _scrollToBottom();
    }

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header + Clean Single Quota & Energy Profile Bar
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: c.border.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: c.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.auto_awesome_outlined,
                          size: 21,
                          color: c.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appLang.tr('مساعد هندلها', 'Handelha Assistant'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            Text(
                              appLang.tr('معاك، مش مستعجلك', 'With you, no rush'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      HandelhaHeaderIconButton(
                        icon: Icons.format_list_bulleted_rounded,
                        tooltip: appLang.tr('سجل المحادثات', 'Chat History'),
                        iconColor: c.primary,
                        onTap: () => context.push('/chat/history'),
                      ),
                      const SizedBox(width: 6),
                      HandelhaHeaderIconButton(
                        icon: Icons.settings_outlined,
                        tooltip: appLang.tr('الإعدادات', 'Settings'),
                        onTap: () => context.push('/settings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Clean Single Quota & Energy Profile Row (no duplicate badges, no fake ads)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showTokenRefillSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: tokenState.isUnlimitedPro
                                  ? c.primarySoft
                                  : c.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: tokenState.isUnlimitedPro
                                    ? c.primary.withValues(alpha: 0.4)
                                    : c.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  tokenState.isUnlimitedPro
                                      ? Icons.workspace_premium_rounded
                                      : Icons.bolt_rounded,
                                  size: 15,
                                  color: tokenState.isUnlimitedPro
                                      ? c.primary
                                      : (tokenState.balance <= 10
                                          ? c.danger
                                          : c.warning),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    tokenState.isUnlimitedPro
                                        ? (appLang.isEnglish
                                            ? 'Pro ∞ • Unlimited'
                                            : 'Pro ∞ • توكنز غير محدودة')
                                        : (appLang.isEnglish
                                            ? 'Daily Tokens: ${tokenState.balance}/${tokenState.dailyAllowance}'
                                            : 'التوكنز اليومية: ${ArabicFormatters.toArabicDigits(tokenState.balance)}/${ArabicFormatters.toArabicDigits(tokenState.dailyAllowance)}'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: tokenState.isUnlimitedPro
                                          ? c.primary
                                          : c.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => EnergyPreferencesWizardSheet.show(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: c.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: c.primary.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 14,
                                  color: c.primary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    appLang.isEnglish
                                        ? 'Energy: ${energyPrefs.peakShortEn}'
                                        : 'طاقتك: ${energyPrefs.peakShortAr}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: c.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      '${appLang.tr('النهارده', 'Today')} • ${ArabicFormatters.timeOfDayAr(DateTime.now())}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ),

                // Welcome card
                _AssistantTextCard(
                  text: appLang.isEnglish
                      ? 'Welcome ${ArabicFormatters.trData(user?.firstName ?? 'friend')}, how is your day going?\nTell me what is on your plate and we will plan it together.'
                      : 'أهلًا يا ${user?.firstName ?? 'صديقي'}، يومك عامل إيه؟\nقولّي اللي وراك ونرتّبه سوا.',
                ),
                const SizedBox(height: 12),

                if (session.messages.isEmpty) ...[
                  if (topOpenTask != null) ...[
                    _AssistantSuggestedTaskBubble(
                      task: topOpenTask,
                      projectName: topOpenTask.projectId != null
                          ? projectMap[topOpenTask.projectId!]
                          : null,
                      onStartFocus: () => _launchFocusSession(
                        taskId: topOpenTask.id,
                        title: topOpenTask.title,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ] else ...[
                  for (var i = 0; i < session.messages.length; i++) ...[
                    _MessageItem(
                      message: session.messages[i],
                      isLastAssistant: i == session.messages.length - 1 &&
                          session.messages[i].role == MessageRole.assistant,
                      suggestedTask: topOpenTask,
                      suggestedProjectName: topOpenTask?.projectId != null
                          ? projectMap[topOpenTask!.projectId!]
                          : null,
                      onQuickReply: (reply) => _send(reply),
                      onStartFocus: () {
                        if (topOpenTask != null) {
                          _launchFocusSession(
                            taskId: topOpenTask.id,
                            title: topOpenTask.title,
                          );
                        } else {
                          _launchFocusSession(
                            title: _extractCreatedTitleOrFallback(
                              session.messages[i].content,
                              appLang.isEnglish,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],

                if (session.isSending)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          appLang.tr('برتب لك الرد...', 'Preparing your reply...'),
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (session.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: c.danger.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          session.error!,
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textPrimary,
                          ),
                        ),
                        if (session.canRetry) ...[
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: session.retry,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(appLang.tr('إعادة المحاولة', 'Retry')),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

            // Dedicated Bottom Composer Dock — cleanly separated from the message list
            // so chat bubbles can never overlap or get clipped behind quick pills.
            Container(
              decoration: BoxDecoration(
                color: c.background.withValues(alpha: 0.94),
                border: Border(
                  top: BorderSide(
                    color: c.border.withValues(alpha: 0.55),
                    width: 1,
                  ),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                keyboardOpen ? 8 : (86 + safeBottom),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (voiceStatus != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: c.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.graphic_eq_rounded, size: 19, color: c.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              session.partialTranscript.isNotEmpty
                                  ? session.partialTranscript
                                  : voiceStatus,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: c.primary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: session.stopVoiceOrSpeaking,
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              appLang.tr('إيقاف', 'Stop'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: c.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (!keyboardOpen) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _QuickSuggestionPill(
                            label: appLang.tr('رتّب مهامي', 'Plan my tasks'),
                            onTap: () => _send(
                              appLang.tr(
                                'رتّب معايا أولويات مهامي النهارده',
                                'Plan and prioritize my tasks for today',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickSuggestionPill(
                            label: appLang.tr('اختار أول خطوة', 'Pick first step'),
                            onTap: () => _send(
                              appLang.tr(
                                'اختار لي أول خطوة أبدأ بيها دلوقتي',
                                'Pick the best first step for me to start now',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Composer pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: c.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: appLang.tr('إضافة مهمة', 'Add Task'),
                          onPressed: () => context.push('/tasks/add'),
                          icon: Icon(
                            Icons.add_rounded,
                            color: c.textSecondary,
                            size: 22,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _composerFocusNode,
                            enabled: !session.isSending,
                            minLines: 1,
                            maxLines: 3,
                            onSubmitted: (_) => _send(),
                            style: TextStyle(
                              fontSize: 14.5,
                              color: c.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: appLang.tr(
                                'اكتب اللي في بالك...',
                                "Type what's on your mind...",
                              ),
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: c.textSecondary,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: appLang.tr(
                            'أمر صوتي (٥ توكن)',
                            'Voice Input (5 Tokens)',
                          ),
                          onPressed: _handleVoiceTap,
                          icon: Icon(
                            session.assistantState == AssistantState.listening
                                ? Icons.stop_circle_rounded
                                : Icons.mic_none_rounded,
                            color: session.assistantState ==
                                    AssistantState.listening
                                ? c.danger
                                : c.textSecondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Material(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: session.isSending ? null : () => _send(),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.send_rounded,
                                size: 19,
                                color: c.textOnPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!keyboardOpen)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        appLang.tr(
                          'مش لازم ترتّب كلامك، أنا معاك.',
                          "You don't have to organize your thoughts — I'm here.",
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantTextCard extends StatelessWidget {
  final String text;
  const _AssistantTextCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              color: c.textPrimary,
              height: 1.55,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageItem extends StatelessWidget {
  final ConversationMessage message;
  final bool isLastAssistant;
  final Task? suggestedTask;
  final String? suggestedProjectName;
  final ValueChanged<String> onQuickReply;
  final VoidCallback? onStartFocus;

  const _MessageItem({
    required this.message,
    required this.isLastAssistant,
    required this.onQuickReply,
    this.suggestedTask,
    this.suggestedProjectName,
    this.onStartFocus,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isUser = message.role == MessageRole.user;

    if (isUser) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 310),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: c.heroTeal,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                fontSize: 14.5,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    final isEn = Directionality.of(context) == TextDirection.ltr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                size: 13,
                color: c.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  isEn
                      ? 'Handelha • Personal Secretary'
                      : 'هندلها • مكتب السكرتير الذكي',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SecretaryRichMessageBody(
                content: message.content,
                onQuickReply: onQuickReply,
                isLastAssistant: isLastAssistant,
                suggestedTask: suggestedTask,
                suggestedProjectName: suggestedProjectName,
                onStartFocus: onStartFocus,
              ),
              if (isLastAssistant &&
                  suggestedTask != null &&
                  onStartFocus != null &&
                  !message.content.trimLeft().startsWith('🔍') &&
                  !message.content.trimLeft().startsWith('⚠️') &&
                  !message.content.trimLeft().startsWith('تمام، ضفتلك') &&
                  !message.content.trimLeft().startsWith('تمام! ضفتلك') &&
                  !message.content.trimLeft().startsWith('تمام، ظبطتلك') &&
                  !message.content.trimLeft().startsWith('Added ') &&
                  !message.content.trimLeft().startsWith('All set — saved')) ...[
                const SizedBox(height: 14),
                _EmbeddedFocusSnippet(
                  task: suggestedTask!,
                  projectName: suggestedProjectName,
                  onStartFocus: onStartFocus!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TokenRefillBottomSheet extends ConsumerWidget {
  const _TokenRefillBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final appLang = ref.watch(appLanguageProvider);
    final tokenState = ref.watch(tokenBalanceProvider);
    final isEn = appLang.isEnglish;

    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    Icons.bolt_rounded,
                    size: 26,
                    color: c.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appLang.tr(
                          'محفظة توكنز مساعد هندلها',
                          'Handelha Assistant Tokens',
                        ),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        appLang.tr(
                          'يتجدد رصيدك تلقائيًا كل يوم إلى ٥٠ توكن مجانًا',
                          'Auto-renews daily to 50 free tokens every day',
                        ),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: c.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Balance Progress Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surfaceSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        appLang.tr('رصيدك المتاح الآن', 'Current Balance'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: c.textSecondary,
                        ),
                      ),
                      Text(
                        tokenState.isUnlimitedPro
                            ? (isEn ? 'Unlimited (Pro)' : 'غير محدود (Pro)')
                            : (isEn
                                ? '${tokenState.balance} / ${tokenState.dailyAllowance} Tokens'
                                : '${ArabicFormatters.toArabicDigits(tokenState.balance)} / ${ArabicFormatters.toArabicDigits(tokenState.dailyAllowance)} توكن'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: c.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: tokenState.fillRatio,
                      minHeight: 9,
                      backgroundColor: c.border.withValues(alpha: 0.4),
                      valueColor: AlwaysStoppedAnimation<Color>(c.primary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _CostExplanationTile(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: appLang.tr('الرسالة النصية', 'Text Message'),
                          cost: appLang.tr('٢ توكن', '2 Tokens'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CostExplanationTile(
                          icon: Icons.mic_none_rounded,
                          title: appLang.tr('الرسالة الصوتية (فويس)', 'Voice Message'),
                          cost: appLang.tr('٥ توكن', '5 Tokens'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (SubscriptionConfig.isStoreBillingConfigured)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/subscription');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.workspace_premium_outlined, size: 22),
                label: Text(
                  appLang.tr(
                    'اشترك في هندلها Pro لتوكنز غير محدودة',
                    'Upgrade to Handelha Pro for Unlimited Tokens',
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.primary.withValues(alpha: 0.25)),
                ),
                child: Text(
                  appLang.tr(
                    'هذه نسخة تجربة مجانية محلية — الدفع عبر Google Play غير مفعّل حاليًا، ورصيدك اليومي يتجدد تلقائيًا كل يوم.',
                    'Free local pilot build — Google Play Billing is not enabled yet and your daily tokens renew automatically every day.',
                  ),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CostExplanationTile extends StatelessWidget {
  const _CostExplanationTile({
    required this.icon,
    required this.title,
    required this.cost,
  });

  final IconData icon;
  final String title;
  final String cost;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: c.textSecondary,
                  ),
                ),
                Text(
                  cost,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
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

class _AssistantSuggestedTaskBubble extends StatelessWidget {
  final Task task;
  final String? projectName;
  final VoidCallback onStartFocus;

  const _AssistantSuggestedTaskBubble({
    required this.task,
    this.projectName,
    required this.onStartFocus,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final mins = task.estimatedDurationMinutes ?? 25;
    final cleanTitle = ArabicFormatters.trData(task.title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 4),
          child: Text(
            isEn ? 'Handelha' : 'هندلها',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEn
                    ? 'I hear you. Let us take it one step at a time.'
                    : 'فاهمك. ناخدها واحدة واحدة.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isEn
                    ? 'Start with "$cleanTitle" for ${ArabicFormatters.durationMinutesFull(mins)}?\nThen take a short break.'
                    : 'نبدأ بـ «${task.title}» لمدة ${ArabicFormatters.durationMinutesFull(mins)}؟\nوبعدها تاخد استراحة صغيرة.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              _EmbeddedFocusSnippet(
                task: task,
                projectName: projectName,
                onStartFocus: onStartFocus,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmbeddedFocusSnippet extends StatelessWidget {
  final Task task;
  final String? projectName;
  final VoidCallback onStartFocus;

  const _EmbeddedFocusSnippet({
    required this.task,
    this.projectName,
    required this.onStartFocus,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final mins = task.estimatedDurationMinutes ?? 25;
    final cleanTitle = ArabicFormatters.trData(task.title);
    final cleanProject = projectName != null
        ? ArabicFormatters.trData(projectName!)
        : (isEn ? 'Task' : 'مهمة');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 20, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cleanTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: onStartFocus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.textOnPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isEn ? "Let's Start" : 'يلا نبدأ',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: c.textOnPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$cleanProject • ${ArabicFormatters.durationMinutesFull(mins)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickSuggestionPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickSuggestionPill({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: c.primary,
            ),
          ),
        ),
      ),
    );
  }
}
