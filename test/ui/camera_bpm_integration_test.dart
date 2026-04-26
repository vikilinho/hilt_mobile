/// Integration and widget tests for the CameraBpmScreen exposure lock sequence
/// and sustained status stability.
///
/// ## Architecture note — camera controller mocking
///
/// [CameraController] is a heavy platform plugin that builds on top of the
/// `plugins.flutter.io/camera` method channel. Mocking it at the method-call
/// level in widget tests is fundamentally fragile (channel names vary by
/// platform and plugin federation), and timing verification (proving ≥1200 ms
/// elapsed between setFlashMode and setExposureMode) cannot be done reliably
/// in a fake-async environment where [Future.delayed] is quantised to
/// [tester.pump] increments.
///
/// The same architectural limitation is acknowledged in the existing torch
/// stability test group (camera_bpm_screen_test.dart, lines 400–407), which
/// includes the comment:
///   "A separate device/integration test is required to assert that
///    setFlashMode is called exactly once on a real device."
///
/// The tests below therefore validate the *observable consequences* of the
/// settle-then-lock sequence via the BPM stream interface, exactly as the
/// rest of the test suite does. Each test documents the corresponding
/// hardware-level assertion that must be verified on a physical device.
///
/// ## What these tests cover:
///   1. Exposure-settle window: BPM stream data arriving after a 1200 ms gap
///      does not trigger a false `NO FINGER DETECTED` event.
///   2. Status stability: a sustained high-brightness stream (≥30 readings)
///      never causes the status to flicker to `NO FINGER DETECTED`.
///   3. Settle-point reset: emitting valid BPM data after a simulated settle
///      gap results in correct stabilizing → ready state transitions.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_mobile/src/screens/camera_bpm_screen.dart';
import 'package:hilt_mobile/src/services/bpm_filter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildScreen(Stream<int> stream) => MaterialApp(
      home: CameraBpmScreen.forTesting(bpmStream: stream),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Stub permission channel (matches existing test suite setup).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async => 1, // PermissionStatus.granted
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 1. Exposure-settle window — BPM data after 1200 ms gap must be accepted
  //
  //  Device-level assertion (requires physical device):
  //    setFlashMode(torch) → pause ≥ 1200 ms → setExposureMode(locked)
  //    → setExposureOffset(-2.0) → startImageStream().
  //    Verified by attaching a custom CameraController spy or using
  //    instrumented integration tests via flutter drive.
  // ───────────────────────────────────────────────────────────────────────────
  group('CameraBpmScreen — settle-window BPM acceptance', () {
    testWidgets(
        'finger is accepted immediately after a 1200 ms settle-equivalent gap '
        '— no false NO FINGER DETECTED on first post-settle frame', (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      // Initial state: no data → finger not detected.
      expect(find.text('NO FINGER DETECTED'), findsOneWidget);

      // Simulate the settle window: no frames arrive for 1200 ms.
      await tester.pump(const Duration(milliseconds: 1200));

      // Status must still show 'no finger' (no false positive during gap).
      expect(find.text('NO FINGER DETECTED'), findsOneWidget,
          reason: 'No data during settle window → finger must not be '
              'spuriously detected');

      // First valid BPM arrives after settle + lock (first real camera frame).
      controller.add(75);
      await tester.pump();
      // pumpAndSettle: AnimatedSwitcher dismisses the outgoing widget via a
      // status-listener callback that triggers its own setState; a plain
      // pump(350ms) advances the animation but does not flush that removal
      // setState — pumpAndSettle handles both in one call.
      await tester.pumpAndSettle();

      // Finger must now be detected without any further gap.
      expect(
        find.text('FINGER DETECTED ✓'),
        findsOneWidget,
        reason:
            'First valid BPM arriving after a 1200 ms settle gap must '
            'immediately trigger FINGER DETECTED ✓ — no secondary gap needed',
      );
      expect(find.text('NO FINGER DETECTED'), findsNothing,
          reason: 'Old AnimatedSwitcher child must be fully removed after settle');

      await controller.close();
    });

    testWidgets(
        'multiple settle gaps between readings do not accumulate to a false '
        'reset — each gap is independent', (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      // Past warmup.
      for (int i = 0; i < BpmFilter.warmupReadings; i++) {
        controller.add(72);
        await tester.pump();
      }

      // Simulate an irregular camera frame rate: short gaps between frames.
      for (int batch = 0; batch < 3; batch++) {
        await tester.pump(const Duration(milliseconds: 400));
        controller.add(72);
        await tester.pump();
      }

      await tester.pump(const Duration(milliseconds: 350));

      // After warmup + 3 valid readings, finger must still be detected.
      expect(find.text('FINGER DETECTED ✓'), findsOneWidget,
          reason: 'Irregular inter-frame gaps must not reset finger detection');

      await controller.close();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Status stability — sustained high-brightness stream
  //
  //  Verifies Task 4: the _statusText must remain stable during active
  //  measurement and never flicker back to NO FINGER DETECTED.
  //
  //  Device-level assertion:
  //    With ExposureMode.locked + offset -2.0, the inter-frame brightness
  //    variance must be < 5 units (measured as brightnessMean std-dev across
  //    30 consecutive frames at 30 fps on a physical Android device).
  // ───────────────────────────────────────────────────────────────────────────
  group('CameraBpmScreen — status stability (sustained high-brightness stream)',
      () {
    testWidgets(
        'status never flickers to NO FINGER DETECTED during a 5-second '
        'sustained valid BPM stream (simulating a high-brightness torch session)',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      // Prime the initial finger detection and let the AnimatedSwitcher
      // transition fully settle before the per-frame assertion loop.
      // Without this, frame 0 of the loop would catch the outgoing
      // 'NO FINGER DETECTED' widget still fading out in the AnimatedSwitcher.
      controller.add(75);
      await tester.pump();
      await tester.pumpAndSettle(); // waits for AnimatedSwitcher removal setState
      expect(find.text('NO FINGER DETECTED'), findsNothing,
          reason: 'Finger must be detected and animation fully settled before loop');

      // Sustain valid readings for ~5 seconds worth of frames at 30 fps.
      // The AnimatedSwitcher key (ValueKey(_fingerDetected)) stays unchanged
      // (true→true) so no further transition fires — each frame is safe to assert.
      for (int frame = 0; frame < 30; frame++) {
        controller.add(75);
        await tester.pump(const Duration(milliseconds: 33)); // ~30 fps

        // The critical assertion: status must NEVER revert to 'no finger'
        // while valid BPM data is arriving.
        expect(
          find.text('NO FINGER DETECTED'),
          findsNothing,
          reason:
              'Frame $frame: valid BPM (75) was just emitted — '
              '"NO FINGER DETECTED" must not appear (flicker regression)',
        );
      }

      // After the sustained stream, FINGER DETECTED ✓ must still be showing.
      expect(find.text('FINGER DETECTED ✓'), findsOneWidget);

      await controller.close();
    });

    testWidgets(
        'a single out-of-range frame does NOT cause a permanent finger-loss '
        '— detection recovers on the next valid frame', (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      // Build up readings past warmup.
      for (int i = 0; i < BpmFilter.warmupReadings + 5; i++) {
        controller.add(72);
        await tester.pump();
      }

      // Inject one transient out-of-range spike (motion artifact / saturated
      // overexposure): the kind of frame that would arrive BEFORE exposure lock.
      controller.add(0); // below physiological range
      await tester.pump();

      // Followed immediately by a valid frame (exposure lock prevents sat.).
      controller.add(72);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Status must have recovered — FINGER DETECTED ✓ must be showing.
      expect(
        find.text('FINGER DETECTED ✓'),
        findsOneWidget,
        reason:
            'A single transient bad frame must not permanently lose the finger '
            '— valid data immediately after must restore detection',
      );

      await controller.close();
    });

    testWidgets(
        'status transitions correctly through stabilizing → ready during '
        'a sustained stream — never regresses to NO FINGER DETECTED',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      // Phase 1: warmup (frames discarded — cue shows COVER THE LENS).
      //
      // The first reading changes _fingerDetected false→true, triggering the
      // AnimatedSwitcher transition. pumpAndSettle() on the first frame ensures
      // the old 'NO FINGER DETECTED' widget is fully removed before we enter
      // the per-iteration assertion loop (where only pump() is called).
      controller.add(72);
      await tester.pump();
      await tester.pumpAndSettle(); // flush AnimatedSwitcher widget removal
      expect(find.text('NO FINGER DETECTED'), findsNothing,
          reason: 'Warmup frame 0: finger detected — old cue must be gone');

      for (int i = 1; i < BpmFilter.warmupReadings; i++) {
        controller.add(72);
        await tester.pump();
        // ValueKey(true)→ValueKey(true): no new AnimatedSwitcher transition.
        expect(find.text('NO FINGER DETECTED'), findsNothing,
            reason: 'Warmup frame $i: finger detected flag must not regress');
      }

      // Phase 2: accumulate toward lock threshold.
      for (int i = 0; i < BpmFilter.lockThreshold - 1; i++) {
        controller.add(72);
        await tester.pump();
        expect(find.text('NO FINGER DETECTED'), findsNothing,
            reason: 'Stabilizing frame $i: must never revert to no-finger');
      }

      // Phase 3: hit the lock threshold — status becomes READING LOCKED.
      controller.add(72);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('READING LOCKED'), findsOneWidget,
          reason: 'After lockThreshold stable readings, status must be LOCKED');
      expect(find.text('NO FINGER DETECTED'), findsNothing,
          reason: 'LOCKED state must never show NO FINGER DETECTED');

      await controller.close();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Post-settle reset — buffer starts clean
  //
  //  [_CameraBpmScreenState._resetProductionSignal] is called after the 1200 ms
  //  settle window and before [startImageStream]. This means:
  //    a) No settle-window frames contaminate _redBuffer.
  //    b) _currentComputedBpm starts at 0 (not a stale prior value).
  //    c) The progress ring resets to 0 — no "free progress" from settle.
  //
  //  Tests below verify (b) and (c) via the observable BPM stream interface.
  // ───────────────────────────────────────────────────────────────────────────
  group('CameraBpmScreen — post-settle buffer starts clean', () {
    testWidgets(
        'BPM display shows 0 (--) at the start of a new session '
        '— no stale BPM bleeds from a prior settle window', (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      // No data has arrived yet — BPM text must be placeholder.
      expect(find.text('--'), findsOneWidget,
          reason: 'Fresh session must start with -- BPM, not a stale value');

      await controller.close();
    });

    testWidgets(
        'progress ring is 0.0 at t=0 and begins advancing only after valid '
        'post-warmup readings arrive — settle window adds no "free" progress',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));

      // Advance 1200 ms (the settle window duration) with no data.
      await tester.pump(const Duration(milliseconds: 1200));

      final rings = tester
          .widgetList<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator))
          .toList();

      expect(rings.length, greaterThanOrEqualTo(2));
      expect(
        rings[1].value!,
        closeTo(0.0, 0.01),
        reason:
            'After a 1200 ms settle window with no BPM data, the progress '
            'ring must remain at 0 — the settle gap must not pad progress',
      );

      await controller.close();
    });

    testWidgets(
        'BPM stream data arriving after the settle window (1200 ms gap) '
        'drives the progress ring forward from a clean zero baseline',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump(const Duration(milliseconds: 1200)); // settle gap

      // Post-settle readings start. Skip warmup then add 10 real readings.
      for (int i = 0; i < BpmFilter.warmupReadings + 10; i++) {
        controller.add(72);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 650));

      final rings = tester
          .widgetList<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator))
          .toList();

      expect(
        rings[1].value!,
        greaterThan(0.0),
        reason: 'Progress ring must advance once real post-settle data '
            'arrives — confirming the buffer reset worked correctly',
      );
      // Ring must not show more progress than 10 readings justify.
      expect(rings[1].value!, lessThanOrEqualTo(10 / 30 + 0.05));

      await controller.close();
    });
  });
}
