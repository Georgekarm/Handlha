import 'dart:math' as math;

import '../util/arabic_text.dart';

/// Shared feature extractor used verbatim by both offline trainer and runtime NLU.
class EgyptianNluFeatures {
  const EgyptianNluFeatures._();

  static final _negCommandRegex = RegExp(
    r'(?:^|\s)(ما\s*\S+ش|مش\s+(?:عايز|ه|محتاج)|بلاش|مت\S+ش|لا\s+تحذف|لا\s+تمسح)(?=\s|$)',
  );
  static final _conditionalRegex = RegExp(r'(?:^|\s)(لو\s+كنت|لو\s+حبيت|لو\s+ينفع)(?=\s|$)');
  static final _quoteRegex = RegExp(r'["«»“”]');
  static final _questionPrefixRegex = RegExp(r'(?:^|\s)(هل|ينفع|ممكن|ايه|امتي|ازاي|كام)(?=\s|$)');

  /// Normalizes raw input for intent classification while preserving negation,
  /// self-correction cues, question markers, and normalized Latin tokens.
  static String normalizeInput(String raw) {
    final base = ArabicText.normalizeForNlu(raw);
    final withQ = (raw.contains('؟') || raw.contains('?')) && !base.endsWith('؟')
        ? '$base ؟'
        : base;
    return withQ.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Extracts L2-normalized features combining exact word forms, lightweight
  /// Egyptian stems, boundary bigrams, char 3-grams, and grammatical safety cues.
  static Map<String, double> extract(String raw) {
    final normalized = normalizeInput(raw);
    if (normalized.isEmpty) return const {};

    final counts = <String, double>{};
    final words = normalized.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const {};

    // Grammatical & pragmatic structure cues (general Arabic signals).
    if (raw.contains('؟') || raw.contains('?') || _questionPrefixRegex.hasMatch(normalized)) {
      _add(counts, 'cue:question', 1.5);
    }
    if (_negCommandRegex.hasMatch(normalized)) {
      _add(counts, 'cue:negation', 2.2);
    }
    if (_conditionalRegex.hasMatch(normalized)) {
      _add(counts, 'cue:conditional', 1.8);
    }
    if (_quoteRegex.hasMatch(raw)) {
      _add(counts, 'cue:quoted', 2.0);
    }
    if (RegExp(r'(?:^|\s)(لسه\s+ه|بفكر\s+ممكن|ممكن\s+ابقي)(?=\s|$)').hasMatch(normalized)) {
      _add(counts, 'cue:tentative_future', 1.9);
    }

    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w == '؟' || w == '?') continue;

      _add(counts, 'w:$w', 1.6);

      final stem = _lightEgyptianStem(w);
      if (stem.length >= 2 && stem != w) {
        _add(counts, 'm:$stem', 1.45);
      } else {
        _add(counts, 'm:$w', 0.9);
      }

      if (i == 0) {
        _add(counts, 'b:<BOS>_$stem', 1.2);
      }
      if (i + 1 < words.length && words[i + 1] != '؟') {
        final nextStem = _lightEgyptianStem(words[i + 1]);
        _add(counts, 'b:${w}_${words[i + 1]}', 0.9);
        _add(counts, 'bm:${stem}_$nextStem', 1.0);
      } else if (i == words.length - 1) {
        _add(counts, 'b:${stem}_<EOS>', 0.7);
      }

      if (w.length >= 3) {
        final bounded = '#$stem#';
        for (var j = 0; j + 3 <= bounded.length; j++) {
          _add(counts, 'c3:${bounded.substring(j, j + 3)}', 0.65);
        }
      }
    }

    var sq = 0.0;
    for (final v in counts.values) {
      sq += v * v;
    }
    if (sq <= 0) return counts;
    final norm = math.sqrt(sq);
    return counts.map((k, v) => MapEntry(k, v / norm));
  }

  /// Non-destructive morphological stem feature ONLY (never used for display text).
  static String _lightEgyptianStem(String token) {
    // Keep English tokens intact.
    if (RegExp(r'^[a-z0-9_+-]+$').hasMatch(token)) return token;
    var s = token;
    // Strip common proclitics only when token stays meaningful.
    if (s.length >= 4 && s.startsWith('ال')) {
      s = s.substring(2);
    } else if (s.length >= 5 && RegExp(r'^[وبفل]').hasMatch(s)) {
      s = s.substring(1);
    }
    // Strip common object/dative suffixes `-لي`, `-ني`, `-ها`, `-هم` when safe.
    for (final suffix in const ['لي', 'ني', 'ها', 'هم', 'نا']) {
      if (s.length >= suffix.length + 3 && s.endsWith(suffix)) {
        s = s.substring(0, s.length - suffix.length);
        break;
      }
    }
    if (s.length >= 4 && s.endsWith('ه') && !s.endsWith('ة')) {
      // e.g., النهارده -> preserve common time words
      if (token != 'النهارده' && token != 'نهارده' && token != 'بكره' && token != 'بعده') {
        s = s.substring(0, s.length - 1);
      }
    }
    return s;
  }

  static void _add(Map<String, double> map, String key, double weight) {
    map[key] = (map[key] ?? 0.0) + weight;
  }
}
