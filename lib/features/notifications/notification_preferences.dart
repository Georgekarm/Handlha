import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tasks/domain/task.dart';

enum ReminderTone { supportive, direct }

enum ReminderUrgency { overdue, today, upcoming }

class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.enabled = true,
    this.tone = ReminderTone.supportive,
    this.quietHoursStartMinutes = 22 * 60,
    this.quietHoursEndMinutes = 8 * 60,
  });

  final bool enabled;
  final ReminderTone tone;
  final int quietHoursStartMinutes;
  final int quietHoursEndMinutes;

  @override
  List<Object> get props => [enabled, tone, quietHoursStartMinutes, quietHoursEndMinutes];

  NotificationPreferences copyWith({
    bool? enabled,
    ReminderTone? tone,
    int? quietHoursStartMinutes,
    int? quietHoursEndMinutes,
  }) => NotificationPreferences(
    enabled: enabled ?? this.enabled,
    tone: tone ?? this.tone,
    quietHoursStartMinutes: quietHoursStartMinutes ?? this.quietHoursStartMinutes,
    quietHoursEndMinutes: quietHoursEndMinutes ?? this.quietHoursEndMinutes,
  );

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'tone': tone.name,
    'quietHoursStartMinutes': quietHoursStartMinutes,
    'quietHoursEndMinutes': quietHoursEndMinutes,
  };

  factory NotificationPreferences.fromJson(Map<String, Object?> json) {
    final toneName = json['tone'] as String?;
    return NotificationPreferences(
      enabled: json['enabled'] as bool? ?? true,
      tone: ReminderTone.values.firstWhere(
        (tone) => tone.name == toneName,
        orElse: () => ReminderTone.supportive,
      ),
      quietHoursStartMinutes: _validMinute(json['quietHoursStartMinutes'], 22 * 60),
      quietHoursEndMinutes: _validMinute(json['quietHoursEndMinutes'], 8 * 60),
    );
  }

  static int _validMinute(Object? value, int fallback) {
    if (value is int && value >= 0 && value < 24 * 60) return value;
    return fallback;
  }
}

/// Stores non-sensitive notification choices locally, separately per account.
class LocalNotificationPreferences {
  const LocalNotificationPreferences._();

  static String _key(String userId) => 'notification_preferences_$userId';

  static Future<NotificationPreferences> load(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_key(userId));
    if (values == null || values.length != 4) return const NotificationPreferences();
    return NotificationPreferences.fromJson({
      'enabled': values[0] == 'true',
      'tone': values[1],
      'quietHoursStartMinutes': int.tryParse(values[2]),
      'quietHoursEndMinutes': int.tryParse(values[3]),
    });
  }

  static Future<void> save(String userId, NotificationPreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_key(userId), [
      value.enabled.toString(),
      value.tone.name,
      value.quietHoursStartMinutes.toString(),
      value.quietHoursEndMinutes.toString(),
    ]);
  }

  static Future<void> clear(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(userId));
  }
}

class ReminderMessage {
  const ReminderMessage({required this.urgency, required this.title, required this.body});

  final ReminderUrgency urgency;
  final String title;
  final String body;
}

/// Short Egyptian Arabic copy for the in-app inbox; it never changes task data.
class ReminderMessageCatalog {
  const ReminderMessageCatalog._();

  static const _dailySupportive = [
    'خدها واحدة واحدة؛ مش لازم تخلّص الدنيا كلها النهارده.',
    'حتى لو أنجزت حتة صغيرة، دي خطوة حقيقية لقدّام.',
    'يومك مش سباق. اختار أهم حاجة وابدأ براحتك.',
    'لو دماغك زحمة، اكتب أول خطوة بس وسيب الباقي بعدين.',
    'الراحة جزء من الخطة، مش مكافأة لازم تستناها.',
    'إنت ماشي كويس، كمّل على قد طاقتك ومن غير جلد ذات.',
    'مش لازم تستنى المزاج المثالي؛ خمس دقايق بداية حلوة.',
    'لو الخطة اتلخبطت، عادي. نرتبها تاني خطوة خطوة.',
  ];

  static const _dailyDirect = [
    'يلا نختار حاجة واحدة ونبدأ فيها دلوقتي.',
    'افتح المهمة وخد أول خطوة؛ الباقي هيبان بعدها.',
    'خمس دقايق تركيز أحسن من تأجيلها لآخر اليوم.',
    'رتّب أولوياتك بسرعة وابدأ بالأهم.',
    'بلاش تسيب المهمة معلّقة؛ يا تبدأها يا تحدد لها معاد.',
    'جاهز تخلّص خطوة صغيرة وتريح دماغك؟',
    'اختار مهمة واحدة، اقفل المشتتات، وابدأ.',
    'النهارده لسه فيه وقت؛ استغله في حاجة واحدة مفيدة.',
  ];

