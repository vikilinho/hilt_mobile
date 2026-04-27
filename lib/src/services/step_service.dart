import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../workout_manager.dart';

class MagEvent {
  final DateTime time;
  final double mag;
  MagEvent(this.time, this.mag);
}

class StepService extends ChangeNotifier with WidgetsBindingObserver {
  SessionRepository? _repo;
  UserStats? _userStats;
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  Timer? _midnightCheckTimer;

  final _stepsController = StreamController<int>.broadcast();
  Stream<int> get stepsStream => _stepsController.stream;

  int _currentSteps = 0;
  int get dailySteps => _currentSteps;
  bool _preferExternalStepTotal = false;
  
  @visibleForTesting
  set dailySteps(int steps) => _currentSteps = steps;
  int get stepGoal => _userStats?.stepGoal ?? 10000;
  bool get isMatchReady => dailySteps >= stepGoal;

  WorkoutManager? _workoutManager;
  int _lastRawSensorTotal = 0;

  Future<void> setExternalDailySteps(int steps) async {
    _preferExternalStepTotal = true;
    if (_currentSteps == steps) return;

    _currentSteps = steps;
    if (_userStats != null && _repo != null) {
      _userStats!.dailySteps = steps;
      _userStats!.lastResetDate ??= DateTime.now();
      await _repo!.saveUserStats(_userStats!);
    }
    _publish();
  }

  void clearExternalDailyStepsPreference() {
    _preferExternalStepTotal = false;
  }

  // ---------------------------------------------------------------------------
  // Gait Validation State
  // ---------------------------------------------------------------------------
  final Queue<MagEvent> _recentMagnitudes = Queue();
  final Queue<DateTime> _recentPeaks = Queue();
  DateTime? _shakePauseUntil;
  double _lastMag = 1.0;
  double _lastLastMag = 1.0;

  final Queue<DateTime> _stepBuffer = Queue();
  DateTime _lastValidStepTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isWalkingBurst = false;

  StepService() {
    _startMidnightChecker();
    WidgetsBinding.instance.addObserver(this);
  }

  void updateDependencies(WorkoutManager? manager) {
    if (_repo == null && manager?.repo != null) {
      _repo = manager!.repo;
      _workoutManager = manager;
      _initService();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAccelerometerStream();
      _refreshFromIsar();
      _checkMidnightReset();
      _workoutManager?.refreshHistory();
    }
  }

  Future<void> _initService() async {
    if (_repo == null) return;

    if (await Permission.activityRecognition.isDenied) {
      await Permission.activityRecognition.request();
    }

    _startSensorStreams();
    await _refreshFromIsar();
  }

