import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_mobile/src/screens/camera_bpm_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPreview(
    WidgetTester tester, {
    required bool fingerDetected,
    required bool hasPulseSignal,
    int? bpm,
  }) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CameraBpmScreen(
          previewMode: true,
          previewFingerDetected: fingerDetected,
          previewHasPulseSignal: hasPulseSignal,
          previewBpm: bpm,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('camera scanner preview - no finger', (tester) async {
    await pumpPreview(
      tester,
      fingerDetected: false,
      hasPulseSignal: false,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/camera_scanner_no_finger.png'),
    );
  });

  testWidgets('camera scanner preview - measuring', (tester) async {
    await pumpPreview(
      tester,
      fingerDetected: true,
      hasPulseSignal: true,
      bpm: 72,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/camera_scanner_measuring.png'),
    );
  });
}
