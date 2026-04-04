import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:provider/provider.dart';
import 'package:hilt_mobile/src/workout_manager.dart';
import 'package:hilt_mobile/src/screens/post_workout_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Minimal WorkoutManager stub
//
// Extends ChangeNotifier directly so that context.watch<WorkoutManager>()
// works correctly (Provider requires a real ChangeNotifier, not a Mock).
// ─────────────────────────────────────────────────────────────────────────────
class _StubWorkoutManager extends ChangeNotifier implements WorkoutManager {
  @override
  SportProfile get profile => const SportProfile(
        type: SportType.football,
        workDuration: 20,
        restDuration: 30,
        targetHeartRate: 150,
        displayName: 'Football',
      );

  @override
  Future<void> updatePeakBpm(int sessionId, int bpm) async {}

  @override
  Future<void> saveSessionToDatabase(WorkoutSession session) async {}

  // All other WorkoutManager members are not exercised by these tests.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─────────────────────────────────────────────────────────────────────────────
// Session factory
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a [WorkoutSession] that will reach grade **A** once a BPM ≥ 150 is
/// submitted via the camera screen.
///
/// Grading logic in [_onManualBpmReceived]:
///   ratio = timeInTargetZone / durationSeconds = 45 / 60 = 0.75 ≥ 0.7
///   bpm ≥ 150  →  grade = 'A'
WorkoutSession _buildSession({
  int peakBpm = 0,
  String grade = 'C',
}) {
  return WorkoutSession()
    ..timestamp = DateTime(2026, 4, 4)
    ..sportType = SportType.football
    ..heartRateReadings = List.filled(60, 120) // populate chart
    ..averageBpm = 120.0
    ..peakBpm = peakBpm
    ..timeInTargetZone = 45 // 45/60 = 0.75 ≥ 0.7 → enables A grade
    ..grade = grade
    ..durationSeconds = 60;
}

/// Wraps [PostWorkoutSummaryScreen] with the required [WorkoutManager] provider.
Widget _buildApp(
  WorkoutSession session, {
  WidgetBuilder? cameraScreenBuilder,
}) {
  final manager = _StubWorkoutManager();
  return ChangeNotifierProvider<WorkoutManager>.value(
    value: manager,
    child: MaterialApp(
      home: PostWorkoutSummaryScreen(
        session: session,
        cameraScreenBuilder: cameraScreenBuilder,
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async => 1,
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Integration: peakBpm = 0 default prevents LateInitializationError
  // ───────────────────────────────────────────────────────────────────────────
  group('Integration: peakBpm = 0 default prevents LateInitializationError',
      () {
    testWidgets(
        'PostWorkoutSummaryScreen renders without crash when peakBpm = 0',
        (tester) async {
      // A WorkoutSession with peakBpm = 0 must not raise a
      // LateInitializationError — verifying the field is initialized to 0,
      // not declared as `late int`.
      final session = _buildSession(peakBpm: 0, grade: 'C');

      // If a LateInitializationError were thrown, pumpWidget would throw.
      await tester.pumpWidget(_buildApp(session));
      await tester.pump();

      // Screen must render the grade badge
      expect(find.text('C'), findsOneWidget,
          reason: 'Grade badge should display "C"');

      // The MEASURE MANUALLY button must be visible (peakBpm == 0)
      expect(find.textContaining('NO WATCH?'), findsOneWidget,
          reason: 'Manual measure button must appear when peakBpm == 0');
    });

    testWidgets(
        'PEAK BPM stat cell shows "0" initially (not a runtime error)',
        (tester) async {
      final session = _buildSession(peakBpm: 0, grade: 'C');
      await tester.pumpWidget(_buildApp(session));
      await tester.pump();

      // The tactical grid renders "0" for the PEAK BPM cell — no exception.
      expect(find.text('PEAK BPM'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'No exception should occur when reading peakBpm = 0');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Widget: Grade recalculates immediately when BPM is returned
  // ───────────────────────────────────────────────────────────────────────────
  group('Post-workout grade recalculation', () {
    testWidgets('Grade upgrades C → A when camera screen returns 170 BPM',
        (tester) async {
      final session = _buildSession(peakBpm: 0, grade: 'C');

      // A fake "camera screen" that immediately returns 170 via pop().
      // This simulates the user completing a real measurement without
      // requiring a physical camera or the heart_bpm plugin.
      Widget fakeCameraBuilder(BuildContext ctx) {
        return Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(170);
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        });
      }

      await tester.pumpWidget(
        _buildApp(session, cameraScreenBuilder: fakeCameraBuilder),
      );
      await tester.pump();

      // Initial state: grade is C, A badge not visible
      expect(find.text('C'), findsOneWidget, reason: 'Initial grade must be C');
      expect(find.text('A'), findsNothing, reason: 'A badge must not appear yet');

      // Tap the "MEASURE MANUALLY" button to trigger navigation
      final measureBtnFinder = find.ancestor(
        of: find.textContaining('NO WATCH?'),
        matching: find.byType(OutlinedButton),
      );
      expect(measureBtnFinder, findsOneWidget);
      await tester.tap(measureBtnFinder);

      // pumpAndSettle:
      //   1. Pushes the fake camera screen
      //   2. Post-frame callback fires, Navigator.pop(170) is called
      //   3. PostWorkoutSummaryScreen receives 170 / calls _onManualBpmReceived
      //   4. setState rebuilds the tree with grade = 'A'
      await tester.pumpAndSettle();

      // Grade badge must now display 'A'
      expect(find.text('A'), findsOneWidget,
          reason:
              'Grade must upgrade to A (ratio=0.75≥0.7 AND bpm=170≥150)');
      expect(find.text('C'), findsNothing,
          reason: 'Old C grade badge must be gone after recalculation');
    });

    testWidgets('Grade upgrades C → B when BPM is 135 (high BPM, low ratio)',
        (tester) async {
      // ratio = 45/60 = 0.75 ≥ 0.7, but bpm = 135 < 150 → second branch:
      // ratio >= 0.4 || bpm >= 130 → 'B'
      final session = _buildSession(peakBpm: 0, grade: 'C');

      Widget fakeCameraBuilder(BuildContext ctx) {
        return Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(135);
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        });
      }

      await tester.pumpWidget(
        _buildApp(session, cameraScreenBuilder: fakeCameraBuilder),
      );
      await tester.pump();

      final measureBtnFinder = find.ancestor(
        of: find.textContaining('NO WATCH?'),
        matching: find.byType(OutlinedButton),
      );
      await tester.tap(measureBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('B'), findsOneWidget,
          reason: 'BPM=135 ≥ 130 → second grading branch → B');
      expect(find.text('C'), findsNothing);
    });

    testWidgets('Grade stays C when BPM is 100 (low BPM, low ratio)',
        (tester) async {
      // For a C-grade result we need low ratio AND low BPM.
      // Force a session where timeInTargetZone = 5 / durationSeconds = 60
      // → ratio = 0.083, and bpm = 100 < 130.
      final session = WorkoutSession()
        ..timestamp = DateTime(2026, 4, 4)
        ..sportType = SportType.football
        ..heartRateReadings = List.filled(60, 100)
        ..averageBpm = 100.0
        ..peakBpm = 0
        ..timeInTargetZone = 5 // 5/60 = 0.083 < 0.4
        ..grade = 'C'
        ..durationSeconds = 60;

      Widget fakeCameraBuilder(BuildContext ctx) {
        return Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(100); // below 130 threshold
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        });
      }

      await tester.pumpWidget(
        _buildApp(session, cameraScreenBuilder: fakeCameraBuilder),
      );
      await tester.pump();

      final measureBtnFinder = find.ancestor(
        of: find.textContaining('NO WATCH?'),
        matching: find.byType(OutlinedButton),
      );
      await tester.tap(measureBtnFinder);
      await tester.pumpAndSettle();

      // Grade remains C
      expect(find.text('C'), findsOneWidget,
          reason: 'Low BPM + low ratio must keep grade at C');
    });

    testWidgets('MEASURE MANUALLY button disappears after BPM is captured',
        (tester) async {
      final session = _buildSession(peakBpm: 0, grade: 'C');

      Widget fakeCameraBuilder(BuildContext ctx) {
        return Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop(170);
          });
          return const Scaffold(body: SizedBox.shrink());
        });
      }

      await tester.pumpWidget(
        _buildApp(session, cameraScreenBuilder: fakeCameraBuilder),
      );
      await tester.pump();

      // Button visible initially (peakBpm == 0)
      expect(find.textContaining('NO WATCH?'), findsOneWidget);

      final measureBtnFinder = find.ancestor(
        of: find.textContaining('NO WATCH?'),
        matching: find.byType(OutlinedButton),
      );
      await tester.tap(measureBtnFinder);
      await tester.pumpAndSettle();

      // After capturing 170 BPM: peakBpm > 0 → button condition is false →
      // the OutlinedButton is removed from the tree entirely.
      expect(find.textContaining('NO WATCH?'), findsNothing,
          reason:
              'MEASURE MANUALLY button must be hidden once peakBpm > 0');
      // Session object was mutated correctly
      expect(session.peakBpm, 170,
          reason: 'Session peakBpm must be updated to 170');
    });
  });
}
