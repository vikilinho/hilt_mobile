import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'football_library.dart';
// import 'package:flutter_wearable_data_layer/flutter_wearable_data_layer.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:hilt_mobile/src/services/bike_connector_service.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hilt_mobile/src/logic/treadmill_handler.dart';

// Mock for build success (Connectivity Package Missing)
class WearableDataLayer {
  static void listen(Function(dynamic) callback) {}
}

class WorkoutManager extends ChangeNotifier {
  WorkoutEngine? _engine;

  // State for Grade Calculation
  int _workIntervalsTotalTime = 0;
  int _workIntervalsTimeInZone = 0;

  StreamSubscription?
      _workoutStateSubscription; // Explicit subscription management

  // Global Event Stream for UI Navigation
  final _sessionCompleteController =
      StreamController<WorkoutSession>.broadcast();
  Stream<WorkoutSession> get onSessionComplete =>
      _sessionCompleteController.stream;

  // Real-time BPM Stream for Engine
  final _bpmController = StreamController<int>.broadcast();

  // Recovery
  StreamSubscription? _recoverySubscription;
  int? _endingBpm;
  int? _recoveryScore;

  // Strength Tracking
  double _totalVolume = 0.0;
  double _peakStrengthScore = 0.0;
  int _currentSetInBlock = 0; // Track completed sets in current block

  double get totalVolume => _totalVolume;
  double get peakStrengthScore => _peakStrengthScore;
  int get currentSetInBlock => _currentSetInBlock;

  // FTMS Bike Connectivity
  final _bikeService = BikeConnectorService();
  double _currentSpeedMph = 0.0;
  double _bikeDistanceMiles = 0.0;

  BikeConnectorService get bikeService => _bikeService;
  double get currentSpeedMph => _currentSpeedMph;
  double get bikeDistanceMiles => _bikeDistanceMiles;
  List<int> get currentSessionReadings => _currentSessionReadings;

  // Treadmill Speed/Distance Tracking (from Watch)
  final TreadmillHandler _treadmillHandler = TreadmillHandler();

  double? get currentSpeedKmh => _treadmillHandler.currentSpeedKmh;
  double? get cumulativeDistanceKm => _treadmillHandler.cumulativeDistanceKm;
  double? get avgSpeedKmh => _treadmillHandler.avgSpeedKmh;

  // Expose Handler for specific operations
  TreadmillHandler get treadmillHandler => _treadmillHandler;

  // Equipment Selection
  GarageGear _activeEquipment = GarageGear.noEquipment;
  GarageGear get activeEquipment => _activeEquipment;

  // Weekly Goal Logic
  int _weeklyGoal = 5;
  int get weeklyGoal => _weeklyGoal;

  int get weeklySessionsCompleted {
    final now = DateTime.now();
    // Monday of the current week (1 = Mon, 7 = Sun)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    return _history.where((s) => s.timestamp.isAfter(startOfDay)).length;
  }

  double get weeklyProgressPercent {
    if (_weeklyGoal == 0) return 0.0;
    final pct = weeklySessionsCompleted / _weeklyGoal;
    return pct > 1.0 ? 1.0 : pct;
  }

  List<SportProfile> get filteredWorkouts {
    return FootballLibrary.getStrengthPresetsForGear(_activeEquipment);
  }

  void setActiveEquipment(GarageGear gear) async {
    _activeEquipment = gear;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_equipment', gear.name);
  }

