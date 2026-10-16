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


  /// Normalizes Arabic text for lightweight comparison/search only.
  /// Do not use this as the displayed title: it intentionally folds common
  /// spelling variants (أ/إ/آ -> ا, ى -> ي) and removes tashkeel/tatweel.
  static String normalizeForMatching(String input) {
    var t = normalizeDigits(input).toLowerCase();
    t = t.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '');
    t = t.replaceAll(RegExp(r'[أإآٱ]'), 'ا').replaceAll('ى', 'ي');
    t = t.replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E]'), '');
    t = t.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ');
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
