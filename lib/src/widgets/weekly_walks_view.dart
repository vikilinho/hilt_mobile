import 'package:flutter/material.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:intl/intl.dart';

import '../screens/step_detail_view.dart';

class WeeklyWalksView extends StatelessWidget {
  final List<WorkoutSession> sessions;
  final ValueChanged<int> onDeleteSession;
  final DateTime? now;

  const WeeklyWalksView({
    super.key,
    required this.sessions,
    required this.onDeleteSession,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final referenceDate = _normalizeDate(now ?? DateTime.now());
    final weeks = _groupSessionsByWeek(sessions);

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 24, left: 16, right: 16),
      itemCount: weeks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final week = weeks[index];
        return _WeekCard(
          week: week,
          now: referenceDate,
          onDeleteSession: onDeleteSession,
        );
      },
    );
  }
}

class _WeekCard extends StatelessWidget {
  final _WalkWeekGroup week;
  final DateTime now;
  final ValueChanged<int> onDeleteSession;

  const _WeekCard({
    required this.week,
    required this.now,
    required this.onDeleteSession,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<int>(week.weekStart.millisecondsSinceEpoch),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.calendar_view_week_rounded,
              color: Color(0xFF00897B),
            ),
          ),
          title: Text(
            _getWeekLabel(week.weekStart, now),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _formatWeekRange(week.weekStart, week.weekEnd),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.decimalPattern().format(week.totalSteps),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF00897B),
                ),
              ),
              Text(
                'TOTAL',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade500,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          children: [
            _WeekSummaryRow(week: week),
            const SizedBox(height: 16),
            _WeekStatusRow(
              missingPastDays: week.missingPastDays(now),
              futureDays: week.futureDays(now),
            ),
            if (week.sessions.isNotEmpty) const SizedBox(height: 12),
            for (var i = 0; i < week.sessions.length; i++) ...[
              _buildDayTile(context, week.sessions[i]),
              if (i < week.sessions.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDayTile(BuildContext context, WorkoutSession session) {
    final day = _normalizeDate(session.timestamp);
    final steps = session.steps ?? 0;
    final miles = session.distance ?? (steps * 0.00047);
    final calories = session.calories ?? (steps * 0.04);
    final isMatchReady = steps >= 10000;

    final card = InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StepDetailView(session: session),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isMatchReady
                ? const Color(0xFF00897B).withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE').format(day),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isMatchReady
                              ? const Color(0xFF00897B)
                              : Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.yMMMd().format(day),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${miles.toStringAsFixed(1)} miles  •  ${calories.toStringAsFixed(0)} cal',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat.decimalPattern().format(steps),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isMatchReady
                            ? const Color(0xFF00897B)
                            : Colors.black87,
                      ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'STEPS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey.shade500,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      key: ValueKey('delete_walk_day_${session.id}'),
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => onDeleteSession(session.id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('walk_day_${session.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDeleteSession(session.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: card,
    );
  }
}

class _WeekStatusRow extends StatelessWidget {
  final int missingPastDays;
  final int futureDays;

  const _WeekStatusRow({
    required this.missingPastDays,
    required this.futureDays,
  });

  @override
  Widget build(BuildContext context) {
    if (missingPastDays == 0 && futureDays == 0) {
      return const SizedBox.shrink();
    }

    final messages = <String>[
      if (missingPastDays > 0)
        '$missingPastDays ${missingPastDays == 1 ? 'day' : 'days'} without walks',
      if (futureDays > 0)
        '$futureDays ${futureDays == 1 ? 'day' : 'days'} remaining this week',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        messages.join(' • '),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _WeekSummaryRow extends StatelessWidget {
  final _WalkWeekGroup week;

  const _WeekSummaryRow({required this.week});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FBFA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryStat(
            label: 'Active Days',
            value: '${week.activeDays}',
          ),
          _SummaryStat(
            label: 'Avg / Active Day',
            value: NumberFormat.decimalPattern().format(week.averageSteps),
          ),
          _SummaryStat(
            label: '10K Days',
            value: '${week.goalDays}',
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _WalkWeekGroup {
  final DateTime weekStart;
  final List<WorkoutSession> sessions;

  const _WalkWeekGroup({
    required this.weekStart,
    required this.sessions,
  });

  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  int get totalSteps => sessions.fold<int>(
        0,
        (total, session) => total + (session.steps ?? 0),
      );

  int get activeDays => sessions.length;

  int get averageSteps =>
      activeDays == 0 ? 0 : (totalSteps / activeDays).round();

  int get goalDays =>
      sessions.where((session) => (session.steps ?? 0) >= 10000).length;

  int missingPastDays(DateTime now) {
    final today = _normalizeDate(now);
    if (today.isBefore(weekStart)) return 0;

    final pastWindowEnd = today.isBefore(weekEnd) ? today : weekEnd;
    final totalPastDays = pastWindowEnd.difference(weekStart).inDays + 1;
    return totalPastDays - sessions.length;
  }

  int futureDays(DateTime now) {
    final today = _normalizeDate(now);
    if (!today.isBefore(weekEnd)) return 0;

    final futureStart = today.add(const Duration(days: 1));
    if (futureStart.isAfter(weekEnd)) return 0;
    return weekEnd.difference(futureStart).inDays + 1;
  }
}

List<_WalkWeekGroup> _groupSessionsByWeek(List<WorkoutSession> sessions) {
  final sortedSessions = sessions.toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  final grouped = <DateTime, List<WorkoutSession>>{};

  for (final session in sortedSessions) {
    final weekStart = _startOfWeek(session.timestamp);
    grouped.putIfAbsent(weekStart, () => []).add(session);
  }

  final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final key in keys)
      _WalkWeekGroup(
        weekStart: key,
        sessions: grouped[key]!
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
      ),
  ];
}

DateTime _startOfWeek(DateTime date) {
  final normalized = _normalizeDate(date);
  return normalized
      .subtract(Duration(days: normalized.weekday - DateTime.monday));
}

DateTime _normalizeDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

String _getWeekLabel(DateTime weekStart, DateTime now) {
  final nowWeekStart = _startOfWeek(now);
  final diffInWeeks = nowWeekStart.difference(weekStart).inDays ~/ 7;

  if (diffInWeeks == 0) return 'This Week';
  if (diffInWeeks == 1) return 'Last Week';
  return 'Week of ${DateFormat.MMMd().format(weekStart)}';
}

String _formatWeekRange(DateTime start, DateTime end) {
  final sameMonth = start.month == end.month && start.year == end.year;
  if (sameMonth) {
    return '${DateFormat.MMMd().format(start)} - ${DateFormat.d().format(end)}';
  }
  if (start.year == end.year) {
    return '${DateFormat.MMMd().format(start)} - ${DateFormat.MMMd().format(end)}';
  }
  return '${DateFormat.yMMMd().format(start)} - ${DateFormat.yMMMd().format(end)}';
}