  Future<void> _loadSavedEquipment() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('selected_equipment');
    if (saved != null) {
      try {
        _activeEquipment = GarageGear.values.firstWhere((e) => e.name == saved);
        notifyListeners();
      } catch (e) {
        print("Error loading saved equipment: $e");
      }
    }
  }

  // ...

  void _updateBpm(int bpm, {double? speed, double? distance}) {
    _currentBpm = bpm;
    _lastHeartRateTime = DateTime.now();

    // Update treadmill speed/distance if provided
    if (speed != null || distance != null) {
      _treadmillHandler.updateFromWatchMessage({
        'speed': speed,
        'distance': distance,
      });
    }

    // Record Data if workout is active (Engine is running)
    // This allows capturing Warmup, Rest, and Work for the full session chart/avg.
    if (_engine != null) {
      _currentSessionReadings.add(bpm);

      // Grade Tracking (Specific to Work Phase)
      if (_lastState != null && _lastState!.phase == WorkoutPhase.work) {
        _workIntervalsTotalTime++;
        if (bpm >= _currentProfile.targetHeartRate) {
          _workIntervalsTimeInZone++;
        }
        _checkTargetHit(bpm);
      }
    }

    // Feed the engine real-time data
    _bpmController.add(bpm);

    // Recovery Phase
    if (_recoverySubscription != null) {
      // track recovery logic
    }

    notifyListeners();
  }

  // Strength Logging
  void logStrengthSet(double weight, int reps) {
    if (reps <= 0) return;

    // 1. Increment set counter
    _currentSetInBlock++;

    // 2. Calculate Volume
    _totalVolume += weight * reps;

    // 3. Calculate Strength Score (Epley Formula)
    // 1RM = Weight * (1 + Reps/30)
    final epley = weight * (1 + reps / 30.0);
    if (epley > _peakStrengthScore) {
      _peakStrengthScore = epley;
    }

    // 4. Audio Feedback & Rest Timer
    if (_currentProfile.gear == GarageGear.barbell) {
      _tts.speak("Good set. 90 seconds rest starts now. Stay hydrated.");
    } else if (_currentProfile.gear == GarageGear.dumbbells) {
      _tts.speak(
          "Good set. 60 seconds rest. Dumbbell ${_lastState?.blockLabel ?? 'next set'} starts soon. Focus on form and speed!");
    } else {
      _tts.speak(
          "Set logged. Rest for 60 seconds. Stay focused on your heart rate target.");
    }

    // 5. Advance Engine (Transition to Rest Phase which is set to 60s)
    _engine?.completeCurrentSet();

    notifyListeners();
  }

  // ...

  void startWorkout() {
    // Keep screen on
    WakelockPlus.enable();

    // Reset Grade/Recovery/Strength State
    _workIntervalsTotalTime = 0;
    _workIntervalsTimeInZone = 0;
    _endingBpm = null;
    _recoveryScore = null;
    _totalVolume = 0.0;
    _peakStrengthScore = 0.0;
    _currentSetInBlock = 0; // Reset set counter
    _recoverySubscription?.cancel();
    _recoverySubscription = null;

    // Reset Treadmill State
    _treadmillHandler.reset();

    _engine = WorkoutEngine(
      profile: _currentProfile,
      bpmStream: _bpmController.stream,
    );

    _workoutStartTime = DateTime.now();
    _lowIntensitySeconds = 0;

    _workoutStateSubscription = _engine!.workoutState.listen((state) {
      // Reset set counter when advancing to a new block
      if (_lastState != null && _lastState!.blockLabel != state.blockLabel) {
        _currentSetInBlock = 0;
      }

      _handleAudio(state);
      _lastState = state;
      notifyListeners();
    }, onDone: () {
      // Auto-Save when engine finishes
      print("[Mobile] Workout Finished. Auto-saving...");
      stopWorkout(save: true);
    });

    _engine!.start();
    _currentSessionReadings.clear();

    // Simulation logic removed for production
  }

  Future<WorkoutSession?> stopWorkout({bool save = true}) async {
    // 1. Cancel subscription to prevent 'onDone' from triggering auto-save
    await _workoutStateSubscription?.cancel();
    _workoutStateSubscription = null;

    // 2. Stop Engine
    _engine?.stop();

    WakelockPlus.disable();
    _engine = null;
    _lastState = null;

    _endingBpm = _currentBpm;
    _hasUserSelectedProfile = false; // Reset selection to return to Hub

    if (save) {
      final session = await _saveSession();
      if (session != null) {
        _sessionCompleteController.add(session);
      }
      return session;
    }
    notifyListeners();
    return null;
  }

  Future<WorkoutSession?> _saveSession() async {
    print("[Storage] Saving session...");

    double avg = 0;
    int peak = 0;
    int inZone = 0;

    if (_currentSessionReadings.isNotEmpty) {
      avg = _currentSessionReadings.reduce((a, b) => a + b) /
          _currentSessionReadings.length;
      peak = _currentSessionReadings.reduce((a, b) => a > b ? a : b);
      inZone = _currentSessionReadings
          .where((bpm) => bpm >= _currentProfile.targetHeartRate)
          .length;
    }

    // Calculate Cardio Load
    double cardioLoad = 0.0;
    if (_currentSessionReadings.isNotEmpty) {
      double totalPoints = 0;
      final target = _currentProfile.targetHeartRate.toDouble();

      for (final bpm in _currentSessionReadings) {
        final pct = bpm / target;
        if (pct >= 1.0) {
          totalPoints += 5.0; // Extreme
        } else if (pct >= 0.9) {
          totalPoints += 4.0; // Very Hard
        } else if (pct >= 0.8) {
          totalPoints += 3.0; // Hard
        } else if (pct >= 0.7) {
          totalPoints += 2.0; // Moderate
        } else if (pct >= 0.6) {
          totalPoints += 1.0; // Light
        } else {
          totalPoints += 0.0; // Very Light
        }
      }
      // Normalize: Points per minute
      // Since readings are roughly 1 per second (depending on update rate),
      // we divide total points by 60 to get a "Load unit" comparable to TRIMP-like scores over minutes.
      // Adjust this divisor if update rate is not 1Hz.
      // Assuming _updateBpm is called ~1Hz from watch.
      cardioLoad = totalPoints / 60.0;
    }

    String grade = 'C';

    // Barbell Grading Logic
    if (_currentProfile.gear == GarageGear.barbell) {
      // If HR stays above 140 during session (Average > 140)
      if (avg >= 140) {
        grade = 'B'; // Or logic for B/C
      }
    } else if (_currentProfile.gear == GarageGear.dumbbells) {
      // Dumbbell Grading: High Intensity (150+)
      if (avg >= 150) {
        grade = 'A';
      } else {
        grade = 'B';
      }
    } else if (_currentProfile.gear == GarageGear.treadmill) {
      // Treadmill Grading: 80% of time in target zone
      // Calculation based on Total Workout Duration (excluding warmup if possible, but simplicity: Total Time)
      // Or based on Work Intervals if defined.
      // User Req: "80% of the duration"
      // We'll use _workIntervalsTotalTime if > 0, else total session readings count.
      int totalTime = _workIntervalsTotalTime > 0
          ? _workIntervalsTotalTime
          : _currentSessionReadings.length;
      int zoneTime = _workIntervalsTimeInZone > 0
          ? _workIntervalsTimeInZone
          : inZone; // Fallback to all-session in-zone

      if (totalTime > 0) {
        final pct = zoneTime / totalTime;
        if (pct >= 0.8) {
          grade = 'A';
        } else if (pct >= 0.6) {
          grade = 'B';
        }
      }
    } else {
      // Existing Logic
      if (_workIntervalsTotalTime > 0) {
        final pct = _workIntervalsTimeInZone / _workIntervalsTotalTime;
        if (pct >= 0.9)
          grade = 'A';
        else if (pct >= 0.7) grade = 'B';
      }
    }

    final session = WorkoutSession()
      ..timestamp = DateTime.now()
      ..sportType = _currentProfile.type
      ..heartRateReadings = List.from(_currentSessionReadings)
      ..averageBpm = avg
      ..peakBpm = peak
      ..timeInTargetZone = inZone
      ..grade = grade
      ..cardioLoad = double.parse(cardioLoad.toStringAsFixed(1))
      ..totalVolume = double.parse(_totalVolume.toStringAsFixed(1))
      ..peakStrengthScore = double.parse(_peakStrengthScore.toStringAsFixed(1))
      ..endingBpm = _endingBpm
      ..durationSeconds = _workoutStartTime != null
          ? DateTime.now().difference(_workoutStartTime!).inSeconds
          : null
      ..distance = _treadmillHandler.cumulativeDistanceKm
      ..avgSpeed =
          _treadmillHandler.avgSpeedKmh; // Save last recorded speed as average

    try {
      await _repo?.saveSession(session);
      print("[Storage] Session saved: ${session.id}");
    } catch (e) {
      print("[Storage] Error saving session: $e");
    }

    await _loadHistory();
    return session;
  }

  void startRecoveryTracking(int sessionId) {
    _recoverySubscription?.cancel();
    Timer(const Duration(seconds: 60), () async {
      _recoverySubscription?.cancel();
      _recoverySubscription = null;

      if (_endingBpm != null) {
        _recoveryScore = _endingBpm! - _currentBpm;
      }
      notifyListeners();
    });
  }

  void _handleAudio(WorkoutState state) async {
    // ... (Existing Logic) ...

    // 2. Countdown (3-2-1) before Work
    if (state.phase == WorkoutPhase.rest &&
        state.timeRemaining <= 3 &&
        state.timeRemaining > 0) {
      _tts.speak("${state.timeRemaining}");
    }

    // 3. Match Sim: 10m Warning
    if (state.coachAudio == 'match_sim_half' &&
        state.currentIntervalIndex == 21 &&
        state.phase == WorkoutPhase.work &&
        state.timeRemaining == 15) {
      if (_lastState?.currentIntervalIndex != 21) {
        _tts.speak("Keep your focus, 10 minutes left in the game");
      }
    }

    // 4. Garage Gear Audio Cues
    // Treadmill: "Hop on the belt"
    if (_currentProfile.gear == GarageGear.treadmill &&
        state.phase == WorkoutPhase.rest &&
        state.timeRemaining == 3) {
      _tts.speak("Hop on the belt, sprint coming up");
    }

    // Hammer: "Explosive Power"
    if (state.coachAudio == 'explosive_power' &&
        state.phase == WorkoutPhase.work &&
        state.timeRemaining == state.currentPhaseDuration) {
      _tts.speak("Smash it! Explosive power!");
    }

    // Dumbbell: Switch Legs (Lunges)
    if (state.coachAudio == 'switch_legs_halfway' &&
        state.phase == WorkoutPhase.work &&
        state.timeRemaining == (state.currentPhaseDuration / 2).round()) {
      _tts.speak("Switch legs!");
    }

    // Dumbbells: "Leg Drive"
    if (state.coachAudio == 'leg_drive' &&
        state.phase == WorkoutPhase.work &&
        state.timeRemaining == state.currentPhaseDuration) {
      _tts.speak("Drive through the heels! Speed up!");
    }

    // No-Equipment: Exercise start prompt (speed emphasis)
    if (_currentProfile.gear == GarageGear.noEquipment &&
        state.phase == WorkoutPhase.work &&
        state.timeRemaining == state.currentPhaseDuration &&
        _lastState?.phase != WorkoutPhase.work) {
      final exerciseName = _currentProfile.displayName;
      _tts.speak("$exerciseName starts now. Speed is key for the Match Grade!");
    }

    // No-Equipment: 10s countdown for Burpees and Mountain Climbers
    if (_currentProfile.gear == GarageGear.noEquipment &&
        state.phase == WorkoutPhase.work &&
        state.timeRemaining == 10) {
      final exerciseName = _currentProfile.displayName;
      if (exerciseName.contains('Burpees') ||
          exerciseName.contains('Mountain Climbers')) {
        _tts.speak("Sprint finish! Drive the knees!");
      }
    }

    // 4. "Two Laps Left" Logic
    // Trigger when we are starting the 2nd to last interval (e.g. 9/10)
    // index is 1-based.
    // If total=10. current=9.
    // We want to verify we haven't spoken it yet for this index.
    if (state.phase == WorkoutPhase.work &&
        state.totalIntervalsInBlock > 0 &&
        state.currentIntervalIndex == state.totalIntervalsInBlock - 1) {
      // Only speak once at start of this interval (e.g. first 5 seconds)
      // Or check if index changed.
      if (_lastState?.currentIntervalIndex != state.currentIntervalIndex) {
        _tts.speak("Keep going, two more laps");
      }
    }

    // 5. Motivation
    if (state.phase == WorkoutPhase.work && state.isBelowTarget) {
      _lowIntensitySeconds++;
      if (_lowIntensitySeconds % 10 == 0) {
        _tts.speak("Push harder to reach target");
      }
    }

    // 6. Treadmill Specific Audio
    if (_currentProfile.gear == GarageGear.treadmill) {
      // Calculate elapsed time from state
      final elapsedSeconds =
          state.workoutTotalDuration - state.workoutTimeRemaining;

      // Every 5 minutes (300 seconds)
      // Check if elapsed time is a multiple of 300 and we haven't spoken yet this second
      if (elapsedSeconds > 0 && elapsedSeconds % 300 == 0) {
        _tts.speak("Check your pace. Keep your heart rate in the elite zone.");
      }

      // Blitz Finish: 10s warning
      if (state.coachAudio == 'blitz_finish_interval' &&
          state.phase == WorkoutPhase.work &&
          state.timeRemaining == 10) {
        _tts.speak("Max speed! 10 kilometers per hour drive!");
      }
    }
  }

  // Audio Logic: Chime when below target
  void _checkTargetHit(int bpm) {
    // User requested chime when heart beat is BELOW target
    // Chime disabled for now
  }

  // Future<void> _playWhistle() async {
  //   print("[Audio] Playing Whistle");
  //   try {
  //     await _player.play(AssetSource('sounds/whistle.mp3'));
  //   } catch (e) {
  //     print("[Audio] Error playing whistle: $e");
  //   }
  // }

  void setProfile(SportType type) {
    switch (type) {
      case SportType.football:
        _currentProfile = _currentProfile.copyWith(
          type: SportType.football,
          workDuration: 20,
          restDuration: 30,
          targetHeartRate: 150,
        );
        break;
      case SportType.boxing:
        _currentProfile = _currentProfile.copyWith(
            type: SportType.boxing,
            workDuration: 180,
            restDuration: 60,
            targetHeartRate: 160);
        break;
      case SportType.cycling:
        _currentProfile = _currentProfile.copyWith(
            type: SportType.cycling,
            workDuration: 60,
            restDuration: 60,
            targetHeartRate: 140);
        break;
      case SportType.custom:
        _currentProfile = _currentProfile.copyWith(
            type: SportType.custom,
            workDuration: 45,
            restDuration: 15,
            targetHeartRate: 140);
        break;
    }
    notifyListeners();
  }

  Future<void> connectToBike() async {
    // Only connect if gear is set to Bike or None (Default)
    if (_currentProfile.gear == GarageGear.bike ||
        _currentProfile.gear == GarageGear.none) {
      await _bikeService.scanAndConnect();
      notifyListeners(); // Force UI update after connection attempt
    } else {
      print(
          "[Mobile] Skipping bike scan for manual gear: ${_currentProfile.gear}");
    }
  }

  void loadPreset(SportProfile profile) {
    _currentProfile = profile;
    _hasUserSelectedProfile = true;
    notifyListeners();
  }

  void updateTargetHeartRate(int newTarget) {
    _currentProfile = _currentProfile.copyWith(targetHeartRate: newTarget);
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    print("[Storage] Loading history...");
    try {
      _history = await _repo?.getAllSessions() ?? [];
      print("[Storage] Loaded ${_history.length} sessions");
    } catch (e) {
      print("[Storage] Error loading history: $e");
    }
    _history = _history.toList();
    notifyListeners();
  }

  Future<void> deleteSession(int id) async {
    await _repo?.deleteSession(id);
    await _loadHistory();
  }

  Future<void> updateSessionStats(
      int sessionId, double? distance, double? incline) async {
    try {
      final session = _history.firstWhere((s) => s.id == sessionId);
      session.distance = distance;
      session.incline = incline;
      await _repo?.saveSession(session);
      await _loadHistory();
    } catch (e) {
      print("[Mobile] Error updating session stats: $e");
    }
  }

  // Public Getters
  int get currentBpm => _currentBpm;
  WorkoutState? get workoutState => _lastState;
  SportProfile get profile => _currentProfile;
  List<WorkoutSession> get history => _history;
  int? get recoveryScore => _recoveryScore;
  DateTime? get lastHeartRateTime => _lastHeartRateTime;
  bool get hasUserSelectedProfile => _hasUserSelectedProfile;

  DateTime? _lastHeartRateTime;
  DateTime? _workoutStartTime;

  // Restore Missing Fields and Constructor
  SportProfile _currentProfile = FootballLibrary.warmup;

  WorkoutState? _lastState;
  int _currentBpm = 0;

  final _tts = FlutterTts();

  int _lowIntensitySeconds = 0;

  SessionRepository? _repo;
  final List<int> _currentSessionReadings = [];
  List<WorkoutSession> _history = [];
  bool _hasUserSelectedProfile =
      false; // Track if user explicitly selected a workout

  WorkoutManager() {
    _initDataLayer();
    _initDb();
    _loadSavedEquipment();
  }

  Future<void> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [WorkoutSessionSchema],
      directory: dir.path,
    );
    _repo = SessionRepository(isar);
    await _loadHistory();
  }

  void _initDataLayer() {
    print("[Mobile] Initializing Watch Connectivity...");
    WatchConnectivity().messageStream.listen((message) {
      if (message.containsKey('bpm') && message['bpm'] is int) {
        final bpm = message['bpm'] as int;
        print("[Mobile] Received BPM: $bpm");

        // Optional: Extract speed and distance if available
        double? speed;
        double? distance;

        if (message.containsKey('speed') && message['speed'] != null) {
          speed = (message['speed'] as num).toDouble();
          print("[Mobile] Received Speed: $speed km/h");
        }

        if (message.containsKey('distance') && message['distance'] != null) {
          distance = (message['distance'] as num).toDouble();
          print("[Mobile] Received Distance: $distance km");
        }

        _updateBpm(bpm, speed: speed, distance: distance);
      }
    });

    _bikeService.dataStream.listen((data) {
      final speedParam =
          data.getParameterValueByName(DeviceDataParameterName.instSpeed);
      if (speedParam != null) {
        final kph = (speedParam.value * speedParam.factor).toDouble();
        _currentSpeedMph = kph * 0.621371;
      }

      final distParam =
          data.getParameterValueByName(DeviceDataParameterName.totalDistance);
      if (distParam != null) {
        final meters = (distParam.value * distParam.factor).toDouble();
        _bikeDistanceMiles = meters * 0.000621371;
      }
      notifyListeners();
    });
  }
}
