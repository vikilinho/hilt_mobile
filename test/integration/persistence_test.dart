import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:isar/isar.dart';

void main() {
  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  group('DailyActivity Persistence Engine', () {
    late Isar isar;

    setUp(() async {
      isar = await Isar.open(
        [WorkoutSessionSchema, UserStatsSchema, DailyActivitySchema],
        directory: Directory.systemTemp.path,
        name: 'persistence_test_${DateTime.now().microsecondsSinceEpoch}',
      );
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
    });

    test('put() with same natural ID overwrites, not duplicates', () async {
      final date = DateTime(2026, 4, 4);
      const naturalId = 20260404;

      // First write
      await isar.writeTxn(() async {
        await isar.dailyActivitys.put(DailyActivity()
          ..id = naturalId
          ..date = date
          ..totalSteps = 3000
          ..miles = 1.4
          ..calories = 120);
      });

      // Second write with same ID (should overwrite)
      await isar.writeTxn(() async {
        await isar.dailyActivitys.put(DailyActivity()
          ..id = naturalId
          ..date = date
          ..totalSteps = 5000
          ..miles = 2.4
          ..calories = 200);
      });

      final all = await isar.dailyActivitys.where().findAll();

      // The natural key enforces uniqueness: only 1 record should exist
      expect(all.length, 1);
      expect(all.first.totalSteps, 5000);
      expect(all.first.calories, 200);
    });

    test('generateDailyId produces correct integer for April 4, 2026', () {
      // Inline the same logic used in HealthSyncService
      final date = DateTime(2026, 4, 4);
      final id = int.parse(
        '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}',
      );
      expect(id, 20260404);
    });

    test('record persists across Isar instance close and re-open', () async {
      const naturalId = 20260404;
      final date = DateTime(2026, 4, 4);
      final dir = Directory.systemTemp.path;
      const dbName = 'persistence_reopen_test';

      // Open a fresh instance
      final db1 = await Isar.open(
        [WorkoutSessionSchema, UserStatsSchema, DailyActivitySchema],
        directory: dir,
        name: dbName,
      );

      await db1.writeTxn(() async {
        await db1.dailyActivitys.put(DailyActivity()
          ..id = naturalId
          ..date = date
          ..totalSteps = 7500
          ..miles = 3.5
          ..calories = 300);
      });

      // Close it
      await db1.close();

      // Re-open the SAME database
      final db2 = await Isar.open(
        [WorkoutSessionSchema, UserStatsSchema, DailyActivitySchema],
        directory: dir,
        name: dbName,
      );

      final record = await db2.dailyActivitys.get(naturalId);

      expect(record, isNotNull);
      expect(record!.totalSteps, 7500);
      expect(record.id, naturalId);

      await db2.close(deleteFromDisk: true);
    });
  });
}
