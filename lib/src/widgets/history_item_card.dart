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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Background Chart (Subtle)
              Positioned.fill(
                child: Opacity(
                  opacity:
                      0.1, // Increased slightly for visibility if we change color
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: LineChart(
                      LineChartData(
                        lineTouchData: const LineTouchData(
                            enabled: false), // Disable interaction
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: session.heartRateReadings
                                .asMap()
                                .entries
                                .map((e) => FlSpot(
                                    e.key.toDouble(), e.value.toDouble()))
                                .toList(),
                            isCurved: true,
                            color: Colors.blueAccent, // Subtle BlueGrey
                            barWidth: 3,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.green,
                            ),
                          ),
                        ],
                        minY: 0,
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            session.sportType.name.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        Text(
                          _formatTimestamp(session.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Main Stats
                    Row(
                      children: [
                        // Grade Badge
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            // color: gradeColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: gradeColor, width: 4),
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

                        // Text Stats
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStat(context, "AVG BPM",
                                  "${session.averageBpm.round()}"),
                              _buildStat(context, "PEAK", "${session.peakBpm}"),
                              _buildStat(context, "IN ZONE",
                                  _formatDuration(session.timeInTargetZone)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
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

  String _formatDuration(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return "${m}m${s}s";
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
    if (grade == 'A') return const Color(0xFF4CAF50); // Green
    if (grade == 'B') return const Color(0xFFFFC107); // Amber
    return const Color(0xFFF44336); // Red
  }
}
