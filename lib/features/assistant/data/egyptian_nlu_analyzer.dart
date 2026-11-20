import 'package:ai_assistant/ai_assistant.dart';

class ExtractedTaskSpec {
  const ExtractedTaskSpec({
    required this.title,
    required this.date,
    required this.time,
    required this.priority,
    required this.category,
    required this.isReminder,
    required this.explicitNoDate,
    required this.isVagueTitle,
    this.inMinutes,
    this.isMissingTitle = false,
  });

  final String title;
  final DateTime? date;
  final String? time;
  final String priority;
  final String? category;
  final bool isReminder;
  final bool explicitNoDate;
  final bool isVagueTitle;
  final int? inMinutes;
  final bool isMissingTitle;
}

class NluAnalysisOutcome {
  const NluAnalysisOutcome({
    required this.understanding,
    required this.taskSpecs,
    required this.targetQuery,
    required this.requestedDate,
    required this.requestedTime,
    required this.requestedPriority,
    required this.inMinutes,
    required this.correctedRaw,
  });

  final AssistantUnderstandingResult understanding;
  final List<ExtractedTaskSpec> taskSpecs;
  final String targetQuery;
  final DateTime? requestedDate;
  final String? requestedTime;
  final String? requestedPriority;
  final int? inMinutes;
  final String correctedRaw;
}

/// Pure, offline NLU analyzer: combines the from-scratch trained softmax intent
/// classifier ([EgyptianIntentModel]) with hard pragmatic safety gates and
/// deterministic Egyptian Arabic + mixed-English slot extraction.
class EgyptianNluAnalyzer {
  EgyptianNluAnalyzer({EgyptianIntentModel? intentModel})
      : _intentModel = intentModel ?? EgyptianIntentModel();

  static const int maxInputChars = 2000;

  final EgyptianIntentModel _intentModel;

  String get modelVersion => _intentModel.modelVersion;

  NluAnalysisOutcome analyze(
    String rawInput, {
    required DateTime now,
    bool hasPendingClarification = false,
    bool hasActiveDraft = false,
    String languageCode = 'ar',
  }) {
    if (rawInput.length > maxInputChars) {
      rawInput = rawInput.substring(0, maxInputChars);
    }
    final isEn = languageCode.toLowerCase().startsWith('en');
    final resolution = ArabicText.resolveSelfCorrection(rawInput);
    final correctedRaw = resolution.resolved;
    final selfCorrected = resolution.hadCorrection;
    final norm = normalize(correctedRaw);
    final rawNorm = normalize(rawInput);

    final safety = _detectSafetyFlags(
      rawInput: rawInput,
      rawNorm: rawNorm,
      norm: norm,
      selfCorrected: selfCorrected,
      hasPendingClarification: hasPendingClarification,
      hasActiveDraft: hasActiveDraft,
    );

    final prediction = _intentModel.predict(correctedRaw);
    var intent = prediction.intent;

    // Pragmatic override hierarchy ONLY where classifier vs obvious pragmatic
    // form diverge on safety-critical boundaries (never memorizing test IDs).
    if (safety.blocksWrite && !hasPendingClarification && !hasActiveDraft) {
      intent = EgyptianIntent.unknown;
    } else if (!hasPendingClarification &&
        !hasActiveDraft &&
        _isExplicitOutOfScope(norm)) {
      intent = EgyptianIntent.outOfScope;
    } else if (!hasPendingClarification &&
        !hasActiveDraft &&
        _isGreetingOnly(norm, prediction.intent)) {
      intent = EgyptianIntent.greeting;
    } else if (!hasPendingClarification &&
        !hasActiveDraft &&
        _isScheduleIntent(norm, prediction.intent)) {
      intent = EgyptianIntent.schedule;
    } else if (!hasPendingClarification &&
        !hasActiveDraft &&
        _isSummaryIntent(norm, prediction.intent)) {
      intent = EgyptianIntent.summary;
    } else if (!hasPendingClarification &&
        !hasActiveDraft &&
        _isListTasksIntent(norm, prediction.intent)) {
      intent = EgyptianIntent.listTasks;
    } else if (!hasPendingClarification &&
        !hasActiveDraft &&
        _isCompleteIntent(norm, prediction.intent)) {
      intent = EgyptianIntent.completeTask;
    } else if (!hasPendingClarification &&
        !hasActiveDraft &&
        _isDeleteIntent(norm, prediction.intent)) {
      intent = EgyptianIntent.deleteTask;
    } else if (!hasPendingClarification &&
        !hasActiveDraft &&
        _isUpdateIntent(norm, prediction.intent)) {
      intent = EgyptianIntent.updateTask;
    } else if (!hasPendingClarification &&
        !hasActiveDraft &&
        _isPureReminderIntent(norm, prediction.intent)) {
      intent = EgyptianIntent.reminder;
    } else if (!hasPendingClarification &&
        !hasActiveDraft &&
        _isCreateIntent(norm, prediction.intent)) {
      intent = EgyptianIntent.createTask;
    }

    if (hasPendingClarification && !safety.negated && !safety.quotedExample) {
      if (intent == EgyptianIntent.unknown ||
          prediction.intent == EgyptianIntent.clarificationAnswer ||
          _looksLikeShortAnswer(norm)) {
        intent = EgyptianIntent.clarificationAnswer;
      }
    }

    final reqDate = parseDate(norm, now);
    final reqTime = parseTime(norm);
    final reqPrio = parseExplicitPriority(norm);
    final inMins = parseInMinutes(norm);
    final specs = (intent == EgyptianIntent.createTask ||
            intent == EgyptianIntent.reminder ||
            intent == EgyptianIntent.clarificationAnswer)
        ? extractTaskSpecs(correctedRaw, now)
        : const <ExtractedTaskSpec>[];

    final targetQuery = _extractQueryForIntent(correctedRaw, intent);

    String? clarQ;
    String? pendingAct;
    var needsClar = false;
    var rationale = isEn
        ? 'Local classifier (${_intentModel.modelVersion}) at ${(prediction.confidence * 100).toStringAsFixed(0)}% confidence.'
        : 'تصنيف محلي (${_intentModel.modelVersion}) بثقة ${(prediction.confidence * 100).toStringAsFixed(0)}%.';

    if (safety.blocksWrite && !hasPendingClarification && !hasActiveDraft) {
      needsClar = true;
      clarQ = _safetyClarificationMessage(safety, isEnglish: isEn);
      pendingAct = 'other';
      rationale = isEn
          ? 'Blocked direct write to protect your schedule (negation/question/quote/future statement).'
          : 'تم إيقاف التنفيذ لحماية جدولك (نفي/سؤال/اقتباس/صيغة مستقبلية).';
    } else if (intent == EgyptianIntent.createTask && specs.isNotEmpty) {
      final first = specs.first;
      if (specs.length == 1 && first.isMissingTitle) {
        needsClar = true;
        pendingAct = 'create_task';
        clarQ = _clarificationForMissingTitle(first, now: now, isEnglish: isEn);
        rationale = isEn
            ? 'Time was understood, but the task title is missing; asking one concise clarifying question.'
            : 'تم فهم الميعاد لكن اسم المهمة غير محدد؛ يلزم سؤال استيضاحي واحد.';
      } else if (specs.length == 1 &&
          first.date == null &&
          first.time == null &&
          first.inMinutes == null &&
          !first.explicitNoDate) {
        needsClar = true;
        pendingAct = 'create_task';
        clarQ = _clarificationForUnderspecifiedTask(first, isEnglish: isEn);
        rationale = isEn
            ? 'Underspecified date/details; asking one concise clarifying question.'
            : 'عنوان غير مكتمل الميعاد أو التفاصيل؛ يلزم سؤال استيضاحي واحد.';
      }
    } else if (intent == EgyptianIntent.unknown) {
      needsClar = true;
      pendingAct = 'other';
      clarQ = isEn
          ? 'Not quite sure what you want me to do: should I add a task, reschedule an existing one, or plan your day?'
          : 'مش متأكد قصدك بالضبط إيه: تحب تضيف مهمة جديدة، تعدّل ميعاد، ولا ترتّب جدولك؟';
      rationale = isEn
          ? 'Confidence or margin below dev-calibrated threshold.'
          : 'الثقة أو الهامش أقل من الحد المعاير على بيانات التطوير.';
    }

    final slots = <String, dynamic>{
      if (specs.isNotEmpty)
        'tasks': [
          for (final s in specs)
            {
              'title': s.title,
              if (s.date != null) 'date': WallClock.ymd(s.date!),
              if (s.time != null) 'time': s.time,
              'priority': s.priority,
              if (s.category != null) 'category': s.category,
            },
        ],
      if (targetQuery.isNotEmpty) 'query': targetQuery,
      if (reqDate != null) 'date': WallClock.ymd(reqDate),
      'time': ?reqTime,
      'priority': ?reqPrio,
      'in_minutes': ?inMins,
    };

    final understanding = AssistantUnderstandingResult(
      modelVersion: _intentModel.modelVersion,
      originalText: rawInput,
      normalizedText: norm,
      intent: intent,
      confidence: prediction.confidence,
      margin: prediction.margin,
      slots: slots,
      sourceTextSpan: TextSpanRef(
        start: 0,
        end: rawInput.length,
        text: rawInput,
      ),
      needsClarification: needsClar,
      clarificationQuestion: clarQ,
      pendingAction: pendingAct,
      safetyFlags: safety,
      rationale: rationale,
    );

    return NluAnalysisOutcome(
      understanding: understanding,
      taskSpecs: specs,
      targetQuery: targetQuery,
      requestedDate: reqDate,
      requestedTime: reqTime,
      requestedPriority: reqPrio,
      inMinutes: inMins,
      correctedRaw: correctedRaw,
    );
  }

