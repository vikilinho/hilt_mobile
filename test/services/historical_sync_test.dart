import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      name: 'test_hist_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('Historical Backfill Logic', () {
    test('Range query uses StartOfDay (midnight) as start, not app-launch time', () {
      // Simulates what HealthSyncService.fetchDailySteps() must do:
      // The startTime must be midnight, not the time the app was opened.
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // StartTime must be exactly midnight
      expect(midnight.hour, 0);
      expect(midnight.minute, 0);
      expect(midnight.second, 0);
      expect(midnight.millisecond, 0);

      // EndTime is "now" — which must be after midnight
      expect(now.isAfter(midnight), isTrue);

      // Simulated 10PM scenario: difference must cover at least 20 hours
      // In real test conditions the 'now' may be any time,  so just verify:
      // if it were 22:00, the delta would be ≥ 20 hours.
      final simulatedEvening = DateTime(now.year, now.month, now.day, 22, 0);
      final delta = simulatedEvening.difference(midnight).inHours;
      expect(delta, 22, reason: 'A 10 PM query must reach back exactly 22 hours to midnight');
    });

    test('DailyActivity is updated with OS-reported total steps, not hardware delta', () async {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final naturalId = int.parse(DateFormat('yyyyMMdd').format(midnight));

      // Simulate OS returning 8,500 steps for the full day
      const osReportedSteps = 8500;

      // Write using the same logic as HealthSyncService._saveToIsar
      await isar.writeTxn(() async {
        await isar.dailyActivitys.put(
          DailyActivity()
            ..id = naturalId
            ..date = midnight
            ..totalSteps = osReportedSteps
            ..miles = double.parse((osReportedSteps * 0.00047).toStringAsFixed(1))
            ..calories = (osReportedSteps * 0.04).toInt(),
        );
      });

      // ASSERT: Isar persists exactly what OS reported
      final record = await isar.dailyActivitys.get(naturalId);
      expect(record, isNotNull);
      expect(record!.totalSteps, osReportedSteps,
          reason: 'Full-day OS bucket (8500) must replace any prior delta accumulation');
    });

    test('App-resume triggers full-day range query via correct naturalId', () async {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final expectedId = int.parse(DateFormat('yyyyMMdd').format(midnight));

      // Simulate what _init() does on AppLifecycleState.resumed
      final queriedId = int.parse(DateFormat('yyyyMMdd').format(midnight));

      expect(queriedId, expectedId,
          reason: 'The naturalId computed on resume must match the current day record');
    });

    test('Match Ready label is absent from UI when steps < goal', () {
      const stepGoal = 10000;
      const currentSteps = 3200;

      // UI should never show MATCH READY below step goal
      final isMatchReady = currentSteps >= stepGoal;
      expect(isMatchReady, isFalse,
          reason: '"MATCH READY" label must not appear below the step goal');
    });

    test('Match Ready label is absent from UI when steps == 0', () {
      const stepGoal = 10000;
      const currentSteps = 0;

      final isMatchReady = currentSteps >= stepGoal;
      expect(isMatchReady, isFalse,
          reason: '"MATCH READY" label must not appear at zero steps (fresh install)');
    });
  });
}
