/// أدوات تنسيق الأرقام والتواريخ بالعربية والإنجليزية لتطابق وضع اللغة الحالي.
class ArabicFormatters {
  ArabicFormatters._();

  /// يتم تحديثه تلقائيًا من [HandelhaApp] عند تغيير اللغة إلى الإنجليزية.
  static bool useEnglish = false;

  static const List<String> _arabicDigits = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
  ];

  static const List<String> _arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static const List<String> _englishMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const Map<String, String> _commonTranslations = {
    'صديقي': 'Friend',
    'ترتيب جدول الأسبوع': 'Weekly Schedule Planning',
    'تحضير عرض العمل': 'Work Presentation Prep',
    'تنظيم مذاكرة الامتحانات': 'Exam Study Plan',
    'جلسة تركيز هادئة': 'Calm Focus Session',
  };

  /// يترجم النصوص الشائعة تلقائيًا عند تفعيل الوضع الإنجليزي.
  static String trData(String text) {
    if (!useEnglish || text.isEmpty) return text;
    final direct = _commonTranslations[text.trim()];
    if (direct != null) return direct;
    var out = text;
    for (final entry in _commonTranslations.entries) {
      if (out.contains(entry.key)) {
        out = out.replaceAll(entry.key, entry.value);
      }
    }
    return out;
  }

  /// يحوّل الأرقام الإنجليزية (0-9) إلى أرقام عربية هندية (٠-٩) في الوضع العربي،
  /// ويبقيها (0-9) في الوضع الإنجليزي.
  static String toArabicDigits(Object value) {
    final raw = value.toString();
    if (useEnglish) return raw;
    final buffer = StringBuffer();
    for (final code in raw.runes) {
      if (code >= 48 && code <= 57) {
        buffer.write(_arabicDigits[code - 48]);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  static String percent(num value) =>
      useEnglish ? '${value.round()}%' : '${toArabicDigits(value.round())}٪';

  static String countOf(int completed, int total) => useEnglish
      ? '$completed of $total tasks'
      : '${toArabicDigits(completed)} من ${toArabicDigits(total)} مهام';

  static String durationMinutes(int minutes) =>
      useEnglish ? '${minutes}m' : '${toArabicDigits(minutes)} د';

  static String durationMinutesFull(int minutes) =>
      useEnglish ? '$minutes min' : '${toArabicDigits(minutes)} دقيقة';

  static String timeOfDayAr(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    if (useEnglish) {
      final suffix = dt.hour < 12 ? 'AM' : 'PM';
      return '$hour12:$minute $suffix';
    }
    final suffix = dt.hour < 12 ? 'ص' : 'م';
    return '${toArabicDigits('$hour12:$minute')} $suffix';
  }

  static String dateShort(DateTime dt) {
    if (useEnglish) {
      final month = _englishMonths[(dt.month - 1).clamp(0, 11)];
      return '$month ${dt.day}';
    }
    final month = _arabicMonths[(dt.month - 1).clamp(0, 11)];
    return '${toArabicDigits(dt.day)} $month';
  }

  static String dateFull(DateTime dt) {
    if (useEnglish) {
      final month = _englishMonths[(dt.month - 1).clamp(0, 11)];
      return '$month ${dt.day}, ${dt.year}';
    }
    final month = _arabicMonths[(dt.month - 1).clamp(0, 11)];
    return '${toArabicDigits(dt.day)} $month ${toArabicDigits(dt.year)}';
  }

  static String weekdayShort(DateTime dt) {
    if (useEnglish) {
      switch (dt.weekday) {
        case DateTime.saturday:
          return 'Saturday';
        case DateTime.sunday:
          return 'Sunday';
        case DateTime.monday:
          return 'Monday';
        case DateTime.tuesday:
          return 'Tuesday';
        case DateTime.wednesday:
          return 'Wednesday';
        case DateTime.thursday:
          return 'Thursday';
        case DateTime.friday:
          return 'Friday';
        default:
          return '';
      }
    }
    switch (dt.weekday) {
      case DateTime.saturday:
        return 'السبت';
      case DateTime.sunday:
        return 'الأحد';
      case DateTime.monday:
        return 'الإثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      default:
        return '';
    }
  }

  static String monthName(int month) => useEnglish
      ? _englishMonths[(month - 1).clamp(0, 11)]
      : _arabicMonths[(month - 1).clamp(0, 11)];

  static String durationCompact(int totalMinutes) {
    final safe = totalMinutes < 0 ? 0 : totalMinutes;
    if (safe < 60) return durationMinutes(safe);
    final hours = safe ~/ 60;
    final rem = safe % 60;
    if (useEnglish) {
      if (rem == 0) return '${hours}h';
      return '${hours}h ${rem}m';
    }
    if (rem == 0) return '${toArabicDigits(hours)} س';
    return '${toArabicDigits(hours)} س ${toArabicDigits(rem)} د';
  }

  /// تنسيق عداد جلسة التركيز (MM:SS) بالأرقام القياسية كما في مرجع التصميم.
  static String timerMmSs(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = (safe ~/ 60).toString().padLeft(2, '0');
    final seconds = (safe % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
