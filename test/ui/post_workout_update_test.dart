import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:provider/provider.dart';
import 'package:hilt_mobile/src/workout_manager.dart';
import 'package:hilt_mobile/src/screens/post_workout_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Minimal WorkoutManager stub
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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─────────────────────────────────────────────────────────────────────────────
// Session factory
// ─────────────────────────────────────────────────────────────────────────────
WorkoutSession _buildSession({
  int peakBpm = 0,
  String grade = 'C',
}) {
  return WorkoutSession()
    ..timestamp = DateTime(2026, 4, 4)
    ..sportType = SportType.football
    ..heartRateReadings = List.filled(60, 120)
    ..averageBpm = 120.0
    ..peakBpm = peakBpm
    ..timeInTargetZone = 45
    ..grade = grade
    ..durationSeconds = 60;
}

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
      final session = _buildSession(peakBpm: 0, grade: 'C');

      await tester.pumpWidget(_buildApp(session));
      await tester.pump();

      // Screen must render the grade badge
      expect(find.text('C'), findsOneWidget,
          reason: 'Grade badge should display "C"');

      // The 'PEAK BPM' Hero text must appear
      expect(find.text('PEAK BPM'), findsOneWidget,
          reason: 'PEAK BPM hero title should render.');
    });

    testWidgets(
        'ZONE stat cell appears',
        (tester) async {
      final session = _buildSession(peakBpm: 0, grade: 'C');
      await tester.pumpWidget(_buildApp(session));
      await tester.pump();

      expect(find.text('ZONE'), findsOneWidget);
      expect(find.text('WARMUP'), findsOneWidget); // PeakBpm 0 gives WARMUP
      expect(tester.takeException(), isNull,
          reason: 'No exception should occur when reading peakBpm = 0');
    });
  });
}
