import 'dart:async';
import 'dart:math' as dart_math;
import 'package:flutter/foundation.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'football_library.dart';
// import 'package:flutter_wearable_data_layer/flutter_wearable_data_layer.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:hilt_mobile/src/services/bike_connector_service.dart';
import 'package:flutter_ftms/flutter_ftms.dart';

// Mock for build success (Connectivity Package Missing)
class WearableDataLayer {
  static void listen(Function(dynamic) callback) {}
}

class WorkoutManager extends ChangeNotifier {
  WorkoutEngine? _engine;
  Timer? _simulationTimer; // Simulator Enabled for Testing

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

  // Recovery
  StreamSubscription? _recoverySubscription;
  int? _endingBpm;
  int? _recoveryScore;

  // FTMS Bike Connectivity
  final _bikeService = BikeConnectorService();
  double _currentSpeedMph = 0.0;
  double _bikeDistanceMiles = 0.0;

  BikeConnectorService get bikeService => _bikeService;
  double get currentSpeedMph => _currentSpeedMph;
  double get bikeDistanceMiles => _bikeDistanceMiles;

  // ...

  void _updateBpm(int bpm) {
    _currentBpm = bpm;
    _lastHeartRateTime = DateTime.now();
    if (_lastState != null && _lastState!.phase == WorkoutPhase.work) {
      _currentSessionReadings.add(bpm);

      // Grade Tracking
      _workIntervalsTotalTime++;
      if (bpm >= _currentProfile.targetHeartRate) {
        _workIntervalsTimeInZone++;
      }

      _checkTargetHit(bpm);
    }

    // Recovery Phase
    if (_recoverySubscription != null) {
      // We are in recovery mode.
      // Logic: Wait 60s? Or just expose current BPM for UI to show recovery?
      // For now, let's just tracking it.
    }

    notifyListeners();
  }

  // ...

  void startWorkout() {
    // Keep screen on
    WakelockPlus.enable();

    // Reset Grade/Recovery State
    _workIntervalsTotalTime = 0;
    _workIntervalsTimeInZone = 0;
    _endingBpm = null;
    _recoveryScore = null;
    _recoverySubscription?.cancel();
    _recoverySubscription = null;

    final bpmStream =
        Stream.periodic(const Duration(seconds: 1), (_) => _currentBpm);

    _engine = WorkoutEngine(
      profile: _currentProfile,
      bpmStream: bpmStream,
    );

    _lowIntensitySeconds = 0;

    _workoutStateSubscription = _engine!.workoutState.listen((state) {
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

    // Simulation Enabled for Emulator Testing
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Simulate BPM between 120 and 160 roughly
      // Use logic to make it look somewhat natural
      final base = 130;
      final variance = 30;
      final time = DateTime.now().millisecondsSinceEpoch / 1000;
      // Sine wave simulation
      final simulated = base + (dart_math.sin(time / 5) * variance).toInt();
      _updateBpm(simulated);
    });
  }

  Future<WorkoutSession?> stopWorkout({bool save = true}) async {
    // 1. Cancel subscription to prevent 'onDone' from triggering auto-save
    await _workoutStateSubscription?.cancel();
    _workoutStateSubscription = null;

    // 2. Stop Engine
    _engine?.stop();
    _simulationTimer?.cancel();
    WakelockPlus.disable();
    _engine = null;
    _lastState = null;

    _endingBpm = _currentBpm;

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

    String grade = 'C';
    if (_workIntervalsTotalTime > 0) {
      final pct = _workIntervalsTimeInZone / _workIntervalsTotalTime;
      if (pct >= 0.9)
        grade = 'A';
      else if (pct >= 0.7) grade = 'B';
    }

    final session = WorkoutSession()
      ..timestamp = DateTime.now()
      ..sportType = _currentProfile.type
      ..heartRateReadings = List.from(_currentSessionReadings)
      ..averageBpm = avg
      ..peakBpm = peak
      ..timeInTargetZone = inZone
      ..grade = grade
      ..endingBpm = _endingBpm;

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
    await _bikeService.scanAndConnect();
  }

  void loadPreset(SportProfile profile) {
    _currentProfile = profile;
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
    _history = _history.reversed.toList();
    notifyListeners();
  }

  Future<void> deleteSession(int id) async {
    await _repo?.deleteSession(id);
    await _loadHistory();
  }

  // Public Getters
  int get currentBpm => _currentBpm;
  WorkoutState? get workoutState => _lastState;
  SportProfile get profile => _currentProfile;
  List<WorkoutSession> get history => _history;
  int? get recoveryScore => _recoveryScore;
  DateTime? get lastHeartRateTime => _lastHeartRateTime;

  DateTime? _lastHeartRateTime;

  // Restore Missing Fields and Constructor
  SportProfile _currentProfile = FootballLibrary.warmup;

  WorkoutState? _lastState;
  int _currentBpm = 0;

  final _player = AudioPlayer();
  final _tts = FlutterTts();

  int _lowIntensitySeconds = 0;
  bool _targetHitChimePlayed = false;

  SessionRepository? _repo;
  final List<int> _currentSessionReadings = [];
  List<WorkoutSession> _history = [];

  WorkoutManager() {
    _initDataLayer();
    _initDb();
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
      if (message.containsKey('bpm')) {
        final bpm = message['bpm'] as int;
        _updateBpm(bpm);
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
