import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:hilt_mobile/src/widgets/weekly_walks_view.dart';
import '../support/test_app.dart';

void main() {
  WorkoutSession buildWalkSession({
    required int id,
    required DateTime timestamp,
    required int steps,
  }) {
    return WorkoutSession()
      ..id = id
      ..timestamp = timestamp
      ..sportType = SportType.custom
      ..heartRateReadings = const []
      ..averageBpm = 0
      ..timeInTargetZone = 0
      ..steps = steps
      ..distance = steps * 0.00047
      ..calories = steps * 0.04
      ..comboNames = ['Daily Steps'];
  }

  group('WeeklyWalksView', () {
    testWidgets('groups walks into weeks and reveals daily stats on tap',
        (tester) async {
      final sessions = [
        buildWalkSession(
          id: 1,
          timestamp: DateTime(2026, 5, 5, 23, 59),
          steps: 8300,
        ),
        buildWalkSession(
          id: 2,
          timestamp: DateTime(2026, 5, 7, 23, 59),
          steps: 12400,
        ),
        buildWalkSession(
          id: 3,
          timestamp: DateTime(2026, 4, 29, 23, 59),
          steps: 9100,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: WeeklyWalksView(
              sessions: sessions,
              now: DateTime(2026, 5, 7),
              onDeleteSession: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ExpansionTile), findsNWidgets(2));

      expect(find.text('Thursday'), findsNothing);
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();

      expect(find.text('Thursday'), findsOneWidget);
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('Wednesday'), findsNothing);
      expect(
        find.text('2 days without walks • 3 days remaining this week'),
        findsOneWidget,
      );
    });

    testWidgets('opens the daily detail view from an expanded day row',
        (tester) async {
      final sessions = [
        buildWalkSession(
          id: 1,
          timestamp: DateTime(2026, 5, 7, 23, 59),
          steps: 12400,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: WeeklyWalksView(
              sessions: sessions,
              now: DateTime(2026, 5, 7),
              onDeleteSession: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thursday'));
      await tester.pumpAndSettle();

      expect(find.text('DAILY ACTIVITY'), findsOneWidget);
      expect(find.text('TOTAL STEPS'), findsOneWidget);
    });

    testWidgets('deletes a recorded day walk from the expanded week',
        (tester) async {
      int? deletedId;
      final sessions = [
        buildWalkSession(
          id: 7,
          timestamp: DateTime(2026, 5, 7, 23, 59),
          steps: 12400,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: WeeklyWalksView(
              sessions: sessions,
              now: DateTime(2026, 5, 7),
              onDeleteSession: (id) => deletedId = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete_walk_day_7')));
      await tester.pumpAndSettle();

      expect(deletedId, 7);
    });
  });
}
