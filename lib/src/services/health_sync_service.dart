import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'step_service.dart';
import '../workout_manager.dart'; // To access the repository

class HealthSyncService with WidgetsBindingObserver {
  final Health _health = Health();
  final StepService _stepService;
  WorkoutManager? _workoutManager;
  Isar? _isar;

  HealthSyncService(this._stepService) {
    WidgetsBinding.instance.addObserver(this);
  }

  void updateDependencies(WorkoutManager manager) {
    if (_workoutManager == null) {
      _workoutManager = manager;
      _isar = manager.repo?.isar; // wait, SessionRepository doesn't expose _isar, let's update it.
      _init();
    }
  }

  Future<void> _init() async {
    await fetchDailySteps();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchDailySteps();
    }
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

    final types = [HealthDataType.STEPS];
    final perms = [HealthDataAccess.READ];

    bool? hasPermissions = await _health.hasPermissions(types, permissions: perms);
    if (hasPermissions != true) {
      final granted = await _health.requestAuthorization(types, permissions: perms);
      if (!granted) {
        // Permission denied: Use hardware sensor
        _fallbackToHardwareSensor(naturalId, midnight);
        return;
      }
    }

    try {
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
        _saveToIsar(naturalId, midnight, totalSteps);
      } else {
        // Zero steps or no recordings yet today. Use fallback or write zeros.
        _fallbackToHardwareSensor(naturalId, midnight);
      }
    } catch (e) {
       debugPrint("[HealthSync] Error syncing steps: $e");
       _fallbackToHardwareSensor(naturalId, midnight);
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

  void _fallbackToHardwareSensor(int id, DateTime midnight) {
    // Read from existing step service
    final fallbackSteps = _stepService.dailySteps;
    _saveToIsar(id, midnight, fallbackSteps);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