  static const _overdueSupportive = [
    'المعاد فات، بس عادي. خد نفس وقرّر: نبدأ فيها ولا نعيد جدولتها؟',
    'اتأخرت شوية؟ ولا يهمك. ظبّط المعاد على قد يومك وكمّل.',
    'مش محتاج تلوم نفسك؛ اختار أصغر خطوة أو أجّلها بوضوح.',
    'لسه تقدر تلحقها. ابدأ حتة بسيطة، أو غيّر معادها من غير ضغط.',
  ];

  static const _overdueDirect = [
    'المهمة اتأخرت. يلا نخلّص منها خطوة، أو نحدد لها معاد جديد.',
    'ما تسيبهاش معلّقة: ابدأ فيها دلوقتي أو أعد جدولتها.',
    'المعاد عدى؛ خد قرار واضح للمهمة دي وريح دماغك.',
    'يلا نبصّ لها: محتاجة تنفيذ دلوقتي ولا معاد أنسب؟',
  ];

  static const _todaySupportive = [
    'دي على جدول النهارده. ابدأ بخمس دقايق بس وشوف هتوصل لفين.',
    'لو عندك طاقة، ابدأ فيها دلوقتي. ولو لأ، ظبّط وقتها براحتك.',
    'خطوة صغيرة في المهمة دي كفاية كبداية حلوة.',
    'افتكر المهمة دي وسط يومك، وخليها على قد وقتك وطاقتك.',
  ];

  static const _todayDirect = [
    'يلا نخلّصها النهارده. ابدأ دلوقتي أو اختار لها ساعة واضحة.',
    'المهمة دي مستنياك النهارده؛ افتحها وخد أول خطوة.',
    'ما تأجلهاش من غير خطة. ابدأ أو غيّر معادها دلوقتي.',
    'خصص لها وقت النهارده وخلّصها من دماغك.',
  ];

  static const _upcomingSupportive = [
    'المهمة لسه قدامها وقت؛ مش لازم تشيل همّها دلوقتي.',
    'سجلناها لمعادها. ركّز في اللي عليك النهارده وسيب دي لوقتها.',
    'لسه بدري عليها؛ لما يقرب معادها هنفكّرك بيها هنا.',
    'خليها في بالك من غير استعجال، لسه عندك وقت ترتّبها.',
  ];

  static const _upcomingDirect = [
    'المهمة جاية قريب. بصّ على معادها وخطّط لها من دلوقتي.',
    'لسه فيه وقت، بس حدّد هتشتغل عليها إمتى.',
    'راجع تجهيزات المهمة قبل معادها عشان ما تتزنقش.',
    'المعاد قرب؛ حضّر أول خطوة بدل ما تسيبها لآخر لحظة.',
  ];

  static String dailyMessage(DateTime now, ReminderTone tone) {
    final messages = tone == ReminderTone.supportive ? _dailySupportive : _dailyDirect;
    return messages[_dayNumber(now) % messages.length];
  }

  static ReminderMessage forTask(Task task, DateTime now, {ReminderTone tone = ReminderTone.supportive}) {
    final dueAt = task.dueAt!.toLocal();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dueDayStart = DateTime(dueAt.year, dueAt.month, dueAt.day);
    final isDateOnly = dueAt.hour == 0 && dueAt.minute == 0 && dueAt.second == 0;
    final isOverdue = dueDayStart.isBefore(dayStart) || (!isDateOnly && dueAt.isBefore(now));
    final urgency = isOverdue
        ? ReminderUrgency.overdue
        : (dueDayStart == dayStart ? ReminderUrgency.today : ReminderUrgency.upcoming);
    final pool = switch ((urgency, tone)) {
      (ReminderUrgency.overdue, ReminderTone.supportive) => _overdueSupportive,
      (ReminderUrgency.overdue, ReminderTone.direct) => _overdueDirect,
      (ReminderUrgency.today, ReminderTone.supportive) => _todaySupportive,
      (ReminderUrgency.today, ReminderTone.direct) => _todayDirect,
      (ReminderUrgency.upcoming, ReminderTone.supportive) => _upcomingSupportive,
      (ReminderUrgency.upcoming, ReminderTone.direct) => _upcomingDirect,
    };
    final index = (_dayNumber(now) + _stableTaskHash(task.id)) % pool.length;
    final title = switch (urgency) {
      ReminderUrgency.overdue => 'المعاد عدى — لسه نقدر نتصرف',
      ReminderUrgency.today => 'مهمة ليك النهارده',
      ReminderUrgency.upcoming => 'تذكير جاي في وقته',
    };
    return ReminderMessage(urgency: urgency, title: title, body: pool[index]);
  }

  static int _dayNumber(DateTime date) => DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(2000, 1, 1))
      .inDays;

  static int _stableTaskHash(String value) {
    var hash = 0;
    for (var i = 0; i < value.length; i++) {
      hash = (hash + value.codeUnitAt(i) * (i + 1)) & 0x7fffffff;
    }
    return hash;
  }
}
