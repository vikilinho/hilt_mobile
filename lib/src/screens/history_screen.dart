import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hilt_core/hilt_core.dart';
import '../workout_manager.dart';
import '../widgets/history_summary.dart';
import '../widgets/history_item_card.dart';
import 'post_workout_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WorkoutManager>();
    final sessions = manager.history;

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "No workouts yet",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
          ],
        ),
      );
    }

    final grouped = _groupSessions(sessions);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: HistorySummary(sessions: sessions),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = grouped[index];
                  if (entry is String) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
                      child: Text(
                        entry.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500,
                              letterSpacing: 1.2,
                            ),
                      ),
                    );
                  } else if (entry is WorkoutSession) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0), // 8px Gap
                      child: HistoryItemCard(
                        session: entry,
                        onDismissed: () => manager.deleteSession(entry.id),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PostWorkoutSummaryScreen(
                                session: entry,
                                isFromHistory: true,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                childCount: grouped.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _groupSessions(List<WorkoutSession> sessions) {
    final List<dynamic> items = [];
    final now = DateTime.now();
    String? lastLabel;

    for (var s in sessions) {
      final label = _getDateLabel(now, s.timestamp);
      if (label != lastLabel) {
        items.add(label);
        lastLabel = label;
      }
      items.add(s);
    }
    return items;
  }

  String _getDateLabel(DateTime now, DateTime date) {
    final diff = now.difference(date).inDays;
    final isSameDay =
        now.year == date.year && now.month == date.month && now.day == date.day;

    if (isSameDay) return "Today";

    // Check for yesterday (handle month boundaries roughly or use specific logic)
    // Simple check:
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == date.year &&
        yesterday.month == date.month &&
        yesterday.day == date.day;

    if (isYesterday) return "Yesterday";

    if (diff < 7) return "This Week";
    if (diff < 30) return "This Month";

    return "Older";
  }
}