  NluSafetyFlags _detectSafetyFlags({
    required String rawInput,
    required String rawNorm,
    required String norm,
    required bool selfCorrected,
    required bool hasPendingClarification,
    required bool hasActiveDraft,
  }) {
    final hasQuotes = RegExp(r'["«»“”]').hasMatch(rawInput) ||
        RegExp(r'(?:^|\s)(?:قال|قالي|قالتلي|المعلم قال|الدكتور قال|المدرس قال)(?=\s|$)')
            .hasMatch(norm);

    // Explicitly protect negation commands (Egyptian + English).
    final negatedAction = RegExp(
          r'(?:^|\s)(?:ما\s+\S*ش|ما\S+ش|مت\S+ش|بلاش\s+(?:ت|ن|تحذف|تمسح|تضيف|تشيل|تلغي)|لا\s+(?:تحذف|تمسح|تضيف|تشيل)|مش\s+عايز\s+(?:اضيف|امسح|احذف|الغي))(?=\s|$)',
        ).hasMatch(rawNorm) ||
        RegExp(
          r"\b(?:do\s+not|don'?t|never|stop)\s+(?:delete|remove|add|create|cancel|complete|move|reschedule|clear|touch)\b",
          caseSensitive: false,
        ).hasMatch(rawInput);

    // Pure hypothetical / permission questions (Egyptian + English).
    final isHypotheticalOrPermission = RegExp(
          r'^(?:هل\s+|ينفع\s+|هو\s+ينفع\s+|لو\s+كنت\s+)',
        ).hasMatch(norm) ||
        RegExp(r'(?:^|\s)لو\s+حبيت(?=\s|[؟?]|$)').hasMatch(norm) ||
        (norm.startsWith('ممكن ') &&
            (rawInput.contains('؟') || rawInput.contains('?'))) &&
            !RegExp(r'(?:الساعه|\d|بكره|النهارده|الخميس|الجمعه|السبت|الاحد)')
                .hasMatch(norm) ||
        RegExp(
          r'\b(?:what\s+if|if\s+you\s+had|if\s+i\s+had|hypothetically)\b',
          caseSensitive: false,
        ).hasMatch(rawInput) ||
        (RegExp(r'^(?:can\s+you|could\s+you|would\s+you)\b', caseSensitive: false)
                .hasMatch(rawInput) &&
            (rawInput.contains('?') || RegExp(r'\bwithout\s+internet\b', caseSensitive: false).hasMatch(rawInput)));

    // Future self-statements without command verb.
    final isFutureStatement = ((RegExp(r'(?:^|\s)لسه\s+ه').hasMatch(norm) ||
                (RegExp(r'(?:^|\s)هخلص(?=\s|$)').hasMatch(norm) &&
                    !RegExp(r'(?:^|\s)(?:ضيف|سجل|حط|فكرني|ذكرني|لازم|عندي|ورايا)(?=\s|$)')
                        .hasMatch(norm))) ||
            (RegExp(r"\b(?:i\s+will|i'll|going\s+to|gonna)\s+(?:finish|study|do|complete)\b", caseSensitive: false)
                    .hasMatch(rawInput) &&
                !RegExp(r'\b(?:add|create|remind|schedule|new\s+task)\b', caseSensitive: false)
                    .hasMatch(rawInput))) &&
        !hasPendingClarification &&
        !hasActiveDraft;

    return NluSafetyFlags(
      negated: negatedAction && !hasActiveDraft,
      hypotheticalOrQuestion: isHypotheticalOrPermission,
      futureNotCompleted: isFutureStatement,
      quotedExample: hasQuotes,
      selfCorrected: selfCorrected,
      lowConfidence: false,
    );
  }

  String _safetyClarificationMessage(NluSafetyFlags safety, {bool isEnglish = false}) {
    if (safety.negated) {
      return isEnglish
          ? 'Got it — you do not want me to run that action, so I left your tasks unchanged.'
          : 'فهمت إنك مش عايز أنفّذ الإجراء ده، فما عدّلتش أي حاجة في مهامك.';
    }
    if (safety.quotedExample) {
      return isEnglish
          ? 'This looks like quoted text rather than a direct command, so I did not add it. Want me to add it as a real task?'
          : 'الجملة دي باين إنها كلام منقول أو بين علامات تنصيص، فما سجّلتهاش كمهمة. تحب أضيفها فعلًا لجدولك؟';
    }
    if (safety.futureNotCompleted) {
      return isEnglish
          ? 'It sounds like you are talking about future plans rather than giving a command — would you like me to add it to your task list?'
          : 'واضح إنك بتحكي عن خطة لسه هتعملها ومش بتأمر بالتعديل دلوقتي — تحب أضيفها كمهمة جديدة في جدولك؟';
    }
    return isEnglish
        ? 'That looks like a question or hypothetical scenario, not a direct change — nothing was modified. Tell me which step you want to apply.'
        : 'فهمت إن ده سؤال أو افتراض ومش أمر تنفيذ مباشر، فما عدّلتش جدولك. تحب أنفّذ خطوة معينة؟';
  }

