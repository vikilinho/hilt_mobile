import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:hilt_mobile/src/services/health_sync_service.dart';

void main() {
  group('HealthSyncService Unit Tests', () {
    test('generateDailyId must return 20260404 for April 4, 2026', () {
      final date = DateTime(2026, 4, 4);
      final generatedId = HealthSyncService.generateDailyId(date);
      
      expect(generatedId, 20260404);
    });
    
    test('generateDailyId must correctly pad single digit months and days', () {
      final date = DateTime(2026, 1, 9);
      final generatedId = HealthSyncService.generateDailyId(date);
      
      expect(generatedId, 20260109);
    });

    test('calculateMiles derives correct distance to 1 decimal place', () {
      // 5000 * 0.00047 = 2.35 -> rounded to 1 decimal place = 2.4
      final miles = HealthSyncService.calculateMiles(5000);
      expect(miles, 2.4);
      
      // 10000 * 0.00047 = 4.7
      final miles2 = HealthSyncService.calculateMiles(10000);
      expect(miles2, 4.7);
    });

    test('calculateCalories derives correct calories', () {
      // 5000 * 0.04 = 200
      final calories = HealthSyncService.calculateCalories(5000);
      expect(calories, 200);
      
      // 1234 * 0.04 = 49.36 -> 49
      final calories2 = HealthSyncService.calculateCalories(1234);
      expect(calories2, 49);
    });

    test('selectDeviceDailyStepTotal prefers phone steps over Fitbit totals', () {
      final points = [
        _stepPoint(
          steps: 1900,
          sourceName: 'Pixel Phone',
          sourceId: 'android.phone',
        ),
        _stepPoint(
          steps: 10000,
          sourceName: 'Fitbit',
          sourceId: 'com.fitbit.FitbitMobile',
        ),
      ];

      expect(HealthSyncService.selectDeviceDailyStepTotal(points), 1900);
    });

    test('selectDeviceDailyStepTotal ignores manual entries', () {
      final points = [
        _stepPoint(
          steps: 2500,
          sourceName: 'Pixel Phone',
          sourceId: 'android.phone',
        ),
        _stepPoint(
          steps: 7000,
          sourceName: 'Manual Entry',
          sourceId: 'manual',
          recordingMethod: RecordingMethod.manual,
        ),
      ];

      expect(HealthSyncService.selectDeviceDailyStepTotal(points), 2500);
    });
  });
}

HealthDataPoint _stepPoint({
  required int steps,
  required String sourceName,
  required String sourceId,
  RecordingMethod recordingMethod = RecordingMethod.automatic,
}) {
  final now = DateTime(2026, 6, 3, 12);
  return HealthDataPoint(
    uuid: '$sourceId-$steps',
    value: NumericHealthValue(numericValue: steps),
    type: HealthDataType.STEPS,
    unit: HealthDataUnit.COUNT,
    dateFrom: now.subtract(const Duration(minutes: 10)),
    dateTo: now,
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'test-device',
    sourceId: sourceId,
    sourceName: sourceName,
    recordingMethod: recordingMethod,
  );
}
