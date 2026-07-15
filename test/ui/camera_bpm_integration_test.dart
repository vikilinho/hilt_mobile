library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_mobile/src/screens/camera_bpm_screen.dart';
import '../support/test_app.dart';

Widget _buildScreen(Stream<int> stream) =>
    buildTestApp(CameraBpmScreen.forTesting(bpmStream: stream));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraBpmScreen — stream stability', () {
    testWidgets(
        'first valid sample after a settle-equivalent gap removes the cover overlay',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      expect(find.text('COVER LENS'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1200));
      controller.add(75);
      await tester.pump();
      await tester.pump();

      expect(find.text('COVER LENS'), findsNothing);

      await controller.close();
    });

    testWidgets('irregular gaps between valid samples do not restore the resting cue',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      controller.add(72);
      await tester.pump();
      await tester.pump();
      expect(find.text('COVER LENS'), findsNothing);

      for (final gap in [400, 700, 1200]) {
        await tester.pump(Duration(milliseconds: gap));
        controller.add(72);
        await tester.pump();
        await tester.pump();
        expect(find.text('COVER LENS'), findsNothing);
      }

      await controller.close();
    });

    testWidgets('sustained valid stream keeps the scanner out of the resting state',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(_buildScreen(controller.stream));
      await tester.pump();

      for (var frame = 0; frame < 30; frame++) {
        controller.add(75);
        await tester.pump(const Duration(milliseconds: 33));
        await tester.pump();
        expect(find.text('COVER LENS'), findsNothing);
        expect(
          find.text('Place finger over the camera lens and flash.'),
          findsNothing,
        );
      }

      await controller.close();
    });
  });
}
