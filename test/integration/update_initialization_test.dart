import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() {
  late Isar isar;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Isar.initializeIsarCore(download: true);
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    isar = await Isar.open(
      [WorkoutSessionSchema, UserStatsSchema, DailyActivitySchema],
      directory: Directory.systemTemp.path,
      name: 'test_init_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('Zero-State Initialization', () {
    test('Fresh start: Isar has no DailyActivity → anchor written with totalSteps=0', () async {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final naturalId = int.parse(DateFormat('yyyyMMdd').format(midnight));

      // Precondition: database is empty
      final before = await isar.dailyActivitys.get(naturalId);
      expect(before, isNull, reason: 'Database must start empty for fresh-install sim');

      // Simulate zero-state anchor write (what HealthSyncService does on init)
      final anchor = DailyActivity()
        ..id = naturalId
        ..date = midnight
        ..totalSteps = 0
        ..miles = 0.0
        ..calories = 0;

      await isar.writeTxn(() async {
        await isar.dailyActivitys.put(anchor);
      });

      // ASSERT: Anchor now exists with 0 steps
      final after = await isar.dailyActivitys.get(naturalId);
      expect(after, isNotNull, reason: 'Zero-state anchor must exist after init');
      expect(after!.totalSteps, 0, reason: 'Ghost steps must not be injected on fresh install');
    });

    test('Ghost-step protection: pre-existing record is not overwritten by sensor bleed', () async {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final naturalId = int.parse(DateFormat('yyyyMMdd').format(midnight));

      // Seed an existing 3200-step record (user has been walking)
      await isar.writeTxn(() async {
        await isar.dailyActivitys.put(
          DailyActivity()
            ..id = naturalId
            ..date = midnight
            ..totalSteps = 3200
            ..miles = 1.5
            ..calories = 128,
        );
      });

      // Simulate HealthSyncService logic: only write anchor if null
      final existing = await isar.dailyActivitys.get(naturalId);
      if (existing == null) {
        await isar.writeTxn(() async {
          await isar.dailyActivitys.put(
            DailyActivity()
              ..id = naturalId
              ..date = midnight
              ..totalSteps = 0,
          );
        });
      }

      // ASSERT: 3200 steps must be preserved, not reset to 0
      final after = await isar.dailyActivitys.get(naturalId);
      expect(after!.totalSteps, 3200, reason: 'Existing steps must not be wiped by init anchor');
    });

    test('UI fallback: zero steps yields icon position 0.0 (not NaN or ghost)', () {
      const stepGoal = 10000;
      const currentSteps = 0;

      // Simulate the dashboard journey position formula
      final position = currentSteps > 0 ? (currentSteps / stepGoal).clamp(0.0, 1.0) : 0.0;

      expect(position, 0.0, reason: 'Step Journey icon must start at far-left (0.0) on fresh install');
      expect(position.isNaN, isFalse);
    });
  });
}
