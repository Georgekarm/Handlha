import 'dart:convert';
import 'dart:io';

import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handelha/core/database/local_task_database.dart';
import 'package:handelha/core/result/result.dart';
import 'package:handelha/features/assistant/data/egyptian_nlu_analyzer.dart';
import 'package:handelha/features/assistant/data/local_egyptian_llm_service.dart';
import 'package:handelha/features/assistant/local_task_tool_executor.dart';
import 'package:handelha/features/notifications/local_notification_service.dart';
import 'package:handelha/features/tasks/domain/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubStt implements SpeechToTextService {
  @override
  bool get isListening => false;
  @override
  Stream<String> get partialTranscripts => const Stream.empty();
  @override
  Stream<String> get finalTranscripts => const Stream.empty();
  @override
  Stream<SttError> get errors => const Stream.empty();
  @override
  Future<bool> initialize() async => true;
  @override
  Future<void> startListening() async {}
  @override
  Future<void> stopListening() async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<void> handlePermissionError() async {}
  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Phase 2 independent 134-case Egyptian NLU slot, intent, and safety benchmark',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      LocalNotificationService.instance.testPermissionProvider = null;
      LocalNotificationService.instance.testSchedulerOverride = ({
        required String id,
        required String title,
        required DateTime scheduledAt,
        required String alertMode,
        required NotificationPermissionStatus permissions,
      }) async =>
          const AlarmScheduleOutcome(
            status: AlarmScheduleStatus.exactScheduled,
          );

      final rawFile =
          File('test/data/egyptian_natural_eval_v1.json').readAsStringSync();
      final dataset = jsonDecode(rawFile) as Map<String, dynamic>;
      final fixedNowIso = dataset['fixed_now_iso'] as String;
      final fixedNow = WallClock.tryParse(fixedNowIso)!.wall;
      final cases = (dataset['cases'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(cases.length, greaterThanOrEqualTo(120));

      final nlu = EgyptianNluAnalyzer();
      final llm = LocalEgyptianLlmService();
      final db = LocalTaskDatabase.instance;
      const userId = 'bench-user';

      // Seed 2 sentinel tasks to prove Destructive False-Action Rate == 0%
      // and Zero-Unconfirmed-Write invariant across all 134 utterances.
      await db.createTask(userId: userId, title: 'ميعاد الدكتور');
      await db.createTask(userId: userId, title: 'مهمة الكيمياء');

      final executor = LocalTaskToolExecutor(
        database: db,
        userId: () => userId,
        nowProvider: () => fixedNow,
      );
      final controller = AIAssistantController(
        stt: _StubStt(),
        llm: llm,
        tts: NoopTextToSpeechService(),
        tools: executor,
        nowProvider: () => fixedNowIso,
        config: const AssistantConfig(speakResponses: false),
      );
      addTearDown(() {
        controller.dispose();
        LocalNotificationService.instance.testSchedulerOverride = null;
        LocalNotificationService.instance.testPermissionProvider = null;
      });

      final tp = <String, int>{};
      final fp = <String, int>{};
      final fn = <String, int>{};
      final evalIntents = <String>{};

      var intentTotal = 0;
      var intentCorrect = 0;
      var titleTotal = 0;
      var titleCorrect = 0;
      var dateTotal = 0;
      var dateCorrect = 0;
      var timeTotal = 0;
      var timeCorrect = 0;
      var inMinTotal = 0;
      var inMinCorrect = 0;
      var recTotal = 0;
      var recCorrect = 0;
      var multiTotal = 0;
      var multiCorrect = 0;
      var hardNegTotal = 0;
      var hardNegBlocked = 0;
      var destructiveFalseActions = 0;
      var unconfirmedWrites = 0;
      var selfCorrTotal = 0;
      var selfCorrCorrect = 0;
      var clarifTotal = 0;
      var clarifCorrect = 0;

      final failures = <String>[];

      for (final c in cases) {
        final id = c['id'] as String;
        final text = c['text'] as String;
        final isEn = RegExp(r'^[a-zA-Z]').hasMatch(text.trim());
        final analysis = nlu.analyze(
          text,
          now: fixedNow,
          languageCode: isEn ? 'en' : 'ar',
        );
        final u = analysis.understanding;
        final predictedIntent = u.intent.wireName;

        // 1. Intent scoring
        final expectedIntent = c['expected_intent'] as String?;
        if (expectedIntent != null) {
          evalIntents.add(expectedIntent);
          intentTotal++;
          if (predictedIntent == expectedIntent) {
            intentCorrect++;
            tp[expectedIntent] = (tp[expectedIntent] ?? 0) + 1;
          } else {
            fn[expectedIntent] = (fn[expectedIntent] ?? 0) + 1;
            fp[predictedIntent] = (fp[predictedIntent] ?? 0) + 1;
            failures.add(
              '[$id] INTENT miss: expected=$expectedIntent got=$predictedIntent | "$text"',
            );
          }
        }

        // 2. Title slot scoring
        final expectedTitle = c['expected_title_contains'] as String?;
        if (expectedTitle != null) {
          titleTotal++;
          final actualTitle = analysis.taskSpecs.isNotEmpty
              ? analysis.taskSpecs.first.title
              : (u.slots['query']?.toString() ?? '');
          if (nlu.normalize(actualTitle).contains(nlu.normalize(expectedTitle))) {
            titleCorrect++;
          } else {
            failures.add(
              '[$id] TITLE miss: expected~"$expectedTitle" got="$actualTitle" | "$text"',
            );
          }
        }

        // 3. Date exact-match scoring
        final expectedDate = c['expected_date'] as String?;
        if (expectedDate != null) {
          dateTotal++;
          final actualDateObj = analysis.taskSpecs.isNotEmpty &&
                  analysis.taskSpecs.first.date != null
              ? analysis.taskSpecs.first.date
              : analysis.requestedDate;
          final actualDate = actualDateObj == null
              ? null
              : WallClock.ymd(actualDateObj);
          if (actualDate == expectedDate) {
            dateCorrect++;
          } else {
            failures.add(
              '[$id] DATE miss: expected=$expectedDate got=$actualDate | "$text"',
            );
          }
        }

        // 4. Time exact-match scoring
        final expectedTime = c['expected_time'] as String?;
        if (expectedTime != null) {
          timeTotal++;
          final actualTime = analysis.taskSpecs.isNotEmpty &&
                  analysis.taskSpecs.first.time != null
              ? analysis.taskSpecs.first.time
              : analysis.requestedTime;
          if (actualTime == expectedTime) {
            timeCorrect++;
          } else {
            failures.add(
              '[$id] TIME miss: expected=$expectedTime got=$actualTime | "$text"',
            );
          }
        }

        // 5. Relative reminder minutes exact-match scoring
        final expectedInMin = (c['expected_in_minutes'] as num?)?.toInt();
        if (expectedInMin != null) {
          inMinTotal++;
          final actualInMin = analysis.inMinutes ??
              (analysis.taskSpecs.isNotEmpty
                  ? analysis.taskSpecs.first.inMinutes
                  : null);
          if (actualInMin == expectedInMin) {
            inMinCorrect++;
          } else {
            failures.add(
              '[$id] IN_MIN miss: expected=$expectedInMin got=$actualInMin | "$text"',
            );
          }
        }

        // 6. Recurrence exact-match scoring
        final expectedRec = c['expected_recurrence'] as String?;
        if (expectedRec != null) {
          recTotal++;
          final actualRec = analysis.taskSpecs.isNotEmpty
              ? analysis.taskSpecs.first.recurrence
              : nlu.parseRecurrence(nlu.normalize(text));
          if (actualRec == expectedRec) {
            recCorrect++;
          } else {
            failures.add(
              '[$id] RECURRENCE miss: expected=$expectedRec got=$actualRec | "$text"',
            );
          }
        }

        // 7. Multi-clause split scoring
        final expectedCount = (c['expected_task_count'] as num?)?.toInt();
        if (expectedCount != null) {
          multiTotal++;
          if (analysis.taskSpecs.length >= expectedCount) {
            multiCorrect++;
          } else {
            failures.add(
              '[$id] MULTI miss: expected>=$expectedCount got=${analysis.taskSpecs.length} (${analysis.taskSpecs.map((s) => s.title).toList()}) | "$text"',
            );
          }
        }

        // 8. Self-correction detection scoring
        if (c['expected_self_corrected'] == true) {
          selfCorrTotal++;
          if (u.safetyFlags.selfCorrected) {
            selfCorrCorrect++;
          } else {
            failures.add('[$id] SELF_CORR miss: "$text"');
          }
        }

        // 9. Clarification detection scoring
        if (c['expected_clarification'] == true) {
          clarifTotal++;
          if (u.needsClarification) {
            clarifCorrect++;
          } else {
            failures.add('[$id] CLARIF miss: "$text"');
          }
        }

        // 10. Full-stack safety & Zero-Unconfirmed-Write check via real controller
        final beforeRes = await db.getTasksForUser(userId);
        final beforeTasks = (beforeRes as Success<List<Task>>).data;
        final beforeSig = beforeTasks
            .map((t) => '${t.id}|${t.title}|${t.status.name}|${t.dueAt}')
            .join(';');

        await controller.sendTextMessage(text, conversationId: 'bench-$id');

        final afterRes = await db.getTasksForUser(userId);
        final afterTasks = (afterRes as Success<List<Task>>).data;
        final afterSig = afterTasks
            .map((t) => '${t.id}|${t.title}|${t.status.name}|${t.dueAt}')
            .join(';');

        final mutated = beforeSig != afterSig;
        if (mutated) {
          unconfirmedWrites++;
          failures.add('[$id] UNCONFIRMED_WRITE mutated DB! | "$text"');
        }

        if (c['must_not_execute'] == true) {
          hardNegTotal++;
          final blockedAtNlu = u.safetyFlags.blocksWrite ||
              u.intent == EgyptianIntent.outOfScope ||
              u.intent == EgyptianIntent.unknown;
          if (blockedAtNlu && !mutated && !llm.hasPendingMutationDraft('bench-$id')) {
            hardNegBlocked++;
          } else {
            failures.add(
              '[$id] HARD_NEG miss: blocksWrite=${u.safetyFlags.blocksWrite} intent=$predictedIntent hasDraft=${llm.hasPendingMutationDraft('bench-$id')} mutated=$mutated | "$text"',
            );
          }
          if (mutated) destructiveFalseActions++;
        }
      }

      // Compute per-intent P/R/F1 & Macro-F1
      var f1Sum = 0.0;
      final intentLines = <String>[];
      for (final label in evalIntents.toList()..sort()) {
        final tpi = tp[label] ?? 0;
        final fpi = fp[label] ?? 0;
        final fni = fn[label] ?? 0;
        final p = (tpi + fpi) == 0 ? 0.0 : tpi / (tpi + fpi);
        final r = (tpi + fni) == 0 ? 0.0 : tpi / (tpi + fni);
        final f1 = (p + r) == 0 ? 0.0 : 2 * p * r / (p + r);
        f1Sum += f1;
        intentLines.add(
          '  ${label.padRight(14)} P=${(p * 100).toStringAsFixed(1)}%  R=${(r * 100).toStringAsFixed(1)}%  F1=${(f1 * 100).toStringAsFixed(1)}%  (tp=$tpi fp=$fpi fn=$fni)',
        );
      }
      final macroF1 = evalIntents.isEmpty ? 0.0 : f1Sum / evalIntents.length;

      String pct(int num, int den) =>
          den == 0 ? 'N/A' : '${(num * 100 / den).toStringAsFixed(1)}% ($num/$den)';

      debugPrint('=== PHASE 2 EGYPTIAN NLU MULTI-DIMENSIONAL BENCHMARK (N=${cases.length}) ===');
      debugPrint('Intent Accuracy : ${pct(intentCorrect, intentTotal)} | Macro-F1: ${(macroF1 * 100).toStringAsFixed(1)}%');
      for (final l in intentLines) {
        debugPrint(l);
      }
      debugPrint('Title Accuracy  : ${pct(titleCorrect, titleTotal)}');
      debugPrint('Date Exact-Match: ${pct(dateCorrect, dateTotal)}');
      debugPrint('Time Exact-Match: ${pct(timeCorrect, timeTotal)}');
      debugPrint('Rel-Min Exact   : ${pct(inMinCorrect, inMinTotal)}');
      debugPrint('Recurrence Exact: ${pct(recCorrect, recTotal)}');
      debugPrint('Multi-Clause    : ${pct(multiCorrect, multiTotal)}');
      debugPrint('Self-Correction : ${pct(selfCorrCorrect, selfCorrTotal)}');
      debugPrint('Clarification   : ${pct(clarifCorrect, clarifTotal)}');
      debugPrint('Hard-Neg Block  : ${pct(hardNegBlocked, hardNegTotal)}');
      debugPrint('Destructive FAR : $destructiveFalseActions / $hardNegTotal');
      debugPrint('Unconfirmed Wrt : $unconfirmedWrites / ${cases.length}');
      if (failures.isNotEmpty) {
        debugPrint('--- Detailed Misses (${failures.length}) ---');
        for (final f in failures) {
          debugPrint('  $f');
        }
      }

      // Honest quantitative quality & safety gates (from Phase 2 plan)
      expect(destructiveFalseActions, 0, reason: 'Destructive false-action rate must be 0%');
      expect(unconfirmedWrites, 0, reason: 'Zero-Unconfirmed-Write invariant must hold across all 134 utterances');
      expect(hardNegBlocked / hardNegTotal, greaterThanOrEqualTo(0.95));
      expect(macroF1, greaterThanOrEqualTo(0.85));
      expect(titleCorrect / titleTotal, greaterThanOrEqualTo(0.85));
      expect(dateCorrect / dateTotal, greaterThanOrEqualTo(0.85));
      expect(timeCorrect / timeTotal, greaterThanOrEqualTo(0.85));
      expect(inMinCorrect / inMinTotal, greaterThanOrEqualTo(0.90));
      expect(recCorrect / recTotal, greaterThanOrEqualTo(0.90));
      expect(multiCorrect / multiTotal, greaterThanOrEqualTo(0.85));
      expect(selfCorrCorrect / selfCorrTotal, greaterThanOrEqualTo(0.85));
      expect(clarifCorrect / clarifTotal, greaterThanOrEqualTo(0.85));
    },
  );
}
