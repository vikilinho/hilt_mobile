import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';
import '../workout_manager.dart';

/// Step-tracking service using the industry-standard **Daily Offset** pattern.
///
/// `TYPE_STEP_COUNTER` emits a monotonically-increasing total since the last
/// device reboot. On the **first sensor event of each calendar day** we store
/// that raw value as [UserStats.startOfDaySteps] (the "anchor"). Every
/// subsequent event within the same day computes:
///
///   displaySteps = rawSensorTotal − startOfDaySteps
///
/// This is exactly how Google Fit and Fitbit calibrate their step counts and
/// naturally survives reboots, midnight-crossings, and foreground/background
/// transitions without any drift.
///
/// Battery: the `pedometer` package wraps Android's `TYPE_STEP_COUNTER` which
/// is handled entirely in the low-power hardware step chip — no wakelock is
/// required and CPU usage is negligible.
class StepService extends ChangeNotifier with WidgetsBindingObserver {
  SessionRepository? _repo;
  UserStats? _userStats;
  StreamSubscription<StepCount>? _stepSubscription;
  Timer? _midnightCheckTimer;

  // Internal broadcast stream so widgets can subscribe without rebuilding
  // the entire screen on every step event.
  final _stepsController = StreamController<int>.broadcast();

  /// Live stream of today's display step count.
  /// Widgets should prefer `StreamBuilder<int>(stream: stepService.stepsStream)`
  /// over `context.watch<StepService>()` to limit rebuild scope.
  Stream<int> get stepsStream => _stepsController.stream;

  int _currentSteps = 0;

  int get dailySteps => _currentSteps;
  int get stepGoal => _userStats?.stepGoal ?? 10000;
  bool get isMatchReady => dailySteps >= stepGoal;

  WorkoutManager? _workoutManager;

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

  // ---------------------------------------------------------------------------
  // App lifecycle
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-read Isar so we have the latest persisted values. The sensor stream
      // will fire a fresh event within milliseconds and self-correct via
      // _handleNewSensorValue, so there is no need to do anything heavier here.
      _refreshFromIsar();
      _checkMidnightReset();
      _workoutManager?.refreshHistory();
    }
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> _initService() async {
    if (_repo == null) return;

    if (await Permission.activityRecognition.isDenied) {
      await Permission.activityRecognition.request();
    }

    await _refreshFromIsar();
    _checkMidnightReset();

    // Subscribe to the hardware step-chip stream. Each event carries the
    // cumulative total since the last device reboot.
    _stepSubscription =
        Pedometer.stepCountStream.listen((StepCount event) {
      _handleNewSensorValue(event.steps);
    }, onError: (error) {
      debugPrint('[StepService] Sensor error: $error');
    });
  }

  Future<void> _refreshFromIsar() async {
    if (_repo == null) return;
    _userStats = await _repo!.getUserStats();
    final persisted = _userStats?.dailySteps ?? 0;
    if (persisted != _currentSteps) {
      _currentSteps = persisted;
      _publish();
    }
  }

  // ---------------------------------------------------------------------------
  // Daily Offset calibration
  // ---------------------------------------------------------------------------

  /// Called on every sensor tick. [rawSensorTotal] is the device's cumulative
  /// step count since the last reboot — it never resets mid-day on its own.
  Future<void> _handleNewSensorValue(int rawSensorTotal) async {
    if (_userStats == null || _repo == null) return;

    final now = DateTime.now();
    final lastReset = _userStats!.lastResetDate;

    // --- 1. Midnight / new-day check ---
    if (lastReset != null) {
      final nowDay = DateTime(now.year, now.month, now.day);
      final lastDay = DateTime(lastReset.year, lastReset.month, lastReset.day);

      if (!nowDay.isAtSameMomentAs(lastDay)) {
        _userStats!.lastResetDate = now;
        await _handleDayChange(lastDay, nowDay, now, rawSensorTotal);
        return;
      }
    } else {
      _currentSteps = 0;
      _userStats!.dailySteps = 0;
      _userStats!.lastResetDate = now;
      _userStats!.startOfDaySteps = rawSensorTotal;
      await _repo!.saveUserStats(_userStats!);
      _publish();
      return;
    }

    // --- 2. Daily Offset: first sync of the day ---
    // If startOfDaySteps is 0, we must initialise it carefully.
    if (_userStats!.startOfDaySteps == 0 && rawSensorTotal > 0) {
      // If we loaded pre-existing steps (e.g. from history), the anchor MUST
      // be lowered by exactly that amount so `displaySteps` mathematically resumes.
      int newAnchor = rawSensorTotal - _userStats!.dailySteps;
      if (newAnchor < 0) newAnchor = 0;
      _userStats!.startOfDaySteps = newAnchor;
      await _repo!.saveUserStats(_userStats!);
    }

    // --- 3. Compute display steps via offset ---
    final offset = _userStats!.startOfDaySteps;
    int displaySteps = rawSensorTotal - offset;

    // Handle edge case: sensor reset (e.g., reboot mid-day) where rawSensorTotal
    // drops below the stored offset. Treat post-reboot raw value as new delta.
    if (displaySteps < 0) {
      _userStats!.startOfDaySteps = rawSensorTotal;
      displaySteps = 0;
      await _repo!.saveUserStats(_userStats!);
    }

    if (displaySteps != _currentSteps) {
      _currentSteps = displaySteps;
      await _saveCurrentSteps();
    }
  }

  Future<void> _saveCurrentSteps() async {
    if (_userStats == null || _repo == null) return;
    _userStats!.dailySteps = _currentSteps;
    _userStats!.lastResetDate = DateTime.now();
    await _repo!.saveUserStats(_userStats!);
    _publish();
  }

  // ---------------------------------------------------------------------------
  // Midnight reset & archiving
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
        // Guard against double entry from timer
        _userStats!.lastResetDate = now; 
        _handleDayChange(lastDay, nowDay, now, null);
      }
    } else if (lastReset == null) {
      _userStats!.lastResetDate = now;
      _saveCurrentSteps();
    }
  }

  Future<void> _handleDayChange(
      DateTime lastDay, DateTime nowDay, DateTime now, int? rawSensorTotal) async {
    final archivedSteps = _currentSteps;

    // 1. Archive the outgoing day's steps
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

    // 2. Load the incoming day's steps (if any exist)
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
      // Wipe the offset anchor so the next sensor tick recalibrates it dynamically
      _userStats!.startOfDaySteps = 0; 
      await _repo!.deleteSession(existingIncomingDay.id);
    } else {
      _currentSteps = 0;
      _userStats!.startOfDaySteps = rawSensorTotal ?? 0;
    }

    // 3. Reset boundaries
    _userStats!.dailySteps = _currentSteps;
    _userStats!.lastResetDate = now;
    await _repo!.saveUserStats(_userStats!);
    _workoutManager?.refreshHistory();
    _publish();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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
    _midnightCheckTimer?.cancel();
    _stepsController.close();
    super.dispose();
  }
}