  void _startSensorStreams() {
    _stepSubscription?.cancel();
    _accelSubscription?.cancel();

    _checkMidnightReset();

    _stepSubscription = (_stepStreamOverride ?? Pedometer.stepCountStream).listen((StepCount event) {
      _handleNewSensorValue(event.steps);
    }, onError: (error) {
      debugPrint('[StepService] Sensor error: $error');
    });

    _accelSubscription = (_accelStreamOverride ?? accelerometerEventStream()).listen((event) {
        final now = DateTime.now();
        final mag = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z) / 9.81;

        _recentMagnitudes.add(MagEvent(now, mag));

        // Peak Detection
        if (_lastMag > _lastLastMag && _lastMag > mag && _lastMag > 1.2) {
          _recentPeaks.add(now);
        }

        _lastLastMag = _lastMag;
        _lastMag = mag;

        // Sliding windows pruning
        final magCutoff = now.subtract(const Duration(milliseconds: 1500));
        while (_recentMagnitudes.isNotEmpty && _recentMagnitudes.first.time.isBefore(magCutoff)) {
          _recentMagnitudes.removeFirst();
        }

        final peakCutoff = now.subtract(const Duration(seconds: 1));
        while (_recentPeaks.isNotEmpty && _recentPeaks.first.isBefore(peakCutoff)) {
          _recentPeaks.removeFirst();
        }

        // 4Hz Frequency Cutoff Loop Protector
        if (_recentPeaks.length > 4) {
          _shakePauseUntil = now.add(const Duration(seconds: 5));
        }
    });
  }

  Stream<StepCount>? _stepStreamOverride;
  Stream<AccelerometerEvent>? _accelStreamOverride;

  @visibleForTesting
  void setStreamOverrides({
    Stream<StepCount>? steps,
    Stream<AccelerometerEvent>? accel,
  }) {
    _stepStreamOverride = steps;
    _accelStreamOverride = accel;
    _startSensorStreams();
  }



  // ---------------------------------------------------------------------------
  // ACCELEROMETER STREAM (GAIT VALIDATOR)
  // ---------------------------------------------------------------------------
  void _startAccelerometerStream() {
    _accelSubscription?.cancel();
    _accelSubscription = accelerometerEventStream().listen((event) {
      final now = DateTime.now();
      final mag = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z) / 9.81;

      _recentMagnitudes.add(MagEvent(now, mag));

      // Peak Detection
      if (_lastMag > _lastLastMag && _lastMag > mag && _lastMag > 1.2) {
        _recentPeaks.add(now);
      }

      _lastLastMag = _lastMag;
      _lastMag = mag;

      // Sliding windows pruning
      final magCutoff = now.subtract(const Duration(milliseconds: 1500));
      while (_recentMagnitudes.isNotEmpty && _recentMagnitudes.first.time.isBefore(magCutoff)) {
        _recentMagnitudes.removeFirst();
      }

      final peakCutoff = now.subtract(const Duration(seconds: 1));
      while (_recentPeaks.isNotEmpty && _recentPeaks.first.isBefore(peakCutoff)) {
        _recentPeaks.removeFirst();
      }

      // 4Hz Frequency Cutoff Loop Protector
      if (_recentPeaks.length > 4) {
        _shakePauseUntil = now.add(const Duration(seconds: 5));
      }
    }, onError: (e) {
      debugPrint('[StepService] Accel error: $e');
    });
  }

  bool _validateWithAccelerometer() {
    final now = DateTime.now();

    // 1. Is 5-second shake pause active?
    if (_shakePauseUntil != null && now.isBefore(_shakePauseUntil!)) {
      return false;
    }

    // If accelerometer data is unavailable, default to trusting the pedometer.
    if (_recentMagnitudes.isEmpty) return true;

    // 2. Magnitude Ceiling Filter
    double maxMag = 1.0;
    for (var m in _recentMagnitudes) {
      if (m.mag > maxMag) maxMag = m.mag;
    }

    // Walking while holding the phone steady (foreground) has very low G-force variance
    // We only filter out violent shakes (> 2.5G).
    if (maxMag > 2.5) {
      return false; // Kinematically invalid step
    }
    return true; // Kinematically valid step
  }

  void _commitBufferedSteps() {
    if (_stepBuffer.isNotEmpty) {
      _userStats!.startOfDaySteps -= _stepBuffer.length;
      _stepBuffer.clear();
      _isWalkingBurst = true;
    }
  }

  // ---------------------------------------------------------------------------
  // STEP PROCESSING
  // ---------------------------------------------------------------------------
  Future<void> _refreshFromIsar() async {
    if (_repo == null) return;
    _userStats = await _repo!.getUserStats();
    
    // 1. Immediately load the persisted state so the UI snaps to the correct steps in 0ms.
    final persisted = _userStats?.dailySteps ?? 0;
    if (persisted != _currentSteps) {
      _currentSteps = persisted;
      _publish();
    }

    // 2. Initialize the background delta anchor mathematically without waiting for the sensor.
    final anchor = _userStats?.startOfDaySteps ?? 0;
    _lastRawSensorTotal = persisted + anchor;
  }

  Future<void> _handleNewSensorValue(int rawSensorTotal) async {
    try {
      if (_userStats == null || _repo == null) return;

      final now = DateTime.now();
      final lastReset = _userStats!.lastResetDate;

      if (lastReset != null) {
        final nowDay = DateTime(now.year, now.month, now.day);
        final lastDay =
            DateTime(lastReset.year, lastReset.month, lastReset.day);

        if (!nowDay.isAtSameMomentAs(lastDay)) {
          _userStats!.lastResetDate = now;
          await _handleDayChange(lastDay, nowDay, now, rawSensorTotal);
          _lastRawSensorTotal = rawSensorTotal;
          return;
        }
      } else {
        _currentSteps = 0;
        _userStats!.dailySteps = 0;
        _userStats!.lastResetDate = now;
        _userStats!.startOfDaySteps = rawSensorTotal;
        await _repo!.saveUserStats(_userStats!);
        _lastRawSensorTotal = rawSensorTotal;
        _publish();
        return;
      }

      if (_userStats!.startOfDaySteps == 0 && rawSensorTotal > 0) {
        int newAnchor = rawSensorTotal - _userStats!.dailySteps;
        if (newAnchor < 0) newAnchor = 0;
        _userStats!.startOfDaySteps = newAnchor;
        await _repo!.saveUserStats(_userStats!);
      }

      // --- GAIT VALIDATION LOGIC ---
      int delta = rawSensorTotal - _lastRawSensorTotal;
      _lastRawSensorTotal = rawSensorTotal;

      if (delta <= 0) return;

      bool dbNeedsUpdate = false;

      if (delta > 5) {
        // Bulk jump from deep sleep/background. Flush active buffers and commit.
        _commitBufferedSteps();
        dbNeedsUpdate = true;
      } else {
        for (int i = 0; i < delta; i++) {
          bool isValid = _validateWithAccelerometer();

          if (!isValid) {
            _userStats!.startOfDaySteps++;
            _isWalkingBurst = false;
            _stepBuffer.clear();
            dbNeedsUpdate = true;
            continue;
          }

          if (_isWalkingBurst) {
            if (now.difference(_lastValidStepTime).inSeconds > 3) {
              _isWalkingBurst = false;
              _stepBuffer.clear();
              _stepBuffer.add(now);
              _userStats!.startOfDaySteps++;
              dbNeedsUpdate = true;
            }
          } else {
            _stepBuffer.add(now);
            _userStats!.startOfDaySteps++;
            dbNeedsUpdate = true;

            final cutoff = now.subtract(const Duration(seconds: 12));
            while (_stepBuffer.isNotEmpty &&
                _stepBuffer.first.isBefore(cutoff)) {
              _stepBuffer.removeFirst();
            }

            if (_stepBuffer.length >= 8) {
              _isWalkingBurst = true;
              _userStats!.startOfDaySteps -= _stepBuffer.length;
              _stepBuffer.clear();
            }
          }
          _lastValidStepTime = now;
        }
      }

      final offset = _userStats!.startOfDaySteps;
      int displaySteps = rawSensorTotal - offset;

      if (displaySteps < 0) {
        _userStats!.startOfDaySteps = rawSensorTotal;
        displaySteps = 0;
        dbNeedsUpdate = true;
      }

      int stepDelta = 0;
      if (!_preferExternalStepTotal && displaySteps != _currentSteps) {
        stepDelta = displaySteps - _currentSteps;
        _currentSteps = displaySteps;
        _userStats!.dailySteps = _currentSteps;
        _userStats!.lastResetDate = now;
        dbNeedsUpdate = true;
        _publish();
      }

      if (dbNeedsUpdate) {
        await _repo!.saveUserStats(_userStats!);
        if (!_preferExternalStepTotal && stepDelta > 0 && _repo != null) {
          final naturalId = int.parse(
              "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}");
          final midnight = DateTime(now.year, now.month, now.day);

          await _repo!.isar.writeTxn(() async {
            final existing = await _repo!.isar.dailyActivitys.get(naturalId);
            final updatedSteps = (existing?.totalSteps ?? _currentSteps) +
                stepDelta;

            final activity = DailyActivity()
              ..id = naturalId
              ..date = midnight
              ..totalSteps = updatedSteps
              ..miles =
                  double.parse((updatedSteps * 0.00047).toStringAsFixed(1))
              ..calories = (updatedSteps * 0.04).toInt();

            await _repo!.isar.dailyActivitys.put(activity);
          });
        }
      }
    } catch (e) {
      debugPrint('[StepService] Step processing error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // MIDNIGHT RESET & ARCHIVE 
  // ---------------------------------------------------------------------------
  void _startMidnightChecker() {
    _midnightCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkMidnightReset();
    });
  }

  void _checkMidnightReset() {
    if (_userStats == null || _repo == null) return;
    final now = DateTime.now();
    final lastReset = _userStats!.lastResetDate;

    if (lastReset != null) {
      final nowDay = DateTime(now.year, now.month, now.day);
      final lastDay = DateTime(lastReset.year, lastReset.month, lastReset.day);

      if (!nowDay.isAtSameMomentAs(lastDay)) {
        _userStats!.lastResetDate = now;
        _handleDayChange(lastDay, nowDay, now, null);
      }
    } else if (lastReset == null) {
      _userStats!.lastResetDate = now;
      _saveCurrentSteps();
    }
  }

  Future<void> _saveCurrentSteps() async {
    if (_userStats == null || _repo == null) return;
    _userStats!.dailySteps = _currentSteps;
    _userStats!.lastResetDate = DateTime.now();
    await _repo!.saveUserStats(_userStats!);
    _publish();
  }

  Future<void> _handleDayChange(
      DateTime lastDay, DateTime nowDay, DateTime now, int? rawSensorTotal) async {
    final archivedSteps = _currentSteps;

    if (archivedSteps > 0) {
      final sessions = await _repo!.getAllSessions();
      final existingLastDay = sessions.where((s) {
        if (s.comboNames?.contains('Daily Steps') ?? false) {
          final d = DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day);
          return d.isAtSameMomentAs(lastDay);
        }
        return false;
      }).lastOrNull;

      if (existingLastDay != null) {
        existingLastDay.steps = archivedSteps;
        existingLastDay.distance = double.parse((archivedSteps * 0.00047).toStringAsFixed(1));
        existingLastDay.calories = double.parse((archivedSteps * 0.04).toStringAsFixed(1));
        await _repo!.saveSession(existingLastDay);
      } else {
        final session = WorkoutSession()
          ..timestamp = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59)
          ..sportType = SportType.custom
          ..steps = archivedSteps
          ..distance = double.parse((archivedSteps * 0.00047).toStringAsFixed(1))
          ..calories = double.parse((archivedSteps * 0.04).toStringAsFixed(1))
          ..heartRateReadings = []
          ..averageBpm = 0
          ..peakBpm = 0
          ..timeInTargetZone = 0
          ..grade = '-'
          ..durationSeconds = 0
          ..comboNames = ['Daily Steps'];
        await _repo!.saveSession(session);
      }
    }

    final sessions = await _repo!.getAllSessions();
    final existingIncomingDay = sessions.where((s) {
      if (s.comboNames?.contains('Daily Steps') ?? false) {
        final d = DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day);
        return d.isAtSameMomentAs(nowDay);
      }
      return false;
    }).lastOrNull;

    if (existingIncomingDay != null) {
      _currentSteps = existingIncomingDay.steps ?? 0;
      _userStats!.startOfDaySteps = 0; 
      await _repo!.deleteSession(existingIncomingDay.id);
    } else {
      _currentSteps = 0;
      _userStats!.startOfDaySteps = rawSensorTotal ?? 0;
    }

    _userStats!.dailySteps = _currentSteps;
    _userStats!.lastResetDate = now;
    await _repo!.saveUserStats(_userStats!);
    _workoutManager?.refreshHistory();
    _publish();
  }

  void _publish() {
    if (!_stepsController.isClosed) {
      _stepsController.add(_currentSteps);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stepSubscription?.cancel();
    _accelSubscription?.cancel();
    _midnightCheckTimer?.cancel();
    _stepsController.close();
    super.dispose();
  }
}
