import 'package:health/health.dart';

class HealthStepTotals {
  static Future<int> getTotalForRange(
    Health health,
    DateTime start,
    DateTime end,
  ) async {
    final total = await health.getTotalStepsInInterval(start, end);
    return total ?? 0;
  }

  static Future<Map<DateTime, int>> getDailyTotals(
    Health health,
    DateTime start,
    DateTime end,
  ) async {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final totals = <DateTime, int>{};

    for (var day = startDay;
        !day.isAfter(endDay);
        day = day.add(const Duration(days: 1))) {
      final nextDay = day.add(const Duration(days: 1));
      final rangeStart = day.isBefore(start) ? start : day;
      final rangeEnd = nextDay.isAfter(end) ? end : nextDay;

      if (!rangeEnd.isAfter(rangeStart)) continue;

      final total = await getTotalForRange(health, rangeStart, rangeEnd);
      if (total > 0) {
        totals[day] = total;
      }
    }

    return totals;
  }
}
