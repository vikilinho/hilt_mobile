import 'package:flutter/material.dart';
import 'package:hilt_core/hilt_core.dart';
import '../l10n/app_localizations.dart';

class HistorySummary extends StatelessWidget {
  final List<WorkoutSession> sessions;

  const HistorySummary({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();

    final totalWorkouts = sessions.length;
    // Calculate total duration roughly if not explicitly saved properly in all versions
    // Assuming each session might have duration, but currently only readings.
    // We can use readings count as seconds approximation or skip duration for now if unreliable.
    // Let's stick to Total Workouts and Grade Distribution for now.

    int gradeA = 0;
    int gradeB = 0;

    for (var s in sessions) {
      if (s.grade == 'A') {
        gradeA++;
      } else if (s.grade == 'B') {
        gradeB++;
      }
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4, // Increased elevation
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0), // Increased padding
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              context,
              context.l10n.text('workoutsLabel').toUpperCase(),
              "$totalWorkouts",
            ),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            _buildStatItem(context, context.l10n.text('bestGrade').toUpperCase(),
                gradeA > 0 ? "A" : (gradeB > 0 ? "B" : "C")),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            _buildStatItem(context, context.l10n.text('last').toUpperCase(),
                _getLastDate(context, sessions.first.timestamp)),
          ],
        ),
      ),
    );
  }

  String _getLastDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final aDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(aDate).inDays;

    if (diff == 0) return context.l10n.text('today');
    if (diff == 1) return context.l10n.text('yesterday');
    return context.l10n.daysAgo(diff);
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                // Increased size
                fontWeight: FontWeight.w900, // Extra Bold
                color: Colors.black87,
                fontSize: 28, // Explicit size increase
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF4A4A4A), // Tactile Dark Grey
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
