import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_mobile/src/screens/camera_bpm_screen.dart';
import '../support/test_app.dart';

Widget _buildPreviewScreen({
  bool fingerDetected = false,
  int? bpm,
}) {
  return buildTestApp(
    CameraBpmScreen(
      previewMode: true,
      previewFingerDetected: fingerDetected,
      previewHasPulseSignal: fingerDetected,
      previewBpm: bpm,
    ),
  );
}

Widget _buildTestingScreen(Stream<int> stream) {
  return buildTestApp(CameraBpmScreen.forTesting(bpmStream: stream));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraBpmScreen preview', () {
    testWidgets('shows resting scanner guidance when no finger is present',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(_buildPreviewScreen());
      await tester.pump();

      expect(
        find.text('Place finger over the camera lens and flash.'),
        findsOneWidget,
      );
      expect(find.text('COVER LENS'), findsNothing);
      expect(find.text('00'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('shows BPM readout and removes cover prompt when finger is present',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(
        _buildPreviewScreen(
          fingerDetected: true,
          bpm: 72,
        ),
      );
      await tester.pump();

      expect(find.text('72'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      expect(find.text('COVER LENS'), findsNothing);
    });
  });

  group('CameraBpmScreen test stream mode', () {
    testWidgets('does not require real camera permission in forTesting mode',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(_buildTestingScreen(controller.stream));
      await tester.pump();

      expect(find.text('Camera permission required.'), findsNothing);
      expect(find.text('COVER LENS'), findsOneWidget);

      await controller.close();
    });

    testWidgets('valid bpm sample removes cover-lens overlay immediately',
        (tester) async {
      final controller = StreamController<int>.broadcast();

      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(_buildTestingScreen(controller.stream));
      await tester.pump();

      controller.add(75);
      await tester.pump();
      await tester.pump();

      expect(find.text('COVER LENS'), findsNothing);
      expect(
        find.text('Place finger over the camera lens and flash.'),
        findsNothing,
      );

      await controller.close();
    });
  });
}
