import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'step_service.dart';
import '../workout_manager.dart'; // To access the repository

class HealthSyncService {
  final Health _health = Health();
  final StepService _stepService;
  WorkoutManager? _workoutManager;
  Isar? _isar;
  bool _didInit = false;

  HealthSyncService(this._stepService);

  void updateDependencies(WorkoutManager manager) {
    _workoutManager ??= manager;

    final repo = manager.repo;
    if (repo == null) return;

    _isar = repo.isar;
    if (_didInit) return;

    _didInit = true;
    _init();
  }

  Future<void> _init() async {
    await fetchDailySteps();
  }

  static int generateDailyId(DateTime date) {
    return int.parse(DateFormat('yyyyMMdd').format(date));
  }

  static double calculateMiles(int steps) {
    return double.parse((steps * 0.00047).toStringAsFixed(1));
  }

  static int calculateCalories(int steps) {
    return (steps * 0.04).toInt();
  }

  Future<void> fetchDailySteps() async {
    if (_isar == null) return;
    
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    
    // Natural ID format: yyyyMMdd
    final naturalId = generateDailyId(midnight);

    // ZERO-STATE INITIALIZATION:
    // Ensure an anchor exists for today before processing deltas to prevent ghost steps.
    final existing = await _isar!.dailyActivitys.get(naturalId);
    if (existing == null) {
      await _saveToIsar(naturalId, midnight, 0);
    }

    final types = [HealthDataType.STEPS];
    final perms = [HealthDataAccess.READ];

    bool? hasPermissions = true;
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      hasPermissions = await _health.hasPermissions(types, permissions: perms);
      if (hasPermissions != true) {
        final granted = await _health.requestAuthorization(types, permissions: perms);
        if (!granted) {
          // Permission denied: Use hardware sensor
          await _fallbackToHardwareSensor(naturalId, midnight);
          return;
        }
      }
    }

    try {
      // EXPLICIT HISTORICAL RANGE: Start of day -> Now
      final healthData = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: types,
      );

      int totalSteps = 0;
      for (var data in healthData) {
        if (data.value is NumericHealthValue) {
          totalSteps += (data.value as NumericHealthValue).numericValue.toInt();
        }
      }

      if (totalSteps > 0) {
        // Sync Success: Insert/Update DailyActivity
        await _saveToIsar(naturalId, midnight, totalSteps);
      } else {
        // Zero steps or no recordings yet today. Use fallback or write zeros.
        await _fallbackToHardwareSensor(naturalId, midnight);
      }
    } catch (e) {
       debugPrint("[HealthSync] Error syncing steps: $e");
       await _fallbackToHardwareSensor(naturalId, midnight);
    }
  }

  Future<void> _saveToIsar(int id, DateTime midnight, int steps) async {
    final activity = DailyActivity()
      ..id = id
      ..date = midnight
      ..totalSteps = steps
      ..miles = calculateMiles(steps)
      ..calories = calculateCalories(steps);

    await _isar!.writeTxn(() async {
      await _isar!.dailyActivitys.put(activity);
    });
  }

  Future<void> _fallbackToHardwareSensor(int id, DateTime midnight) async {
    // Read from existing step service
    final fallbackSteps = _stepService.dailySteps;
    await _saveToIsar(id, midnight, fallbackSteps);
  }
}
