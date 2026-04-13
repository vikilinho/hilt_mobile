import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:intl/intl.dart';
import '../workout_manager.dart';
import '../widgets/history_summary.dart';
import '../widgets/history_item_card.dart';
import 'post_workout_screen.dart';
import 'step_detail_view.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedTab = 0; // 0 = SESSIONS, 1 = WALKS

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WorkoutManager>();
    final allSessions = manager.history;

    // Split History
    final workoutSessions = allSessions
        .where((s) => !(s.comboNames?.contains('Daily Steps') ?? false))
        .toList();
    final walkSessions = allSessions
        .where((s) => s.comboNames?.contains('Daily Steps') ?? false)
        .toList();

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildSegmentedControl(context),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _selectedTab == 0
                  ? _buildSessionsView(context, manager, workoutSessions)
                  : _buildWalksView(context, manager, walkSessions),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabButton("SESSIONS", 0, theme)),
          Expanded(child: _buildTabButton("WALKS", 1, theme)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index, ThemeData theme) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (_selectedTab != index) setState(() => _selectedTab = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00897B) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Center(
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsView(BuildContext context, WorkoutManager manager,
      List<WorkoutSession> sessions) {
    if (sessions.isEmpty) {
      return Center(
        key: const ValueKey('sessions_empty'),
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

    return CustomScrollView(
      key: const ValueKey('sessions_view'),
      slivers: [
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
                    padding: const EdgeInsets.only(bottom: 8.0),
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
    );
  }

  Widget _buildWalksView(BuildContext context, WorkoutManager manager,
      List<WorkoutSession> sessions) {
    if (sessions.isEmpty) {
      return Center(
        key: const ValueKey('walks_empty'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_walk, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "No walks recorded",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey('walks_view'),
      padding: const EdgeInsets.only(top: 8, bottom: 24, left: 16, right: 16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final entry = sessions[index];
        final steps = entry.steps ?? 0;

        return Dismissible(
          key: ValueKey('walk_\${entry.id}'),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => manager.deleteSession(entry.id),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child:
                const Icon(Icons.delete_outline, color: Colors.white, size: 30),
          ),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StepDetailView(session: entry),
                ),
              );
            },
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                  // Date Block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getWalkDateLabel(entry.timestamp),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMd().format(entry.timestamp),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),

                  // Steps Number
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        NumberFormat.decimalPattern().format(steps),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                      ),
                      Text(
                        "TOTAL STEPS",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey.shade500,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                      ),
                    ],
                  ),


                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  String _getWalkDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final aDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(aDate).inDays;

    if (diff == 0) return "Today";
    if (diff == 1) return "Yesterday";
    return DateFormat('EEEE').format(date); // e.g., "Monday"
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