  String _clarificationForMissingTitle(
    ExtractedTaskSpec spec, {
    required DateTime now,
    bool isEnglish = false,
  }) {
    final inMins = spec.inMinutes;
    if (inMins != null) {
      final shifted = now.add(Duration(minutes: inMins));
      final hh = shifted.hour % 12 == 0 ? 12 : shifted.hour % 12;
      final mm = shifted.minute.toString().padLeft(2, '0');
      final periodEn = shifted.hour >= 12 ? 'PM' : 'AM';
      final periodAr = shifted.hour >= 12 ? 'م' : 'ص';
      if (isEnglish) {
        final unit = inMins == 1 ? '1 minute' : '$inMins minutes';
        return 'Got it — I have the time locked in ($unit from now, at $hh:$mm $periodEn). What should I name this task? (Tell me if you also want a ringing alarm.)';
      }
      final minsAr = inMins == 1
          ? 'دقيقة'
          : (inMins == 2 ? 'دقيقتين' : '$inMins دقايق');
      return 'تمام! فهمت إن الميعاد بعد $minsAr (الساعة $hh:$mm $periodAr) — تحب نسمّي المهمة إيه بالظبط؟ (ولو عايزها منبه يرن قولّي)';
    }
    if (spec.date != null || spec.time != null) {
      final whenPart = [
        if (spec.date != null) WallClock.ymd(spec.date!),
        if (spec.time != null) spec.time!,
      ].join(' • ');
      return isEnglish
          ? 'Got the timing ($whenPart) — what should I name this task?'
          : 'فهمت الميعاد ($whenPart) — تحب نسمّي المهمة إيه بالظبط؟';
    }
    return isEnglish
        ? 'Sure! What task would you like me to add, and when should it happen?'
        : 'أكيد! إيه اسم المهمة اللي تحب نضيفها، وإمتى ميعادها؟';
  }

  String _clarificationForUnderspecifiedTask(
    ExtractedTaskSpec spec, {
    bool isEnglish = false,
  }) {
    if (spec.isVagueTitle) {
      return isEnglish
          ? 'Got "${spec.title}" — what exactly should I save it as (e.g. study, review, homework) and when is it due?'
          : 'فهمت إنك تقصد «${spec.title}» — تحب نسجّلها إيه بالضبط (مذاكرة، مراجعة، ولا واجب) وإمتى ميعادها؟';
    }
    return isEnglish
        ? 'Got it! When should I schedule "${spec.title}" (for example today or tomorrow), or leave it with no specific date?'
        : 'حلو! تحب نسجّل «${spec.title}» بميعاد إمتى (زي النهارده أو بكرة)، ولا نخليها من غير ميعاد محدد؟';
  }

  // ---------------------------------------------------------------------------
  // Multi-clause task extraction (fixed Arabic + English word-boundary splitting)
  // ---------------------------------------------------------------------------

  List<ExtractedTaskSpec> extractTaskSpecs(String raw, DateTime now) {
    final normAll = normalize(raw);
    final explicitNoDate = RegExp(
      r'(?:من\s+غير\s+ميعاد|بدون\s+ميعاد|مفتوح[هة]?|مش\s+محدد|no\s+(?:specific\s+)?date|any\s*time|undated)',
      caseSensitive: false,
    ).hasMatch(normAll);
    final segments = splitClauses(raw);
    final specs = <ExtractedTaskSpec>[];

    DateTime? carriedDate = parseDate(normAll, now);
    String? carriedHeadNoun;
    String? sharedHeadNoun;
    for (final seg in segments) {
      final h = detectHeadNoun(normalize(extractCleanClauseTitle(seg.text)));
      if (h != null) {
        sharedHeadNoun = h;
        break;
      }
    }

    for (var idx = 0; idx < segments.length; idx++) {
      final seg = segments[idx];
      final segNorm = normalize(seg.text);
      if (segNorm.isEmpty) continue;

      var segDate = parseDate(segNorm, now);
      if (segDate == null) {
        if (seg.dayOffsetFromPrevious > 0 && carriedDate != null) {
          segDate = carriedDate.add(Duration(days: seg.dayOffsetFromPrevious));
        } else if (seg.dayOffsetFromPrevious > 0) {
          segDate = now.add(Duration(days: 1 + seg.dayOffsetFromPrevious));
        } else if (segments.length > 1) {
          segDate = carriedDate;
        }
      }
      if (segDate != null) carriedDate = segDate;

      final segInMins = parseInMinutes(segNorm);
      var segTime = parseTime(segNorm);
      if (segInMins != null && segDate == null && segTime == null) {
        final shifted = now.add(Duration(minutes: segInMins));
        segDate = DateTime(shifted.year, shifted.month, shifted.day);
        segTime =
            '${shifted.hour.toString().padLeft(2, '0')}:${shifted.minute.toString().padLeft(2, '0')}';
        carriedDate = segDate;
      } else if (segTime != null && segDate == null) {
        segDate = DateTime(now.year, now.month, now.day);
        carriedDate = segDate;
      }

      var cleanTitle = extractCleanClauseTitle(seg.text);
      final isMissingTitle =
          cleanTitle.isEmpty || _isGenericPlaceholderOnly(normalize(cleanTitle));
      if (isMissingTitle) {
        if (segDate != null || segTime != null || segInMins != null) {
          specs.add(
            ExtractedTaskSpec(
              title: '',
              date: segDate,
              time: segTime,
              priority: parsePriority(segNorm),
              category: inferCategory(segNorm),
              isReminder: _isPureReminderVerb(segNorm) || segInMins != null,
              explicitNoDate: explicitNoDate,
              isVagueTitle: true,
              inMinutes: segInMins,
              isMissingTitle: true,
            ),
          );
        }
        continue;
      }

      final clauseHead = detectHeadNoun(normalize(cleanTitle));
      if (clauseHead != null) {
        carriedHeadNoun = clauseHead;
      } else {
        final effectiveHead = carriedHeadNoun ?? (segments.length > 1 ? sharedHeadNoun : null);
        if (effectiveHead != null &&
            cleanTitle.split(RegExp(r'\s+')).length <= 3) {
          cleanTitle = '$effectiveHead $cleanTitle';
        }
      }

      final combinedNorm = normalize('$segNorm $cleanTitle');
      final isVague = _isVagueSubjectOnly(normalize(cleanTitle)) &&
          !(segments.length > 1 && (segDate != null || segTime != null));

      specs.add(
        ExtractedTaskSpec(
          title: cleanTitle,
          date: segDate,
          time: segTime,
          priority: parsePriority(combinedNorm),
          category: inferCategory(combinedNorm),
          isReminder: _isPureReminderVerb(segNorm),
          explicitNoDate: explicitNoDate,
          isVagueTitle: isVague,
          inMinutes: segInMins,
          isMissingTitle: false,
        ),
      );
    }
    return specs;
  }

  List<({String text, int dayOffsetFromPrevious})> splitClauses(String raw) {
    // Stage 1: Explicit connectors & attached/spaced `و` before task/commitment/date words.
    final connectorRe = RegExp(
      r'\s*(?:،|,|؛|;|'
      r'(?:^|\s)(?:وبعده|و\s+بعده|وبعدها|و\s+بعدها|وتاني\s+يوم|و\s+تاني\s+يوم|واليوم\s+اللي\s+بعده|وكمان|و\s+كمان|وبعدين|و\s+بعدين|ثم|'
      r'and\s+(?:the\s+day\s+after|the\s+next\s+day|after\s+that|then)|then)(?=\s|$)|'
      r'(?:^|\s)and\s+(?=(?:tomorrow|today|tonight|on\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)|i\s+have|i\s+need|study|review|exam|quiz|meeting|call|report|lecture|course|homework|assignment|workout|gym)\b)|'
      r'(?:^|\s)و\s*(?=(?:عندي|ورايا|لازم|محتاج|مفروض|عاوز|عايز|هعمل|هروح|هسلم|هقدم|هحضر|هذاكر|هراجع|اذاكر|اراجع|اسلم|احضر|'
      r'امتحان|اختبار|كويز|مذاكره|مذاكرة|مراجعه|مراجعة|واجب|شيت|تسليم|محاضره|محاضرة|سكشن|كورس|درس|اجتماع|ميتنج|مكالمه|مكالمة|مشوار|كشف|تدريب|تمرين|جيم|تقرير|عرض|مشروع|تاسك|مهمه|مهمة|'
      r'السبت|الاحد|الأحد|الحد|الاتنين|الاثنين|التلات|الثلاثاء|الاربع|الأربعاء|الخميس|الجمعه|الجمعة|بكره|بكرة|بعد\s+بكره|بعد\s+بكرة|النهارده|انهارده)(?=\s|$)))\s*',
      caseSensitive: false,
    );

    final stage1 = <({String text, int dayOffsetFromPrevious})>[];
    var cursor = 0;
    var pendingOffset = 0;

    for (final m in connectorRe.allMatches(raw)) {
      final part = raw.substring(cursor, m.start).trim();
      if (part.isNotEmpty) {
        stage1.add((text: part, dayOffsetFromPrevious: pendingOffset));
      }
      final connNorm = normalize(m.group(0) ?? '');
      pendingOffset = (connNorm.contains('بعده') ||
              connNorm.contains('بعدها') ||
              connNorm.contains('تاني يوم') ||
              connNorm.contains('اليوم اللي بعده') ||
              connNorm.contains('day after') ||
              connNorm.contains('next day'))
          ? 1
          : 0;
      cursor = m.end;
    }

    final tail = raw.substring(cursor).trim();
    if (tail.isNotEmpty) {
      stage1.add((text: tail, dayOffsetFromPrevious: pendingOffset));
    }

    // Stage 2: Split compound segments that have multiple independent timed/subject clauses
    // (e.g. "عندي عربي الساعه 8 الصبح وبليل الساعه 8 امتحان انجليزي" or "مذاكرة فيزياء الساعة 4 وكيمياء الساعة 7").
    final out = <({String text, int dayOffsetFromPrevious})>[];
    for (final seg in stage1) {
      out.addAll(_splitCompoundTimedSegment(seg.text, seg.dayOffsetFromPrevious));
    }
    return out;
  }

