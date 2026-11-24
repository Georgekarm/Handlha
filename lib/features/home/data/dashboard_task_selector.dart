import '../../assistant/data/user_energy_preferences.dart';
import '../../tasks/domain/task.dart';

class HeroTaskSelection {
  const HeroTaskSelection({
    required this.task,
    required this.reasonAr,
    required this.reasonEn,
    required this.matchedByEnergy,
  });

  final Task task;
  final String reasonAr;
  final String reasonEn;
  final bool matchedByEnergy;
}

/// Transparent, deterministic hero-task ranking for the Home Dashboard.
///
/// Ranks open tasks using priority/urgency AND the user's configured
/// [UserEnergyPreferences] (`peakEnergyPeriod` + `hardTaskStrategy`) relative
/// to the current hour, returning an explicit human-readable reason.
class DashboardTaskSelector {
  const DashboardTaskSelector._();

  static bool isInPeakWindow(UserEnergyPreferences prefs, DateTime now) {
    final minuteOfDay = now.hour * 60 + now.minute;
    return minuteOfDay >= prefs.workStartMinute &&
        minuteOfDay < prefs.workEndMinute;
  }

  static EnergyLevel targetEnergyForNow(
    UserEnergyPreferences prefs,
    DateTime now,
  ) {
    final inPeak = isInPeakWindow(prefs, now);
    if (inPeak) {
      return prefs.hardTaskStrategy == 'warmup_first'
          ? EnergyLevel.low
          : EnergyLevel.high;
    }
    // Outside peak window: prefer lighter or medium tasks so the user starts calmly.
    return EnergyLevel.low;
  }

  static List<Task> rankOpenTasks(
    List<Task> openTasks,
    UserEnergyPreferences prefs,
    DateTime now,
  ) {
    if (openTasks.length <= 1) return List<Task>.from(openTasks);
    final targetEnergy = targetEnergyForNow(prefs, now);
    final inPeak = isInPeakWindow(prefs, now);

    int score(Task t) {
      var s = switch (t.priority) {
        TaskPriority.urgent => 40,
        TaskPriority.high => 26,
        TaskPriority.medium => 14,
        TaskPriority.low => 6,
      };

      // Imminent or overdue deadlines always rise to the top.
      final due = t.scheduledStartAt ?? t.dueAt;
      if (due != null) {
        final diffMins = due.difference(now).inMinutes;
        if (diffMins <= 0) {
          s += 30;
        } else if (diffMins <= 120) {
          s += 18;
        }
      }

      // Energy profile alignment.
      if (t.energyLevel == targetEnergy) {
        s += 22;
      } else if (t.energyLevel == EnergyLevel.medium) {
        s += 10;
      } else if (!inPeak && t.energyLevel == EnergyLevel.high) {
        s -= 8;
      }

      return s;
    }

    final ranked = List<Task>.from(openTasks)
      ..sort((a, b) {
        final cmp = score(b).compareTo(score(a));
        if (cmp != 0) return cmp;
        final da = a.scheduledStartAt ?? a.dueAt ?? a.createdAt;
        final db = b.scheduledStartAt ?? b.dueAt ?? b.createdAt;
        return da.compareTo(db);
      });
    return ranked;
  }

  static HeroTaskSelection? pickHeroTask(
    List<Task> openTasks,
    UserEnergyPreferences prefs,
    DateTime now,
  ) {
    if (openTasks.isEmpty) return null;
    final ranked = rankOpenTasks(openTasks, prefs, now);
    final chosen = ranked.first;
    final inPeak = isInPeakWindow(prefs, now);
    final targetEnergy = targetEnergyForNow(prefs, now);

    if (chosen.energyLevel == targetEnergy) {
      if (inPeak && prefs.hardTaskStrategy == 'warmup_first') {
        return HeroTaskSelection(
          task: chosen,
          reasonAr: 'مختارة كخطوة تسخين خفيفة حسب أسلوبك',
          reasonEn: 'Picked as a light warm-up matching your strategy',
          matchedByEnergy: true,
        );
      }
      if (inPeak) {
        return HeroTaskSelection(
          task: chosen,
          reasonAr: 'مناسبة لذروة طاقتك الآن (${prefs.peakShortAr})',
          reasonEn: 'Matches your peak energy window (${prefs.peakShortEn})',
          matchedByEnergy: true,
        );
      }
      return HeroTaskSelection(
        task: chosen,
        reasonAr: 'مهمة خفيفة مناسبة لوقتك خارج ذروة الطاقة',
        reasonEn: 'Light task suited for outside your peak window',
        matchedByEnergy: true,
      );
    }

    return HeroTaskSelection(
      task: chosen,
      reasonAr: 'مختارة كأعلى أولوية وموعد أقرب دلوقتي',
      reasonEn: 'Picked by highest priority & nearest schedule',
      matchedByEnergy: false,
    );
  }
}
