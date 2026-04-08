import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_mobile/src/screens/camera_bpm_screen.dart';
import 'package:hilt_mobile/src/services/bpm_filter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps [CameraBpmScreen.forTesting] in a minimal [MaterialApp].
Widget _buildScreen(Stream<int> stream) {
  return MaterialApp(
    home: CameraBpmScreen.forTesting(bpmStream: stream),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Stub the permission channel so _requestCamera() doesn't crash if called.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async => 1, // PermissionStatus.granted
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 1. Initial state
  // ───────────────────────────────────────────────────────────────────────────
  group('CameraBpmScreen — initial state', () {
    testWidgets('shows NO FINGER DETECTED cue before any data arrives',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      expect(find.text('NO FINGER DETECTED'), findsOneWidget);
      expect(find.text('COVER THE LENS WITH YOUR FINGER'), findsOneWidget);
      // BPM display shows placeholder
      expect(find.text('--'), findsOneWidget);

      await controller.close();
    });

    testWidgets('LOCK IN button is present in tree but disabled initially',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      final lockBtn = tester.widget<FilledButton>(
        find.widgetWithIcon(FilledButton, Icons.lock_outline),
      );
      // onPressed must be null (disabled) — not just hidden via AnimatedOpacity
      expect(lockBtn.onPressed, isNull);

      await controller.close();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Finger detection
  // ───────────────────────────────────────────────────────────────────────────
  group('CameraBpmScreen — finger detection cue', () {
    testWidgets(
        'physiological BPM (40–220) transitions cue to FINGER DETECTED ✓',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      expect(find.text('NO FINGER DETECTED'), findsOneWidget);

      controller.add(72); // valid physiological BPM
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350)); // AnimatedSwitcher

      expect(find.text('FINGER DETECTED ✓'), findsOneWidget);
      expect(find.text('HOLD STILL…'), findsOneWidget);

      await controller.close();
    });

    testWidgets('out-of-range BPM (0) keeps NO FINGER DETECTED cue',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      controller.add(0); // below physiological range → no finger
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('NO FINGER DETECTED'), findsOneWidget);

      await controller.close();
    });

    testWidgets('out-of-range BPM (221) keeps NO FINGER DETECTED cue',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      controller.add(221);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('NO FINGER DETECTED'), findsOneWidget);

      await controller.close();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Progress ring grows as readings accumulate
  // ───────────────────────────────────────────────────────────────────────────
  group('CameraBpmScreen — progress ring', () {
    testWidgets(
        'ring value increases as more stream events are received',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      // Emit 10 readings into a 30-reading buffer → progress ≈ 0.333
      for (int i = 0; i < 10; i++) {
        controller.add(72);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 650)); // TweenAnimationBuilder

      // The animated progress indicator is the SECOND CircularProgressIndicator
      // (first is the static dark background ring with value = 1.0).
      final allRings = tester
          .widgetList<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator))
          .toList();

      expect(allRings.length, greaterThanOrEqualTo(2));

      final tealRing = allRings[1]; // animated progress ring
      expect(tealRing.value, isNotNull);
      expect(tealRing.value!, greaterThan(0.0),
          reason: 'Ring should have advanced from zero after 10 readings');
      // Allow a small animation overshoot tolerance
      expect(tealRing.value!, lessThanOrEqualTo(10 / 30 + 0.05));

      await controller.close();
    });

    testWidgets('ring value is 0.0 before any readings', (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump(const Duration(milliseconds: 650));

      final allRings = tester
          .widgetList<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator))
          .toList();

      expect(allRings.length, greaterThanOrEqualTo(2));
      final tealRing = allRings[1];
      expect(tealRing.value, isNotNull);
      expect(tealRing.value!, closeTo(0.0, 0.01));

      await controller.close();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 4. LOCK IN button gating — threshold (80%) + stability check
  // ───────────────────────────────────────────────────────────────────────────
  group('CameraBpmScreen — LOCK IN BPM button gating', () {
    testWidgets(
        'button remains disabled at ${BpmFilter.lockThreshold - 1} readings '
        '(one short of threshold)',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      // Skip warmup, then fill buffer to one below the lock threshold.
      for (int i = 0; i < BpmFilter.warmupReadings + BpmFilter.lockThreshold - 1; i++) {
        controller.add(72);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 50));

      final btn = tester.widget<FilledButton>(
          find.widgetWithIcon(FilledButton, Icons.lock_outline));
      expect(btn.onPressed, isNull,
          reason:
              'Button must stay disabled at ${BpmFilter.lockThreshold - 1} readings');

      await controller.close();
    });

    testWidgets(
        'button becomes enabled once ${BpmFilter.lockThreshold} stable readings '
        'are buffered',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      // Emit warmup frames first (discarded), then lockThreshold real readings.
      for (int i = 0; i < BpmFilter.warmupReadings + BpmFilter.lockThreshold; i++) {
        controller.add(72);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 450)); // opacity animation

      final btn = tester.widget<FilledButton>(
          find.widgetWithIcon(FilledButton, Icons.lock_outline));
      expect(btn.onPressed, isNotNull,
          reason:
              'Button must be enabled after ${BpmFilter.lockThreshold} stable readings');

      // Instruction label should reflect READING LOCKED state
      expect(find.text('READING LOCKED'), findsOneWidget);

      await controller.close();
    });

    testWidgets(
        'button stays disabled when count ≥ lockThreshold but last 5 contain a spike',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      // 19 stable readings...
      for (int i = 0; i < 19; i++) {
        controller.add(72);
        await tester.pump();
      }
      // ...then 5 readings where the last one spikes to 160 (>> 72 ±7.2)
      for (final bpm in [72, 72, 72, 72, 160]) {
        controller.add(bpm);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 50));

      final btn = tester.widget<FilledButton>(
          find.widgetWithIcon(FilledButton, Icons.lock_outline));
      expect(btn.onPressed, isNull,
          reason: 'Spike in last 5 readings must prevent lock-in');

      await controller.close();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 5. Warm-up discard — first N frames are dropped
  // ───────────────────────────────────────────────────────────────────────────
  group('CameraBpmScreen — warm-up discard', () {
    testWidgets(
        'progress ring stays at 0 during the warm-up window',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      // Emit exactly [warmupReadings] valid frames — all should be discarded.
      for (int i = 0; i < BpmFilter.warmupReadings; i++) {
        controller.add(72);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 650));

      final allRings = tester
          .widgetList<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator))
          .toList();

      expect(allRings.length, greaterThanOrEqualTo(2));
      // Animated ring must still be at 0 — no readings have entered the buffer.
      expect(allRings[1].value!, closeTo(0.0, 0.01),
          reason: 'Warm-up frames must not advance the progress ring');

      await controller.close();
    });

    testWidgets(
        'readings accumulate only AFTER the warm-up window',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      // Skip warmup...
      for (int i = 0; i < BpmFilter.warmupReadings; i++) {
        controller.add(72);
        await tester.pump();
      }
      // ...then send 5 real readings that should enter the buffer.
      for (int i = 0; i < 5; i++) {
        controller.add(72);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 650));

      final allRings = tester
          .widgetList<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator))
          .toList();

      expect(allRings[1].value!, greaterThan(0.0),
          reason: 'Ring must advance once warm-up is complete');

      await controller.close();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 6. Buffer reset on finger loss
  // ───────────────────────────────────────────────────────────────────────────
  group('CameraBpmScreen — buffer reset on finger loss', () {
    testWidgets(
        'removing and replacing finger clears the buffer so stale readings '
        'do not carry over',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      // Warmup pass.
      for (int i = 0; i < BpmFilter.warmupReadings; i++) {
        controller.add(72);
        await tester.pump();
      }
      // 10 real readings enter the buffer.
      for (int i = 0; i < 10; i++) {
        controller.add(72);
        await tester.pump();
      }

      // Finger removed (out-of-range value).
      controller.add(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));

      // Ring must be back to 0 — buffer was cleared.
      final allRings = tester
          .widgetList<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator))
          .toList();
      expect(allRings[1].value!, closeTo(0.0, 0.01),
          reason: 'Buffer must be empty after finger is removed');

      // NO FINGER DETECTED cue must be showing.
      expect(find.text('NO FINGER DETECTED'), findsOneWidget);

      await controller.close();
    });
  });
}