  List<({String text, int dayOffsetFromPrevious})> _splitCompoundTimedSegment(
    String text,
    int initialOffset,
  ) {
    final conjRe = RegExp(
      r'\s+(?:و\s*(?!نص(?:\s|$)|ربع(?:\s|$)|تلت(?:\s|$)|ثلث(?:\s|$))|and\s+)',
      caseSensitive: false,
    );
    for (final m in conjRe.allMatches(text)) {
      final left = text.substring(0, m.start).trim();
      final right = text.substring(m.end).trim();
      if (left.isEmpty || right.isEmpty) continue;

      final leftNorm = normalize(left);
      final rightNorm = normalize(right);
      final leftTime = parseTime(leftNorm);
      final rightTime = parseTime(rightNorm);
      final rightHead = detectHeadNoun(rightNorm);
      final leftHasSubject = _containsKnownSubject(leftNorm);
      final rightHasSubject = _containsKnownSubject(rightNorm);

      final shouldSplit = (leftTime != null && rightTime != null) ||
          (rightHead != null && (leftTime != null || detectHeadNoun(leftNorm) != null || leftHasSubject)) ||
          (leftHasSubject && rightHasSubject && (leftTime != null || rightTime != null));

      if (shouldSplit) {
        final leftTitle = extractCleanClauseTitle(left);
        final rightTitle = extractCleanClauseTitle(right);
        if (leftTitle.isNotEmpty && rightTitle.isNotEmpty) {
          return [
            (text: left, dayOffsetFromPrevious: initialOffset),
            ..._splitCompoundTimedSegment(right, 0),
          ];
        }
      }
    }
    return [(text: text, dayOffsetFromPrevious: initialOffset)];
  }

  bool _containsKnownSubject(String normText) => containsAny(normText, const [
        'عربي', 'انجليزي', 'فرنساوي', 'فيزيا', 'فيزياء', 'كيميا', 'كيمياء',
        'احياء', 'رياضه', 'رياضيات', 'جبر', 'هندسه', 'تاريخ', 'جغرافيا',
        'برمجه', 'احصاء', 'فلسفه', 'منطق', 'الماني', 'اسباني',
        'arabic', 'english', 'french', 'physics', 'chemistry', 'biology',
        'math', 'calculus', 'history', 'geography',
      ]);

