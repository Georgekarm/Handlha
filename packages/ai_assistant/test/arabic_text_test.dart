import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arabic-Indic digits are normalised', () {
    expect(ArabicText.normalizeDigits('بكرة الساعة ٨ و١٠ دقايق'), 'بكرة الساعة 8 و10 دقايق');
  });

  test('Arabic matching normalization handles digits, hamza, tashkeel and punctuation', () {
    expect(ArabicText.normalizeForMatching('إمتى؟ الساعة ٨!'), 'امتي الساعة 8');
    expect(ArabicText.matchesForSearch('أذاكر الـ AI', 'اذاكر ال ai'), isTrue);
    expect(ArabicText.normalizeForMatching('مُهِمّ ـ جدًا'), 'مهم جدا');
  });

  test('TTS cleaner strips markdown and emoji', () {
    expect(ArabicText.cleanForTts('**تمام** 👍 ضفتلك [التاسك](http://x)'), 'تمام ضفتلك التاسك');
  });

  test('WallClock keeps the app-supplied wall time and offset', () {
    final w = WallClock.tryParse('2026-10-04T18:00:00+03:00')!;
    expect(w.date, '2026-10-04');
    expect(w.time, '18:00');
    expect(w.weekday, DateTime.sunday);
    expect(w.offset, '+03:00');
    expect(w.dateAfter(1), '2026-10-05');
    expect(w.dateAfter(27), '2026-10-31');
  });

  test('WallClock rejects garbage', () {
    expect(WallClock.tryParse(null), isNull);
    expect(WallClock.tryParse(''), isNull);
    expect(WallClock.tryParse('tomorrow'), isNull);
    expect(WallClock.tryParse('2026-13-40T10:00:00+03:00'), isNull);
    expect(WallClock.tryParse('2026-10-04T25:00:00+03:00'), isNull);
  });

  test('System prompt contains the supplied date table, not an assumed one', () {
    final p = SystemPrompt.build(now: WallClock.tryParse(kNowForPrompt)!);
    expect(p, contains('2026-10-05 الاتنين = بكرة'));
    expect(p, contains('2026-10-11 الأحد'));
    expect(p, contains('Africa/Cairo'));
  });
}

const kNowForPrompt = '2026-10-04T18:00:00+03:00';
