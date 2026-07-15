import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';
import 'step_service.dart';
import 'health_authorization.dart';
import '../workout_manager.dart'; // To access the repository

class HealthSyncService {
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
    debugPrint('[HealthSync] Initializing Health sync.');
    final hasExistingAccess = await HealthAuthorization.hasStepReadAccess(
      _health,
    );
    debugPrint('[HealthSync] Existing Health step access: $hasExistingAccess');
    await fetchDailySteps(
      interactiveAuthorization: false,
    );
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

  Future<void> fetchDailySteps({
    bool interactiveAuthorization = true,
  }) async {
    if (_isar == null) return;
    if (_isFetching) return;

    debugPrint(
      '[HealthSync] Fetching daily steps. interactive=$interactiveAuthorization',
    );
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
        final granted = await HealthAuthorization.ensureStepReadAccess(
          _health,
          interactive: interactiveAuthorization,
        );
        if (!granted) {
          debugPrint('[HealthSync] Step read access not granted.');
          _stepService.clearExternalDailyStepsPreference();
          // Permission denied: Use hardware sensor
          await _fallbackToHardwareSensor(naturalId, midnight);
          return;
        }
      }

      final totalSteps = await _getDeviceDailyStepTotal(midnight, now);

      if (totalSteps > 0) {
        debugPrint('[HealthSync] Selected device daily steps: $totalSteps');
        // Sync Success: Insert/Update DailyActivity
        await _stepService.setExternalDailySteps(totalSteps);
        await _saveToIsar(naturalId, midnight, _stepService.dailySteps);
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

  Future<int> _getDeviceDailyStepTotal(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: start,
        endTime: end,
      );

      if (points.isEmpty) {
        debugPrint(
          '[HealthSync] No raw Health Connect step points found for source breakdown.',
        );
        return 0;
      }

      return selectDeviceDailyStepTotal(points);
    } catch (e) {
      debugPrint('[HealthSync] Unable to log Health Connect step sources: $e');
      return 0;
    }
  }

  @visibleForTesting
  static int selectDeviceDailyStepTotal(List<HealthDataPoint> points) {
    final sources = <String, _StepSourceCandidate>{};
    final methodTotals = <String, num>{};

    for (final point in points) {
      if (point.type != HealthDataType.STEPS) continue;
      if (point.recordingMethod == RecordingMethod.manual) continue;

      final value = point.value;
      if (value is! NumericHealthValue) continue;

      final steps = value.numericValue;
      if (steps <= 0) continue;

      final sourceKey = _sourceKeyFor(point);
      final candidate = sources.putIfAbsent(
        sourceKey,
        () => _StepSourceCandidate(
          sourceKey: sourceKey,
          sourceId: point.sourceId,
          sourceName: point.sourceName,
        ),
      );
      candidate.steps += steps;

      final methodKey = point.recordingMethod.name;
      methodTotals[methodKey] = (methodTotals[methodKey] ?? 0) + steps;
    }

    if (sources.isEmpty) {
      debugPrint('[HealthSync] No usable non-manual step sources found.');
      return 0;
    }

    final sourceSummary = sources.values
        .map((source) => '${source.sourceKey}: ${source.steps.round()}')
        .join(', ');
    final methodSummary = methodTotals.entries
        .map((entry) => '${entry.key}: ${entry.value.round()}')
        .join(', ');
    debugPrint('[HealthSync] Step source breakdown: $sourceSummary');
    debugPrint('[HealthSync] Step recording methods: $methodSummary');

    final deviceCandidates =
        sources.values.where((source) => !source.isWearableOrImported).toList();
    final candidates = deviceCandidates.isNotEmpty
        ? deviceCandidates
        : sources.values.toList();

    candidates.sort((a, b) {
      final scoreCompare = a.priorityScore.compareTo(b.priorityScore);
      if (scoreCompare != 0) return scoreCompare;
      return b.steps.compareTo(a.steps);
    });

    final selected = candidates.first;
    debugPrint(
      '[HealthSync] Selected step source: ${selected.sourceKey} (${selected.steps.round()} steps)',
    );
    return selected.steps.round();
  }

  static String _sourceKeyFor(HealthDataPoint point) {
    final sourceName = point.sourceName.trim();
    final sourceId = point.sourceId.trim();
    if (sourceName.isEmpty) return sourceId;
    if (sourceId.isEmpty) return sourceName;
    return '$sourceName ($sourceId)';
  }

  Future<void> _saveToIsar(int id, DateTime midnight, int steps) async {
    final existing = await _isar!.dailyActivitys.get(id);
    final preservedSteps = preserveHighestSameDayTotal(
      existing?.totalSteps ?? 0,
      steps,
    );
    final activity = DailyActivity()
      ..id = id
      ..date = midnight
      ..totalSteps = preservedSteps
      ..miles = calculateMiles(preservedSteps)
      ..calories = calculateCalories(preservedSteps);

    await _isar!.writeTxn(() async {
      await _isar!.dailyActivitys.put(activity);
    });
  }

  @visibleForTesting
  static int preserveHighestSameDayTotal(int persisted, int incoming) {
    final safePersisted = persisted < 0 ? 0 : persisted;
    final safeIncoming = incoming < 0 ? 0 : incoming;
    return safeIncoming > safePersisted ? safeIncoming : safePersisted;
  }

  Future<void> _fallbackToHardwareSensor(int id, DateTime midnight) async {
    // Read from existing step service
    final fallbackSteps = _stepService.dailySteps;
    await _saveToIsar(id, midnight, fallbackSteps);
  }
}

class _StepSourceCandidate {
  _StepSourceCandidate({
    required this.sourceKey,
    required this.sourceId,
    required this.sourceName,
  });

  final String sourceKey;
  final String sourceId;
  final String sourceName;
  num steps = 0;

  String get _searchText => '$sourceKey $sourceId $sourceName'.toLowerCase();

  bool get isWearableOrImported {
    return _searchText.contains('fitbit') ||
        _searchText.contains('garmin') ||
        _searchText.contains('oura') ||
        _searchText.contains('polar') ||
        _searchText.contains('whoop') ||
        _searchText.contains('strava') ||
        _searchText.contains('watch') ||
        _searchText.contains('wear os') ||
        _searchText.contains('wearable') ||
        _searchText.contains('zepp') ||
        _searchText.contains('amazfit') ||
        _searchText.contains('huawei') ||
        _searchText.contains('import');
  }

  int get priorityScore {
    if (_searchText.contains('phone') ||
        _searchText.contains('pixel') ||
        _searchText.contains('android')) {
      return 0;
    }
    if (_searchText.contains('google fit') || _searchText.contains('fitness')) {
      return 1;
    }
    if (isWearableOrImported) {
      return 3;
    }
    return 2;
  }
}
