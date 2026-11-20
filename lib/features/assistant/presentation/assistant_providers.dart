import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../app/locale/language_controller.dart';
import '../../../core/database/shared_preferences_conversation_store.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../../notifications/alarm_reminder_store.dart';
import '../../tasks/presentation/task_providers.dart';
import '../data/local_egyptian_llm_service.dart';
import '../local_task_tool_executor.dart';
import '../planning/ai_planning_service.dart';
import 'chat_session_controller.dart';

final conversationStoreProvider = FutureProvider<ConversationStore>((ref) async {
  final user = await ref.watch(authNotifierProvider.future);
  if (user == null) throw StateError('يجب تسجيل الدخول لاستخدام المساعد.');
  return SharedPreferencesConversationStore.open(userId: user.id);
});

final assistantAlertModeProvider = StateProvider<String>((ref) => 'alarm');

final llmServiceProvider = Provider<LLMService>((ref) {
  return LocalEgyptianLlmService(
    languageCodeProvider: () => ref.read(appLanguageProvider).wireCode,
    onAlertModeSelected: (mode) {
      ref.read(assistantAlertModeProvider.notifier).state = mode;
    },
  );
});

final aiPlanningServiceProvider = Provider<AiPlanningService>((ref) {
  return AiPlanningService(ref.watch(llmServiceProvider));
});

final assistantControllerProvider = FutureProvider<AIAssistantController>((ref) async {
  final store = await ref.watch(conversationStoreProvider.future);
  final stt = SpeechToTextPackageService(
    localeCandidatesProvider: () {
      final lang = ref.read(appLanguageProvider);
      return lang.isEnglish
          ? const ['en_US', 'en_GB', 'en']
          : const ['ar_EG', 'ar_SA', 'ar'];
    },
  );
  final tts = FlutterTtsService(
    languageCandidatesProvider: () => ref.read(appLanguageProvider).ttsCandidates,
  );
  final controller = AIAssistantController(
    stt: stt,
    llm: ref.watch(llmServiceProvider),
    tts: tts,
    tools: LocalTaskToolExecutor(
      database: ref.read(localTaskDbProvider),
      userId: () => ref.read(authNotifierProvider).value?.id,
      alertModeResolver: () => ref.read(assistantAlertModeProvider),
      onChanged: () {
        ref.invalidate(todayTasksProvider);
        ref.invalidate(allTasksProvider);
        ref.invalidate(alarmReminderProvider);
      },
    ),
    nowProvider: WallClock.deviceNowIso,
    conversations: ConversationManager(store: store),
  );
  ref.onDispose(() {
    controller.dispose();
    stt.dispose();
    tts.dispose();
  });
  return controller;
});

final chatSessionProvider = ChangeNotifierProvider<ChatSessionController>((ref) {
  final session = ChatSessionController();
  Future<void> bind() async {
    try {
      session.bind(await ref.read(assistantControllerProvider.future));
    } catch (e) {
      session.reset();
    }
  }

  ref.listen<AsyncValue<AIAssistantController>>(
    assistantControllerProvider,
    (_, next) {
      next.when(
        data: session.bind,
        loading: () {},
        error: (_, _) => session.reset(),
      );
    },
  );
  bind();
  return session;
});
