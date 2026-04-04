import 'package:flutter_test/flutter_test.dart';
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
  });
}
