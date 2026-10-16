/// The "current time" supplied by the application, parsed as a wall clock.
///
/// The ISO string carries Cairo's UTC offset (+02:00 or +03:00 depending on
/// DST). We deliberately keep the wall-clock fields exactly as written and
/// never convert to the device timezone.
class WallClock {
  WallClock._(this.wall, this.offset);

  /// UTC-flagged DateTime whose fields equal the local wall-clock fields.
  final DateTime wall;

  /// e.g. "+03:00" (may be empty if the app sent no offset).
  final String offset;

  static final _re = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?$');

  static WallClock? tryParse(String? iso) {
    if (iso == null) return null;
    final m = _re.firstMatch(iso.trim());
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final h = int.parse(m.group(4)!);
    final mi = int.parse(m.group(5)!);
    final s = m.group(6) == null ? 0 : int.parse(m.group(6)!);
    final dt = DateTime.utc(y, mo, d, h, mi, s);
    if (dt.year != y || dt.month != mo || dt.day != d || dt.hour != h || dt.minute != mi) {
      return null;
    }
    var off = m.group(7) ?? '';
    if (off == 'Z') {
      off = '+00:00';
    } else if (off.length == 5) {
      off = '${off.substring(0, 3)}:${off.substring(3)}';
    }
    return WallClock._(dt, off);
  }

  String get date => ymd(wall);
  String get time => '${_two(wall.hour)}:${_two(wall.minute)}';
  int get weekday => wall.weekday; // Mon=1 .. Sun=7
  String dateAfter(int days) => ymd(wall.add(Duration(days: days)));
  DateTime dayAfter(int days) => wall.add(Duration(days: days));

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Convenience for apps: ISO string from the device clock with its offset.
  /// (If the device is not in Cairo time, pass your own Cairo time instead.)
  static String deviceNowIso([DateTime? now]) {
    final t = now ?? DateTime.now();
    final off = t.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final a = off.abs();
    return '${ymd(t)}T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}'
        '$sign${_two(a.inHours)}:${_two(a.inMinutes % 60)}';
  }
}
