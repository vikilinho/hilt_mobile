import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:hilt_mobile/src/services/step_service.dart';
import 'package:hilt_mobile/src/workout_manager.dart';
import 'package:isar_community/isar.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Mock PathProvider so Isar can be opened
class MockPathProviderPlatform extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }
}

class MockWorkoutManager extends Mock implements WorkoutManager {}

class MockStepCount extends Mock implements StepCount {}

/// Returns an empty stream for any mocked EventChannel, preventing
/// MissingPluginException from platform channels not available in tests.
class _NullStreamHandler implements MockStreamHandler {
  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {}

  @override
  void onCancel(Object? arguments) {}
}



void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = MockPathProviderPlatform();

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // Mock permission_handler: always granted
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async => 1,
    );

    // Mock sensors_plus method channel (setAccelerationSamplingPeriod, etc.)
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
      (call) async => null,
    );

    // Mock pedometer event channel – return an empty stream immediately
    messenger.setMockStreamHandler(
      const EventChannel('step_count'),
      _NullStreamHandler(),
    );
    messenger.setMockStreamHandler(
      const EventChannel('step_detection'),
      _NullStreamHandler(),
    );

    // Mock sensors_plus event channel
    messenger.setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/sensors/accelerometer'),
      _NullStreamHandler(),
    );

    await Isar.initializeIsarCore(download: true);
  });

  group('StepService Gait Validation (Anti-Shake Filter)', () {
    late StepService stepService;
    late StreamController<StepCount> mockStepStream;
    late StreamController<AccelerometerEvent> mockAccelStream;
    late Isar isar;
    late SessionRepository repo;
    late MockWorkoutManager mockManager;

    setUp(() async {
      // Setup Isar DB in memory/temp
      isar = await Isar.open(
        [WorkoutSessionSchema, UserStatsSchema, DailyActivitySchema],
        directory: Directory.systemTemp.path,
        name: 'step_service_test_${DateTime.now().microsecondsSinceEpoch}',
      );
      repo = SessionRepository(isar);
      
      mockManager = MockWorkoutManager();
      when(() => mockManager.repo).thenReturn(repo);

      stepService = StepService();
      
      // Inject db dependency
      stepService.updateDependencies(mockManager);
      
      // Wait for async Isar refresh logic
      await Future.delayed(const Duration(milliseconds: 100));

      mockStepStream = StreamController<StepCount>.broadcast();
      mockAccelStream = StreamController<AccelerometerEvent>.broadcast();

      stepService.setStreamOverrides(
        steps: mockStepStream.stream,
        accel: mockAccelStream.stream,
      );
    });

    tearDown(() async {
      await mockStepStream.close();
      await mockAccelStream.close();
      stepService.dispose();
      await isar.close(deleteFromDisk: true);
    });

    StepCount getMockStep(int steps) {
      final mock = MockStepCount();
      when(() => mock.steps).thenReturn(steps);
      return mock;
    }

    test('Simulate accelerometer reading < 1.2G -> ignores steps', () async {
      // Inject < 1.2G event
      mockAccelStream.add(AccelerometerEvent(0, 0, 9.81 * 0.5, DateTime.now())); // 0.5 G
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Inject fake pedometer step count
      mockStepStream.add(getMockStep(5));
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(stepService.dailySteps, 0);
    });

    test('Simulate accelerometer reading > 2.5G -> ignores steps', () async {
      // Inject > 2.5G event (Violent shaking)
      mockAccelStream.add(AccelerometerEvent(0, 0, 9.81 * 5.0, DateTime.now())); // 5.0 G
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Inject fake step (delta 1)
      mockStepStream.add(getMockStep(1));
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Should completely block it
      expect(stepService.dailySteps, 0);
    });

    test('Simulate rhythmic 1.8g pulse -> buffer triggers after 8 steps', () async {
      // Simulate 8 rhythmic steps
      for (int i = 1; i <= 8; i++) {
        // Send a 1.8G peak
        mockAccelStream.add(AccelerometerEvent(0, 0, 9.81 * 1.8, DateTime.now()));

        await Future.delayed(const Duration(milliseconds: 50));
        
        // Pedometer registers it
        mockStepStream.add(getMockStep(i));
        
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Validation: Should remain 0 until the 8th step!
        if (i < 8) {
          expect(stepService.dailySteps, 0, reason: 'Failed buffering at step $i');
        } else {
          expect(stepService.dailySteps, 8, reason: 'Failed graduating 8 steps');
        }
      }
    });
  });
}
