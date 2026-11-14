/// Small Arabic text helpers.
class ArabicText {
  ArabicText._();

  static const _weekdays = [
    'الاتنين', 'التلات', 'الأربع', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
  ];

  /// DateTime.weekday (Mon=1..Sun=7) -> Egyptian weekday name.
  static String weekday(int dartWeekday) => _weekdays[(dartWeekday - 1) % 7];

  /// Converts Arabic-Indic (٠-٩) and Persian (۰-۹) digits to ASCII digits.
  static String normalizeDigits(String input) {
    final b = StringBuffer();
    for (final r in input.runes) {
      if (r >= 0x0660 && r <= 0x0669) {
        b.writeCharCode(0x30 + (r - 0x0660));
      } else if (r >= 0x06F0 && r <= 0x06F9) {
        b.writeCharCode(0x30 + (r - 0x06F0));
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }


  /// Collapses excessive elongation in Arabic letters (3+ identical chars -> 1),
  /// e.g. "عااااوز" -> "عاوز", while preserving digits and English identifiers.
  static String collapseElongation(String input) {
    return input.replaceAllMapped(
      RegExp(r'([\u0621-\u064A])\1{2,}'),
      (m) => m.group(1)!,
    );
  }

  /// Normalizes Arabic text for lightweight comparison/search only.
  /// Do not use this as the displayed title: it intentionally folds common
  /// spelling variants (أ/إ/آ -> ا, ى -> ي) and removes tashkeel/tatweel.
  static String normalizeForMatching(String input) {
    var t = collapseElongation(normalizeDigits(input)).toLowerCase();
    t = t.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '');
    t = t.replaceAll(RegExp(r'[أإآٱ]'), 'ا').replaceAll('ى', 'ي');
    t = t.replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E]'), '');
    t = t.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Normalizes for NLU classification/patterning, additionally folding ة/ه and ؤ/و and ئ/ي.
  static String normalizeForNlu(String input) => normalizeForMatching(input)
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');

  /// Resolves mid-sentence self-corrections (especially common in voice/STT),
  /// e.g. "ضيفلي مراجعة الفيزيا بكرة لا قصدي الخميس الساعة 8" ->
  /// "ضيفلي مراجعة الفيزيا الخميس الساعة 8", while allowing full-clause
  /// replacement when the correction begins with a new command verb.
  static ({String resolved, bool hadCorrection, String? prefix, String? correction})
      resolveSelfCorrection(String raw) {
    final cleaned = raw.trim();
    final pivot = RegExp(
      r'(?:^|\s)(?:—|-|،|,)?\s*(?:لأ\s+قصدي|لا\s+قصدي|لا\s+لا(?:\s+قصدي|\s+خليها)?|أقصد|اقصد|قصدي|no\s+i\s+meant|no\s+sorry|i\s+meant)\s+',
      caseSensitive: false,
    );
    final matches = pivot.allMatches(cleaned).toList();
    if (matches.isEmpty) {
      return (resolved: cleaned, hadCorrection: false, prefix: null, correction: null);
    }
    final last = matches.last;
    final prefix = cleaned.substring(0, last.start).trim();
    final correction = cleaned.substring(last.end).trim();
    if (correction.isEmpty) {
      return (resolved: cleaned, hadCorrection: false, prefix: null, correction: null);
    }
    final resolved = _spliceSelfCorrection(prefix, correction);
    return (
      resolved: resolved,
      hadCorrection: true,
      prefix: prefix,
      correction: correction,
    );
  }

  static String _spliceSelfCorrection(String prefix, String correction) {
    if (prefix.isEmpty) return correction;
    final corrNorm = normalizeForNlu(correction);
    final prefixNorm = normalizeForNlu(prefix);

    final fullVerbRe = RegExp(
      r'^(?:ضيف(?:لي|لنا|ها|ه)?|اضف|اعمل|انشي|امسح|احذف|الغي|شيل|عدل|اجل|حرك|خلصت|انجزت|كملت|رتب|خطط|نظم|وريني|اعرض|هات|add|create|delete|remove|cancel|move|reschedule|complete|finish|plan|schedule|show|list)(?=\s|$)',
    );
    if (fullVerbRe.hasMatch(corrNorm)) {
      return correction;
    }

    var effectiveCorr = correction;
    final startsCreatePrefix = RegExp(
      r'^(?:ضيف(?:لي|لنا)?|اضف|اعمل|سجل|عندي|عاوز|عايز|add|create|schedule)\s+',
    ).hasMatch(prefixNorm);
    if (startsCreatePrefix) {
      effectiveCorr = effectiveCorr.replaceFirst(
        RegExp(r'^(?:خلّيها|خليها|خلّيه|خليه|اجلها|أجلها|make\s+it)\s+', caseSensitive: false),
        '',
      ).trim();
      if (effectiveCorr.isEmpty) effectiveCorr = correction;
    }

    var work = prefix;
    var strippedAny = false;
    final trailingPatterns = [
      RegExp(
        r'(?:\s+(?:على|علي|في|الساعة|ساعة|الساعه|ساعه|at))?\s*\d{1,2}(?::\d{2})?(?:\s*(?:صباحا|صباحاً|الصبح|مساء|مساءً|بالليل|بليل|العصر|المغرب|الضهر|الظهر|فجرا|am|pm))?\s*$',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:\s+(?:في|على|علي|يوم|لـ|ل|on|by|for|this|next))?\s*(?:بكرة|بكره|بكرا|بعد\s+بكرة|بعد\s+بكره|بعده|النهاردة|النهارده|اليوم|امبارح|أمس|الاسبوع\s+الجاي|الأسبوع\s+الجاي|الشهر\s+الجاي|السبت|الأحد|الاحد|الإثنين|الاثنين|الاتنين|الثلاثاء|التلات|الأربعاء|الأربع|الاربع|الخميس|الجمعة|الجمعه|today|tomorrow|tmr|yesterday|next\s+week|monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+(?:الجاي|الجاية))?\s*$',
        caseSensitive: false,
      ),
      RegExp(
        r'\s+(?:بأولوية|باولوية|أولوية|اولوية)\s*(?:عالية|متوسطة|منخفضة|high|medium|low)|\s+(?:مهمة?\s+جدا|عاجلة?|عاجل|urgent|high|low)\s*$',
        caseSensitive: false,
      ),
    ];

    var progress = true;
    while (progress) {
      progress = false;
      for (final re in trailingPatterns) {
        final next = work.replaceFirst(re, '').trim();
        if (next != work) {
          work = next;
          strippedAny = true;
          progress = true;
        }
      }
    }

    work = work.replaceFirst(RegExp(r'\s+(?:في|على|علي|ل|لـ|at|on|by|for)$'), '').trim();
    if (work.isEmpty) return effectiveCorr;
    if (strippedAny) return '$work $effectiveCorr';

    final corrIsModifier = RegExp(
      r'^(?:الساعة|ساعة|الساعه|\d{1,2}(?::\d{2})?|بكرة|بكره|بكرا|بعد|النهاردة|النهارده|اليوم|السبت|الأحد|الاحد|الإثنين|الاثنين|الاتنين|التلات|الأربع|الاربع|الخميس|الجمعة|today|tomorrow|next|at|on|monday|tuesday|wednesday|thursday|friday|saturday|sunday|high|medium|low|أولوية|اولوية|من\s+غير|بدون)',
      caseSensitive: false,
    ).hasMatch(effectiveCorr);
    if (corrIsModifier) {
      return '$work $effectiveCorr';
    }

    final words = work.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      final corrWords = effectiveCorr.split(RegExp(r'\s+'));
      if (corrWords.length == 1) {
        return '${words.sublist(0, words.length - 1).join(' ')} $effectiveCorr';
      }
      return '${words.first} $effectiveCorr';
    }
    return effectiveCorr;
  }

  /// Removes tashkeel/tatweel and conversational voice fillers without changing English casing.
  static String cleanDisplayPreserveCase(String raw) {
    var t = raw.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '');
    t = collapseElongation(t);
    t = t.replaceFirst(
      RegExp(r'^(?:آه|اه|أه|امم|بص|يعني|يا\s+ريت|لو\s+سمحت)[،,\s]+'),
      '',
    );
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// True when normalized strings are equivalent for broad Arabic matching.
  static bool matchesForSearch(String a, String b) =>
      normalizeForMatching(a) == normalizeForMatching(b);

  /// Removes markdown/emoji so TTS engines don't read symbols aloud.
  static String cleanForTts(String s) {
    var t = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!);
    t = t.replaceAll(RegExp(r'[*_`#>~|]'), '');
    t = t.replaceAll(
        RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]', unicode: true), '');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
