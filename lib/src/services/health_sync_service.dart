import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';
import 'step_service.dart';
import 'health_authorization.dart';
import 'health_step_totals.dart';
import '../workout_manager.dart'; // To access the repository

class HealthSyncService {
  static const List<String> _preferredStepSources = [
    'com.android.healthconnect.phone.j4498dfd09a793f5186ff99d814cf5f18',
    'com.google.android.apps.fitness',
    'com.fitbit.FitbitMobile',
  ];

  final Health _health = Health();
  final StepService _stepService;
  WorkoutManager? _workoutManager;
  Isar? _isar;
  bool _didInit = false;
  bool _isFetching = false;

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
    if (_isFetching) return;

    _isFetching = true;
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final naturalId = generateDailyId(midnight);
    
    try {
      // ZERO-STATE INITIALIZATION:
      // Ensure an anchor exists for today before processing deltas to prevent ghost steps.
      final existing = await _isar!.dailyActivitys.get(naturalId);
      if (existing == null) {
        await _saveToIsar(naturalId, midnight, 0);
      }

      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        final granted = await HealthAuthorization.ensureStepReadAccess(_health);
        if (!granted) {
          _stepService.clearExternalDailyStepsPreference();
          // Permission denied: Use hardware sensor
          await _fallbackToHardwareSensor(naturalId, midnight);
          return;
        }
      }

      final sourceSelection =
          await _selectPreferredStepTotal(midnight, now);
      final totalSteps = sourceSelection?.steps ??
          await HealthStepTotals.getTotalForRange(_health, midnight, now);

      if (totalSteps > 0) {
        // Sync Success: Insert/Update DailyActivity
        await _stepService.setExternalDailySteps(totalSteps);
        await _saveToIsar(naturalId, midnight, totalSteps);
      } else {
        _stepService.clearExternalDailyStepsPreference();
        // Zero steps or no recordings yet today. Use fallback or write zeros.
        await _fallbackToHardwareSensor(naturalId, midnight);
      }
    } catch (e) {
       debugPrint("[HealthSync] Error syncing steps: $e");
       _stepService.clearExternalDailyStepsPreference();
       await _fallbackToHardwareSensor(naturalId, midnight);
    } finally {
      _isFetching = false;
    }
  }

  Future<_SelectedStepTotal?> _selectPreferredStepTotal(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: start,
        endTime: end,
        recordingMethodsToFilter: const [RecordingMethod.manual],
      );

      if (points.isEmpty) {
        debugPrint('[HealthSync] No raw Health Connect step points found for source breakdown.');
        return null;
      }

      final sourceTotals = <String, num>{};
      final methodTotals = <String, num>{};

      for (final point in points) {
        final value = point.value;
        if (value is! NumericHealthValue) continue;

        final numeric = value.numericValue;
        final sourceKey = point.sourceName.isNotEmpty ? point.sourceName : point.sourceId;
        sourceTotals[sourceKey] = (sourceTotals[sourceKey] ?? 0) + numeric;

        final methodKey = point.recordingMethod.name;
        methodTotals[methodKey] = (methodTotals[methodKey] ?? 0) + numeric;
      }

      final sourceSummary = sourceTotals.entries
          .map((entry) => '${entry.key}: ${entry.value.round()}')
          .join(', ');
      final methodSummary = methodTotals.entries
          .map((entry) => '${entry.key}: ${entry.value.round()}')
          .join(', ');

      debugPrint('[HealthSync] Step source breakdown: $sourceSummary');
      debugPrint('[HealthSync] Step recording methods: $methodSummary');

      for (final source in _preferredStepSources) {
        final total = sourceTotals[source];
        if (total != null && total > 0) {
          debugPrint('[HealthSync] Selected preferred step source: $source (${total.round()} steps)');
          return _SelectedStepTotal(source: source, steps: total.round());
        }
      }

      return null;
    } catch (e) {
      debugPrint('[HealthSync] Unable to log Health Connect step sources: $e');
      return null;
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

class _SelectedStepTotal {
  const _SelectedStepTotal({
    required this.source,
    required this.steps,
  });

  final String source;
  final int steps;
}
