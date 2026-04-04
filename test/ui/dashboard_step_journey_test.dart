import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:hilt_mobile/src/services/step_service.dart';
import 'package:hilt_mobile/src/workout_manager.dart';

class MockWorkoutManager extends Mock implements WorkoutManager {}
class MockStepService extends Mock implements StepService {}

/// A standalone Step Journey Widget for testability.
/// Mirrors the logic from DashboardScreen for the Step Journey section.
class StepJourneyWidget extends StatelessWidget {
  final Stream<DailyActivity?> stream;
  final int goal;

  const StepJourneyWidget({super.key, required this.stream, required this.goal});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DailyActivity?>(
      stream: stream,
      builder: (context, snapshot) {
        final int liveSteps = snapshot.data?.totalSteps ?? 0;
        final bool matchReady = liveSteps >= goal;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double trackWidth = constraints.maxWidth;
              final double progressRaw = goal > 0 ? (liveSteps / goal) : 0;
              final double progress = progressRaw.clamp(0.0, 1.0);

              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  const double containerWidth = 100.0;
                  const double startLeft = -34.0;
                  final double endLeft = trackWidth - 66.0;
                  final double leftPos = startLeft + ((endLeft - startLeft) * value);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 65,
                        width: double.infinity,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Goal label
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Text(
                                '${goal >= 1000 ? '${(goal / 1000).toStringAsFixed(0)}K' : goal}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Track line
                            Positioned(
                              bottom: 24,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0E0E0),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // Athlete icon + step count
                            Positioned(
                              left: leftPos,
                              bottom: 0,
                              width: containerWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.directions_walk,
                                    size: 32,
                                    color: Color(0xFF00897B),
                                    key: Key('step_icon'),
                                  ),
                                  const SizedBox(height: 6),
                                  Opacity(
                                    opacity: value > 0.90
                                        ? (1.0 - ((value - 0.90) * 10.0)).clamp(0.0, 1.0)
                                        : 1.0,
                                    child: Text(
                                      '$liveSteps Steps',
                                      key: const Key('step_label'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF00897B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (matchReady)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('MATCH READY', key: Key('match_ready_banner')),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async => 1,
    );
  });

  group('Step Journey Dashboard Widget Tests', () {
    testWidgets('Shows 5000 Steps text when stream yields 5000 steps', (tester) async {
      final controller = StreamController<DailyActivity?>();

      final activity = DailyActivity()
        ..id = 20260404
        ..date = DateTime(2026, 4, 4)
        ..totalSteps = 5000
        ..miles = 2.4
        ..calories = 200;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: StepJourneyWidget(stream: controller.stream, goal: 10000),
            ),
          ),
        ),
      );

      controller.add(activity);
      await tester.pump(); // trigger StreamBuilder rebuild
      await tester.pump(const Duration(milliseconds: 350)); // let animation settle

      // Verify the teal walking icon is present
      expect(find.byKey(const Key('step_icon')), findsOneWidget);

      // Verify the step count text
      expect(find.text('5000 Steps'), findsOneWidget);

      // MATCH READY should NOT appear (5000 < 10000)
      expect(find.byKey(const Key('match_ready_banner')), findsNothing);

      await controller.close();
    });

    testWidgets('Icon is positioned at ~50% when steps = 50% of goal', (tester) async {
      const double trackWidthMinusPadding = 400.0 - 48.0; // 400 total - 24*2 padding

      final controller = StreamController<DailyActivity?>();

      final activity = DailyActivity()
        ..id = 20260404
        ..date = DateTime(2026, 4, 4)
        ..totalSteps = 5000
        ..miles = 2.4
        ..calories = 200;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: StepJourneyWidget(stream: controller.stream, goal: 10000),
            ),
          ),
        ),
      );

      controller.add(activity);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final iconFinder = find.byKey(const Key('step_icon'));
      expect(iconFinder, findsOneWidget);

      final iconBox = tester.getRect(iconFinder);
      final iconCenter = iconBox.center.dx;

      // At 50% progress: leftPos = startLeft + (endLeft - startLeft) * 0.5
      // startLeft = -34, endLeft = trackWidthMinusPadding - 66
      // containerWidth = 100, iconCenter within container = 50
      // So global center ≈ 24 (left padding) + leftPos + 50
      const double startLeft = -34.0;
      final double endLeft = trackWidthMinusPadding - 66.0;
      final double leftPos = startLeft + ((endLeft - startLeft) * 0.5);
      final double expectedCenter = 24.0 + leftPos + 50.0; // 24px padding + leftPos + half container

      // Allow ±5px tolerance for animation rounding
      expect(iconCenter, closeTo(expectedCenter, 5.0));

      await controller.close();
    });

    testWidgets('Shows MATCH READY when steps >= goal', (tester) async {
      final controller = StreamController<DailyActivity?>();

      final activity = DailyActivity()
        ..id = 20260404
        ..date = DateTime(2026, 4, 4)
        ..totalSteps = 10000
        ..miles = 4.7
        ..calories = 400;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: StepJourneyWidget(stream: controller.stream, goal: 10000),
            ),
          ),
        ),
      );

      controller.add(activity);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('match_ready_banner')), findsOneWidget);

      await controller.close();
    });
  });
}