  String extractCleanClauseTitle(String rawClause) {
    var text = ArabicText.cleanDisplayPreserveCase(rawClause);
    text = text.replaceFirst(
      RegExp(
        r'^(?:بص\s+يعني|يعني|بص|أصلي|اصلي|طيب|طب|ماشي|يا\s+سيدي|يا\s+ريس|معلش|please|hey|hi|ok|okay)\s+',
        caseSensitive: false,
      ),
      '',
    );

    // Strip leading polite / command / desire wrappers (Egyptian + English, preserving case).
    final leadWrapper = RegExp(
      r'^(?:لو\s+سمحت|ممكن|يا\s+ريت|عاوزك|عايزك|can\s+you|could\s+you|please)?\s*'
      r'(?:(?:ت?(?:ضيفلي|ضيف|تضيفلي|تضيف|سجللي|سجلي|سجل|تسجل|حطلي|حط|تحطلي|تحط|تعمللي|اعملي|اعمل|اكتبلي|اكتب|تكتبلي|فكرني|تفكرني|ذكرني|تذكرني|نبهني|تنبهني|زودلي|زود)\s*(?:لي\s+)?(?:ب|بـ|ان|إن|عن)?\s*(?:تاسك|مهمه|مهمة|تذكير|تنبيه|منبه|معاد|ميعاد|موعد)?\s*(?:ل|لـ)?\s*)|'
      r'(?:(?:انا\s+)?(?:عندي|ورايا|لازم|محتاج|مفروض|علي|عليا|معايا|عاوز|عايز|حابب|نفسي|هعمل|هروح|هسلم|هقدم|هحضر)\s+(?:اني\s+|ان\s+|اضيف\s+|اسجل\s+)?)|'
      r'(?:(?:add|create)\s+(?:a\s+)?(?:new\s+)?task(?:\s+to)?\s+|new\s+task(?:\s*:|\s+to)?\s+|remind\s+me(?:\s+(?:in\s+\d+\s*\w+|at\s+\d+(?::\d{2})?\s*(?:am|pm)?))?\s+to\s+|schedule\s+(?:a\s+)?|i\s+need\s+to\s+|i\s+have\s+(?:to\s+|(?:an?\s+)?(?=(?:exam|quiz|meeting|call|appointment|presentation|task)\b))))',
      caseSensitive: false,
    );
    text = text.replaceFirst(leadWrapper, '').trim();
    // Apply a second pass for chained wrappers.
    text = text
        .replaceFirst(
          RegExp(
            r'^(?:ضيفلي|ضيف|اسجل|سجلي|سجل|احط|حط|اكتب|تاسك|مهمه|مهمة|to\s+|task\s+to\s+)\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // Normalize colloquial imperfect study/review verbs at title start into clean Arabic nouns.
    text = text
        .replaceFirst(RegExp(r'^و(?=(?:امتحان|اختبار|كويز|مذاكر|مراجع|واجب|تسليم|محاضر|سكشن|كورس|درس|اجتماع|مكالم|مشوار|تمرين|تقرير|مشروع))'), '')
        .replaceFirst(RegExp(r'^(?:اذاكر|أذاكر|هذاكر)\s+'), 'مذاكرة ')
        .replaceFirst(RegExp(r'^(?:اراجع|أراجع|هراجع)\s+'), 'مراجعة ')
        .replaceFirst(RegExp(r'^(?:اسلم|أسلم|هسلم)\s+'), 'تسليم ')
        .trim();

    // Strip period-first time expressions (e.g. "بليل الساعه 8", "الصبح 8").
    text = text.replaceAll(
      RegExp(
        r'(?:^|\s)(?:الصبح|صباحا|صباحاً|الضهر|الظهر|العصر|المغرب|بليل|بالليل|مساء|مساءً)\s*(?:في\s+|علي\s+|على\s+)?(?:الساعه|الساعة|ساعه|ساعة)?\s*[0-9٠-٩]{1,2}(?::[0-9٠-٩]{1,2})?\s*(?:ونص|وربع|الا\s+ربع)?(?=\s|$)',
      ),
      ' ',
    );

    // Strip explicit time expressions (Arabic-boundary + English safe).
    text = text.replaceAll(
      RegExp(
        r'(?:في|علي|على)?\s*(?:الساعه|الساعة|ساعه|ساعة)\s*[0-9٠-٩]+(?::[0-9٠-٩]{1,2})?\s*(?:ونص|وربع|الا\s+ربع)?\s*(?:ص|م|صباحا|صباحاً|مساء|مساءً|الصبح|الضهر|الظهر|العصر|المغرب|بليل|بالليل)?',
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'(?:^|\s)[0-9٠-٩]{1,2}:[0-9٠-٩]{2}\s*(?:ص|م|am|pm)?(?=\s|$)',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'(?:^|\s)[0-9٠-٩]{1,2}\s+(?:الصبح|الضهر|الظهر|العصر|المغرب|بليل|بالليل|صباحا|صباحاً|مساء|مساءً)(?=\s|$)',
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'\b(?:at|around)\s+\d{1,2}(?::\d{2})?\s*(?:am|pm|tonight|in\s+the\s+(?:morning|afternoon|evening))?\b|\b\d{1,2}\s*(?:am|pm)\b|\b\d{1,2}\s+(?:tonight|in\s+the\s+(?:morning|afternoon|evening))\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // Strip relative and weekday dates cleanly without breaking surrounding English.
    text = text.replaceAll(
      RegExp(
        r'(?:^|\s)(?:يوم\s+)?(?:بعد\s+بكر[هة]|بكر[هة]|النهارد[هة]|انهارد[هة]|اليوم|غد[اً]?|الاسبوع\s+الجاي|الأسبوع\s+الجاي|'
        r'السبت|الاحد|الأحد|الحد|الاتنين|الإثنين|الاثنين|التلات|الثلاثاء|الاربع|الأربع|الأربعاء|الخميس|الجمعه|الجمعة)'
        r'(?:\s+الجاي[هة]?)?(?=\s|$)',
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'\b(?:on|by|for|this|next)?\s*(?:day\s+after\s+tomorrow|tomorrow|tmr|today|tonight|next\s+week|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'(?:^|\s)(?:بعد|كمان|خلال)\s+(?:[0-9٠-٩]+\s*(?:دقيق[هة]|دقايق|دقائق|د|ساع[هة]|ساعات|ايام|أيام|يوم|ثاني[هة]|ثواني)|'
        r'(?:تلات|ثلاث|اربع|أربع|خمس|خمسة|ست|سبع|تمان|تسع|عشر|عشرة|عشرين|تلاتين)\s*(?:دقايق|دقائق|دقيق[هة]|ساعات|ايام|أيام)|'
        r'دقيقتين|دقيق[هة](?:\s+واحد[هة])?|ساعتين|ساع[هة]\s+ونص|ساع[هة]\s+وربع|ساع[هة]|'
        r'نص\s+ساع[هة]|ربع\s+ساع[هة]|تلت\s+ساع[هة]|ثلث\s+ساع[هة]|يومين)(?=\s|$)',
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'\b(?:in|after)\s+(?:\d+|one|two|an?|half\s+an)\s*(?:minutes?|mins?|hours?|hrs?|days?)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(r'(?:^|\s)(?:بمنبه|كمنبه|منبه\s+يرن|بإشعار|باشعار|كإشعار|كاشعار)(?=\s|$)'),
      ' ',
    );
    text = text.replaceAll(
      RegExp(r'(?:^|\s)(?:الصبح|الضهر|الظهر|العصر|المغرب|بليل|بالليل|مساء|صباحا|من\s+غير\s+ميعاد|بدون\s+ميعاد)(?=\s|$)'),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'\b(?:this\s+(?:morning|afternoon|evening)|in\s+the\s+(?:morning|afternoon|evening)|morning|afternoon|evening|no\s+(?:specific\s+)?date|any\s*time|undated)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(r'\s*(?:بأولوية\s+(?:عالية|متوسطة|منخفضة|عاجلة)|مهمة|ضروري|عاجل|(?:with\s+)?(?:high|medium|low)\s+priority|urgent|asap)\s*$', caseSensitive: false),
      ' ',
    );

    text = text.replaceAll(RegExp(r'[.!؟،,]+$'), '').trim();
    text = text.replaceAll(RegExp(r'\s+(?:at|on|by|for|to)$', caseSensitive: false), '').trim();
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  bool _isGenericPlaceholderOnly(String normTitle) {
    final cleaned = normTitle.trim();
    if (cleaned.isEmpty) return true;
    const placeholders = {
      'تاسك', 'مهمه', 'حاجه', 'شغله', 'منبه', 'تذكير', 'تنبيه',
      'معاد', 'ميعاد', 'موعد', 'الامر', 'حاجة', 'مهمة', 'تاسك جديد',
      'مهمه جديده', 'منبه جديد', 'تذكير جديد',
      'task', 'new task', 'reminder', 'alarm', 'item', 'something', 'thing',
    };
    return placeholders.contains(cleaned);
  }

  bool _isVagueSubjectOnly(String normTitle) {
    final words = normTitle.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return true;
    const bareSubjects = {
      'العربي', 'عربي', 'الانجليزي', 'انجليزي', 'الفرنساوي', 'فرنساوي',
      'الفيزياء', 'الفيزيا', 'فيزياء', 'فيزيا', 'الكيمياء', 'الكيميا',
      'كيمياء', 'كيميا', 'الاحياء', 'احياء', 'الرياضه', 'الرياضيات',
      'جبر', 'هندسه', 'تاريخ', 'جغرافيا', 'تاسك', 'مهمه', 'حاجة', 'حاجه',
      'arabic', 'english', 'french', 'physics', 'chemistry', 'biology',
      'math', 'calculus', 'history', 'task', 'item', 'homework',
    };
    return words.length == 1 && bareSubjects.contains(words.first);
  }

  String? detectHeadNoun(String normClause) {
    const headNouns = [
      'امتحان', 'اختبار', 'كويز', 'مذاكره', 'مراجعه', 'واجب', 'شيت',
      'تسليم', 'محاضره', 'سكشن', 'كورس', 'درس', 'اجتماع', 'مكالمه',
      'مشوار', 'كشف', 'تدريب', 'تقرير', 'عرض', 'مشروع',
      'exam', 'quiz', 'study', 'review', 'homework', 'assignment',
      'lecture', 'course', 'meeting', 'call', 'report', 'presentation', 'project',
    ];
    for (final h in headNouns) {
      if (RegExp('(^|\\s)$h(\$|\\s)').hasMatch(normClause)) {
        return switch (h) {
          'مذاكره' => 'مذاكرة',
          'مراجعه' => 'مراجعة',
          'محاضره' => 'محاضرة',
          'مكالمه' => 'مكالمة',
          _ => h,
        };
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Date / time / priority / query extraction helpers
  // ---------------------------------------------------------------------------

  DateTime? parseDate(String normText, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final isoMatch = RegExp(r'\b(\d{4}-\d{2}-\d{2})\b').firstMatch(normText);
    if (isoMatch != null) return DateTime.tryParse(isoMatch.group(1)!);

    if (normText.contains('بعد بكره') || normText.contains('day after tomorrow')) {
      return today.add(const Duration(days: 2));
    }
    if (RegExp(r'(?:^|\s)(?:بكره|غدا|tomorrow|tmr|tonight)(?=\s|$)').hasMatch(normText)) {
      if (RegExp(r'(?:^|\s)tonight(?=\s|$)').hasMatch(normText)) {
        return today;
      }
      return today.add(const Duration(days: 1));
    }
    if (RegExp(r'(?:^|\s)(?:النهارده|انهارده|اليوم|today)(?=\s|$)').hasMatch(normText)) {
      return today;
    }
    if (normText.contains('الاسبوع الجاي') || normText.contains('next week')) {
      return today.add(const Duration(days: 7));
    }
    final afterDays = RegExp(r'(?:بعد|after|in)\s+(\d+)\s*(?:يوم|ايام|days?)').firstMatch(normText);
    if (afterDays != null) {
      final n = int.tryParse(afterDays.group(1) ?? '');
      if (n != null && n > 0 && n <= 365) return today.add(Duration(days: n));
    }
    if (normText.contains('بعد يومين') || normText.contains('in two days')) {
      return today.add(const Duration(days: 2));
    }

    const weekdayMap = <String, int>{
      'الاتنين': DateTime.monday,
      'الاثنين': DateTime.monday,
      'monday': DateTime.monday,
      'التلات': DateTime.tuesday,
      'التلاتاء': DateTime.tuesday,
      'الثلاثاء': DateTime.tuesday,
      'tuesday': DateTime.tuesday,
      'الاربع': DateTime.wednesday,
      'الاربعاء': DateTime.wednesday,
      'wednesday': DateTime.wednesday,
      'الخميس': DateTime.thursday,
      'thursday': DateTime.thursday,
      'الجمعه': DateTime.friday,
      'friday': DateTime.friday,
      'السبت': DateTime.saturday,
      'saturday': DateTime.saturday,
      'الاحد': DateTime.sunday,
      'الحد': DateTime.sunday,
      'sunday': DateTime.sunday,
    };
    for (final entry in weekdayMap.entries) {
      if (RegExp('(?:^|\\s)${entry.key}(?=\\s|\$)').hasMatch(normText)) {
        var diff = (entry.value - today.weekday + 7) % 7;
        if (diff == 0 && (normText.contains('الجاي') || normText.contains('next '))) {
          diff = 7;
        }
        return today.add(Duration(days: diff));
      }
    }
    return null;
  }

  String? parseTime(String normText) {
    final hm = RegExp(r'\b(\d{1,2}):(\d{2})\s*(ص|م|am|pm)?\b').firstMatch(normText);
    if (hm != null) {
      var h = int.parse(hm.group(1)!);
      final m = int.parse(hm.group(2)!);
      h = _adjustHour(h, hm.group(3), normText);
      if (h >= 0 && h < 24 && m >= 0 && m < 60) {
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
    }
    final spoken = RegExp(
      r'(?:الساعه|ساعه)?\s*(\d{1,2})\s*(ونص|وربع|الا ربع)?\s*(ص|م|الصبح|صباحا|الضهر|الظهر|العصر|المغرب|بليل|بالليل|مساء)',
    ).firstMatch(normText);
    if (spoken != null) {
      var h = int.parse(spoken.group(1)!);
      final frac = spoken.group(2) ?? '';
      var mins = 0;
      if (frac == 'ونص') mins = 30;
      if (frac == 'وربع') mins = 15;
      if (frac == 'الا ربع') {
        mins = 45;
        h = (h - 1 <= 0) ? 12 : h - 1;
      }
      h = _adjustHour(h, spoken.group(3), normText);
      if (h >= 0 && h < 24) {
        return '${h.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
      }
    }
    final periodFirst = RegExp(
      r'(?:^|\s)(الصبح|صباحا|الضهر|الظهر|العصر|المغرب|بليل|بالليل|مساء)\s*(?:الساعه|ساعه)?\s*(\d{1,2})(?:\s*(ونص|وربع|الا ربع))?(?=\s|$)',
    ).firstMatch(normText);
    if (periodFirst != null) {
      final period = periodFirst.group(1)!;
      var h = int.parse(periodFirst.group(2)!);
      final frac = periodFirst.group(3) ?? '';
      var mins = 0;
      if (frac == 'ونص') mins = 30;
      if (frac == 'وربع') mins = 15;
      if (frac == 'الا ربع') {
        mins = 45;
        h = (h - 1 <= 0) ? 12 : h - 1;
      }
      h = _adjustHour(h, period, normText);
      if (h >= 0 && h < 24) {
        return '${h.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
      }
    }
    final enSpoken = RegExp(
      r'\b(?:at\s+)?(\d{1,2})\s*(am|pm|tonight|in\s+the\s+morning|in\s+the\s+afternoon|in\s+the\s+evening|morning|evening)\b',
    ).firstMatch(normText);
    if (enSpoken != null) {
      var h = int.parse(enSpoken.group(1)!);
      final suf = enSpoken.group(2)!;
      final normalizedSuf = (suf.contains('morning') || suf == 'am') ? 'am' : 'pm';
      h = _adjustHour(h, normalizedSuf, normText);
      if (h >= 0 && h < 24) {
        return '${h.toString().padLeft(2, '0')}:00';
      }
    }
    final enAt = RegExp(r'\bat\s+(\d{1,2})\b').firstMatch(normText);
    if (enAt != null) {
      var h = int.parse(enAt.group(1)!);
      h = _adjustHour(h, null, normText);
      if (h >= 0 && h < 24) {
        return '${h.toString().padLeft(2, '0')}:00';
      }
    }
    final bareHour = RegExp(r'(?:الساعه|ساعه)\s*(\d{1,2})(?:\s*(ونص|وربع))?')
        .firstMatch(normText);
    if (bareHour != null) {
      var h = int.parse(bareHour.group(1)!);
      final frac = bareHour.group(2) ?? '';
      final mins = frac == 'ونص' ? 30 : (frac == 'وربع' ? 15 : 0);
      h = _adjustHour(h, null, normText);
      if (h >= 0 && h < 24) {
        return '${h.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
      }
    }
    return null;
  }

  int _adjustHour(int h, String? suffix, String fullNorm) {
    final s = suffix ?? '';
    final isEvening = s == 'م' ||
        s == 'pm' ||
        s == 'العصر' ||
        s == 'المغرب' ||
        s == 'بليل' ||
        s == 'بالليل' ||
        s == 'مساء' ||
        fullNorm.contains('بليل') ||
        fullNorm.contains('بالليل') ||
        fullNorm.contains('المغرب') ||
        fullNorm.contains('مساء') ||
        fullNorm.contains('tonight') ||
        fullNorm.contains('evening');
    final isMorning = s == 'ص' ||
        s == 'am' ||
        s == 'الصبح' ||
        s == 'صباحا' ||
        fullNorm.contains('morning');
    if (isEvening && h >= 1 && h <= 11) return h + 12;
    if (isMorning && h == 12) return 0;
    if (suffix == null &&
        !isEvening &&
        !isMorning &&
        h >= 1 &&
        h <= 6 &&
        !fullNorm.contains('الصبح') &&
        !fullNorm.contains('morning')) {
      return h + 12;
    }
    return h;
  }

  int? parseInMinutes(String normText) {
    if (RegExp(r'(?:بعد|كمان|خلال)\s+ساعه\s+ونص').hasMatch(normText) ||
        normText.contains('hour and a half')) {
      return 90;
    }
    if (RegExp(r'(?:بعد|كمان|خلال)\s+ساعه\s+وربع').hasMatch(normText)) {
      return 75;
    }
    if (RegExp(r'(?:بعد|كمان|خلال)\s+نص\s+ساعه').hasMatch(normText) ||
        normText.contains('half an hour')) {
      return 30;
    }
    if (RegExp(r'(?:بعد|كمان|خلال)\s+تلت\s+ساعه').hasMatch(normText) ||
        RegExp(r'(?:بعد|كمان|خلال)\s+ثلث\s+ساعه').hasMatch(normText)) {
      return 20;
    }
    if (RegExp(r'(?:بعد|كمان|خلال)\s+ربع\s+ساعه').hasMatch(normText) ||
        normText.contains('quarter hour')) {
      return 15;
    }
    if (RegExp(r'(?:بعد|كمان|خلال)\s+ساعتين').hasMatch(normText) ||
        normText.contains('two hours')) {
      return 120;
    }
    if (RegExp(r'(?:بعد|كمان|خلال)\s+ساعه(?=\s|$)').hasMatch(normText) ||
        RegExp(r'\b(?:in|after)\s+(?:an?|1|one)\s+hour\b').hasMatch(normText)) {
      return 60;
    }
    if (RegExp(r'(?:بعد|كمان|خلال)\s+دقيقتين(?=\s|$)').hasMatch(normText) ||
        RegExp(r'\b(?:in|after)\s+(?:two|2)\s+(?:mins?|minutes?)\b')
            .hasMatch(normText)) {
      return 2;
    }
    if (RegExp(r'(?:بعد|كمان|خلال)\s+دقيقه(?:\s+واحده)?(?=\s|$)')
            .hasMatch(normText) ||
        RegExp(r'\b(?:in|after)\s+(?:a|an|one|1)\s+(?:min|minute)\b')
            .hasMatch(normText)) {
      return 1;
    }
    final m = RegExp(
      r'(?:بعد|كمان|خلال|in|after)\s+(\d+)\s*(?:دقيقه|دقايق|دقائق|د(?=\s|$)|min|mins|minutes?)',
    ).firstMatch(normText);
    if (m != null) {
      final n = int.tryParse(m.group(1)!);
      if (n != null && n > 0 && n <= 1440) return n;
    }
    const wordNums = <String, int>{
      'تلات': 3,
      'ثلاث': 3,
      'اربع': 4,
      'خمس': 5,
      'خمسه': 5,
      'ست': 6,
      'سبع': 7,
      'تمان': 8,
      'تسع': 9,
      'عشر': 10,
      'عشره': 10,
      'خمسطاشر': 15,
      'عشرين': 20,
      'تلاتين': 30,
      'خمس واربعين': 45,
    };
    final wordMinMatch = RegExp(
      r'(?:بعد|كمان|خلال)\s+(خمس واربعين|تلاتين|عشرين|خمسطاشر|عشره|عشر|تسع|تمان|سبع|ست|خمسه|خمس|اربع|ثلاث|تلات)\s*(?:دقايق|دقائق|دقيقه)',
    ).firstMatch(normText);
    if (wordMinMatch != null) {
      return wordNums[wordMinMatch.group(1)];
    }
    final arHr = RegExp(r'(?:بعد|كمان|خلال)\s+(\d+)\s*(?:ساعات|ساعه)')
        .firstMatch(normText);
    if (arHr != null) {
      final n = int.tryParse(arHr.group(1)!);
      if (n != null && n > 0 && n <= 24) return n * 60;
    }
    final wordHrMatch = RegExp(
      r'(?:بعد|كمان|خلال)\s+(تلات|ثلاث|اربع|خمس|ست)\s*ساعات',
    ).firstMatch(normText);
    if (wordHrMatch != null) {
      final n = wordNums[wordHrMatch.group(1)];
      if (n != null) return n * 60;
    }
    final hr = RegExp(r'\b(?:in|after)\s+(\d+)\s*(?:hr|hrs|hours?)\b').firstMatch(normText);
    if (hr != null) {
      final n = int.tryParse(hr.group(1)!);
      if (n != null && n > 0 && n <= 24) return n * 60;
    }
    return null;
  }

  String parsePriority(String normText) => parseExplicitPriority(normText) ?? 'medium';

  String? parseExplicitPriority(String normText) {
    if (containsAny(normText, [
      'امتحان', 'اختبار', 'عاجل', 'ضروري', 'عاليه', 'مهم جدا', 'تسليم', 'كشف',
      'exam', 'urgent', 'asap', 'high priority', 'high', 'deadline',
    ])) {
      return 'high';
    }
    if (containsAny(normText, ['منخفضه', 'هاديه', 'قليله', 'عادي', 'low priority', 'low', 'optional'])) {
      return 'low';
    }
    if (containsAny(normText, ['متوسطه', 'medium priority', 'medium'])) return 'medium';
    return null;
  }

  String? inferCategory(String normText) {
    if (containsAny(normText, [
      'امتحان', 'اختبار', 'كويز', 'مذاكر', 'مراجع', 'واجب', 'شيت', 'محاضره',
      'سكشن', 'كورس', 'درس', 'عربي', 'انجليزي', 'فرنساوي', 'فيزيا', 'كيميا',
      'ml', 'deep learning', 'flutter', 'algorithm', 'calculus', 'study',
      'homework', 'exam', 'quiz', 'lecture', 'course', 'math',
    ])) {
      return 'study';
    }
    if (containsAny(normText, [
      'اجتماع', 'عميل', 'شغل', 'تقرير', 'عرض', 'مشروع', 'assignment',
      'meeting', 'client', 'work', 'report', 'slides', 'presentation', 'project', 'standup', 'tax',
    ])) {
      return 'work';
    }
    if (containsAny(normText, ['دكتور', 'كشف', 'دواء', 'جيم', 'تمرين', 'dentist', 'doctor', 'medicine', 'workout', 'gym'])) {
      return 'health';
    }
    if (containsAny(normText, ['فواتير', 'ايجار', 'البنك', 'مصاريف', 'rent', 'bill', 'bank', 'budget'])) {
      return 'finance';
    }
    return 'personal';
  }

  String _extractQueryForIntent(String raw, EgyptianIntent intent) {
    final prefix = switch (intent) {
      EgyptianIntent.completeTask =>
        r'^(?:انا\s+)?(?:خلصت|انجزت|انهيت|تم\s+(?:انهاء|تسليم)|شطبت\s+علي|عملت\s+done\s+(?:ل|لـ)?|علم\s+علي|علمها\s+خلصت|قفل|اقفل|mark|i\s+finished|finished|check\s+off|done\s+with)\s*(?:مهمه|مهمة|تاسك|the|task)?\s*',
      EgyptianIntent.deleteTask =>
        r'^(?:امسحلي|امسح|احذفلي|احذف|شيللي|شيل|الغي|إلغاء|delete|remove|cancel|drop)\s*(?:مهمه|مهمة|تاسك|ميعاد|موعد|the|task)?\s*',
      EgyptianIntent.updateTask =>
        r'^(?:اجللي|اجل|أجل|انقللي|انقل|غيرلي|غير|عدللي|عدّل|عدل|بدل|بدّل|خليلي|خلي|ارفع\s+اولويه|زود\s+اولويه|move|reschedule|change|push|postpone|shift)\s*(?:مهمه|مهمة|تاسك|ميعاد|موعد|the|task)?\s*',
      _ => r'^(?:دور\s+علي|ابحث\s+عن|فين|find|search\s+(?:for)?)\s*',
    };
    var q = raw
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceFirst(RegExp(prefix, caseSensitive: false), '')
        .replaceAll(
          RegExp(
            r'\s+(?:لبكرة|لبكره|بكرة|بكره|النهارده|اليوم|لـ?\s*يوم\s+\S+|يوم\s+\S+|للساعة\s*\d+|الساعة\s*\d+|خالص|خلاص|الحمد\s+لله|as\s+done|completed|from\s+my\s+list|task)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s+(?:to|at|on|back)\s+(?:today|tomorrow|next\s+\w+|monday|tuesday|wednesday|thursday|friday|saturday|sunday|high|low|medium|\d{1,2}(?::\d{2})?\s*(?:am|pm|hours?)?)\b.*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[.!؟،,]+$'), '')
        .trim();
    if (RegExp(r'^(?:ها|دي|ده|دول|الاخيره|التانيه|الأولى|it|this|that|last|second|first)?$', caseSensitive: false)
        .hasMatch(normalize(q))) {
      return '';
    }
    return q;
  }

  // ---------------------------------------------------------------------------
  // Domain-bounded intent overrides (zero test string overfitting)
  // ---------------------------------------------------------------------------

  bool _isExplicitOutOfScope(String norm) => containsAny(norm, [
        'نكتة', 'نكته', 'قصيده', 'شعر رومانسي', 'الطقس', 'سعر الدولار',
        'ماتش الاهلي', 'فيلم', 'اغنية', 'اغنيه', 'يوتيوب', 'اترجملي', 'ترجملي',
        'اعمل لي صوره', 'ايميل رسمي',
        'weather forecast', 'tell me a joke', 'write me a python', 'translate this',
      ]);

  bool _isGreetingOnly(String norm, EgyptianIntent pred) {
    final words = norm.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length <= 6 &&
        containsAny(norm, [
          'اهلا', 'اهلين', 'مرحبا', 'ازيك', 'عامل ايه', 'السلام عليكم',
          'صباح الخير', 'مساء النور', 'مساء الخير', 'يا هلا', 'هاي',
          'hello', 'hi ', 'hey', 'good morning', 'good evening', 'good afternoon',
        ]) &&
        !norm.contains('مهام') &&
        !norm.contains('جدول') &&
        !norm.contains('task') &&
        !norm.contains('schedule')) {
      return true;
    }
    return pred == EgyptianIntent.greeting && words.length <= 3;
  }

  bool _isScheduleIntent(String norm, EgyptianIntent pred) =>
      containsAny(norm, [
        'رتب', 'اولويات', 'اولويه', 'نظملي', 'انظم جدول', 'جدوللي',
        'ابدأ بايه', 'ابدا بايه', 'ابدا منين', 'مزنوق', 'خطط معايا',
        'plan my day', 'build a schedule', 'study schedule', 'prioritize my',
        'organize my tasks', 'arrange my workload',
      ]) ||
      pred == EgyptianIntent.schedule;

  bool _isSummaryIntent(String norm, EgyptianIntent pred) =>
      containsAny(norm, [
        'لخص', 'ملخص', 'إجمالي', 'اجمالي', 'انجزت كام', 'إنجازي', 'انجازي',
        'نسبة إنجازي', 'نبذة سريعة', 'summary', 'summarize', 'completion rate',
        'how many tasks', 'my progress',
      ]) ||
      pred == EgyptianIntent.summary;

  bool _isListTasksIntent(String norm, EgyptianIntent pred) {
    if (containsAny(norm, [
      'ايه اللي ورايا', 'ورايا ايه', 'عندي ايه', 'وريني', 'اعرضلي',
      'المتبقيه', 'المفتوحه', 'المتاخره', 'المتأخرة', 'دور على', 'دور علي',
      'show me my tasks', 'show tasks', 'list tasks', 'list all', 'what tasks do i have',
      'pending tasks', 'overdue',
    ])) {
      return true;
    }
    return pred == EgyptianIntent.listTasks;
  }

  bool _isCompleteIntent(String norm, EgyptianIntent pred) =>
      (RegExp(r'^(?:انا\s+)?(?:خلصت|انجزت|انهيت|تم\s+(?:انهاء|تسليم)|شطبت|عملت\s+done|علمها\s+خلص|قفل\s+تاسك)(?=\s|$)')
              .hasMatch(norm) &&
          !norm.contains('كام')) ||
      RegExp(r'^(?:mark\b.*\bdone|i\s+finished|check\s+off|done\s+with)\b').hasMatch(norm) ||
      pred == EgyptianIntent.completeTask;

  bool _isDeleteIntent(String norm, EgyptianIntent pred) =>
      RegExp(r'^(?:امسح|امسحلي|احذف|احذفلي|شيل|شيللي|الغي|إلغاء)(?=\s|$)')
          .hasMatch(norm) ||
      RegExp(r'^(?:delete|remove|cancel|drop)\b').hasMatch(norm) ||
      pred == EgyptianIntent.deleteTask;

  bool _isUpdateIntent(String norm, EgyptianIntent pred) =>
      (RegExp(r'^(?:اجل|أجل|انقل|غير|عدل|بدل|خليها|خلي|ارفع\s+اولويه|زود\s+اولويه)(?=\s|$)')
              .hasMatch(norm) &&
          !norm.contains('نفسك')) ||
      RegExp(r'^(?:move|reschedule|postpone|push|shift|change\s+.*\bpriority)\b').hasMatch(norm) ||
      pred == EgyptianIntent.updateTask;

  bool _isPureReminderVerb(String norm) =>
      norm.contains('فكرني') ||
      norm.contains('ذكرني') ||
      norm.contains('تذكير') ||
      norm.contains('تنبيه') ||
      norm.contains('نبهني') ||
      norm.contains('منبه') ||
      containsAny(norm, ['remind me', 'set an alarm', 'ping me', 'notify me']);

  bool _isPureReminderIntent(String norm, EgyptianIntent pred) =>
      _isPureReminderVerb(norm) || pred == EgyptianIntent.reminder;

  bool isConversationalCoachingQuery(String norm) => containsAny(norm, const [
        'مش قادر اركز', 'مشتت', 'مشكله في التركيز', 'مشكله اني بسوف',
        'تسويف', 'بسوف', 'مكسل', 'زهقت', 'تعبان شويه', 'مش عارف اذاكر',
        'ازاي اذاكر', 'ازاي اركز', 'ازاي انظم', 'ازاي اتعامل مع',
        'نصيحه', 'اديني نصيحه', 'شجعني', 'فقدت الشغف', 'ماليش نفس',
        'بومودورو', 'جلسه تركيز', 'جلسة تركيز', 'ابدا تركيز',
        'how do i study', 'how to focus', 'study tip', 'focus tip',
        'cant focus', "can't focus", 'procrastinat', 'burnt out', 'burned out',
        'no motivation', 'pomodoro',
      ]);

  bool _isCreateIntent(String norm, EgyptianIntent pred) {
    if (RegExp(r'^(?:عندي\s+ايه|ايه\s+اللي\s+عندي|وريني|اعرض|هل\s+عندي|what\s+tasks|show\s+me|list\s+)').hasMatch(norm)) {
      return false;
    }
    final hasExplicitCreateVerb = containsAny(norm, [
      'ضيف', 'سجل', 'حطلي', 'حط ', 'اكتبلي', 'عاوز اذاكر', 'عايز اذاكر',
      'add a task', 'add task', 'create a task', 'create a new task', 'new task',
    ]);
    if (isConversationalCoachingQuery(norm) && !hasExplicitCreateVerb) {
      return false;
    }
    if (hasExplicitCreateVerb || containsAny(norm, ['تاسك ', 'i need to'])) {
      return true;
    }
    final hasCommitment = RegExp(
      r'(?:^|\s)(?:عندي|ورايا|لازم|محتاج|مفروض|علي|عليا|مضطر|معايا|هعمل|هروح|هسلم|هقدم|هحضر|هراجع)(?=\s|$)',
    ).hasMatch(norm);
    final hasTemporalOrActionCue = parseDate(norm, DateTime(2026)) != null ||
        parseTime(norm) != null ||
        parseInMinutes(norm) != null ||
        detectHeadNoun(norm) != null ||
        containsAny(norm, const ['تاسك', 'مهمه', 'شغل', 'كشف', 'ميعاد', 'معاد']);
    if (hasCommitment && hasTemporalOrActionCue) {
      return true;
    }
    return pred == EgyptianIntent.createTask && !isConversationalCoachingQuery(norm);
  }

  bool _looksLikeShortAnswer(String norm) =>
      norm.split(' ').length <= 8 &&
      (parseDate(norm, DateTime(2026)) != null ||
          parseTime(norm) != null ||
          containsAny(norm, [
            'مذاكره', 'مراجعه', 'واجب', 'امتحان', 'من غير ميعاد', 'ايوه', 'تمام',
            'الاولي', 'التانيه', 'no specific date', 'anytime', 'undated', 'yes',
            'ok', 'first', 'second', 'works for me',
          ]));

  bool containsAny(String normText, List<String> needles) =>
      needles.any((n) => normText.contains(normalize(n)));

  String normalize(String raw) => ArabicText.normalizeForMatching(raw)
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
}
