import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hilt_core/hilt_core.dart';

class HistoryItemCard extends StatelessWidget {
  final WorkoutSession session;
  final VoidCallback onDismissed;
  final VoidCallback? onTap;

  const HistoryItemCard({
    super.key,
    required this.session,
    required this.onDismissed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradeColor = _getGradeColor(session.grade);
    final isStrength = _isStrengthSession(session);
    final categoryColor = isStrength
        ? Colors.blue
        : const Color(0xFF00E676); // Electric Blue or Neon Green

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 4), // Adjusted vertical margin
        clipBehavior: Clip.antiAlias, // Ensure neat corners with accent bar
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05), // Subtle opacity
              blurRadius: 4, // 4px blur
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent Bar
              Container(
                width: 5,
                color: gradeColor,
              ),
              // Main Content
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding:
                        const EdgeInsets.all(12.0), // 12px Internal Padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: categoryColor,
                                borderRadius:
                                    BorderRadius.circular(4), // 4px Radius
                              ),
                              alignment: Alignment.center, // Center text
                              child: Text(
                                _deriveSessionLabel(session),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold, // Bold
                                  color: Colors.white, // White text
                                  letterSpacing: 1.0,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Stats Row (Grade + Data)
                        Row(
                          children: [
                            // Grade Badge
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: gradeColor, width: 3),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                session.grade ?? '-',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: gradeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Data Stats
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment
                                    .spaceAround, // Distribute evenly
                                children: [
                                  _buildStat(context, "AVG BPM",
                                      _sanitizeBpm(session.averageBpm)),
                                  _buildStat(context, "PEAK",
                                      "${_sanitizeInt(session.peakBpm)}"),
                                  _buildStat(
                                      context,
                                      "IN ZONE",
                                      _formatDuration(
                                          session.timeInTargetZone)),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Footer: Timestamp
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _formatTimestamp(session.timestamp),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800, // Bold
                fontSize: 16,
              ),
        ),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Colors.grey.shade500, fontSize: 9),
        ),
      ],
    );
  }

  bool _isStrengthSession(WorkoutSession session) {
    if (session.peakStrengthScore != null && session.peakStrengthScore! > 0) {
      return true;
    }
    return false;
  }

  String _deriveSessionLabel(WorkoutSession session) {
    // 1. If we have a Strength Score, it was a Strength Session
    if (_isStrengthSession(session)) {
      return "STRENGTH";
    }

    // 2. Otherwise map SportType to meaningful labels
    switch (session.sportType) {
      case SportType.cycling:
        return "CYCLING";
      case SportType.boxing:
        return "BOXING";
      case SportType.custom:
        return "TRAINING";
      case SportType.football:
      default:
        // User requested "Cardio" for non-strength
        return "CARDIO";
    }
  }

  String _sanitizeBpm(double val) {
    if (val.isNaN || val.isInfinite || val > 300 || val < 0) return "-";
    return "${val.round()}";
  }

  int _sanitizeInt(int val) {
    if (val > 300 || val < 0) return 0;
    return val;
  }

  String _formatDuration(int seconds) {
    if (seconds > 86400 || seconds < 0) return "-"; // Sanity check
    final info = Duration(seconds: seconds);
    if (info.inMinutes > 60) {
      return "${info.inHours}h ${info.inMinutes % 60}m";
    }
    return "${info.inMinutes}m ${info.inSeconds % 60}s";
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final isToday = now.year == timestamp.year &&
        now.month == timestamp.month &&
        now.day == timestamp.day;

    if (isToday) {
      return DateFormat.jm().format(timestamp);
    } else {
      return DateFormat.MMMd().format(timestamp);
    }
  }

  Color _getGradeColor(String? grade) {
    if (grade == 'A') return const Color(0xFF00E676); // Neon Green
    if (grade == 'B') return Colors.amber; // Gold
    if (grade == 'C') return Colors.deepOrange; // Orange
    return Colors.grey; // Default/Null
  }
}
