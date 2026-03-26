import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'dart:async';

class StepService extends ChangeNotifier with WidgetsBindingObserver {
  SessionRepository? _repo;
  UserStats? _userStats;
  StreamSubscription? _stepSubscription;
  Timer? _midnightCheckTimer;

  int _currentSteps = 0;

  int get dailySteps => _currentSteps;
  int get stepGoal => _userStats?.stepGoal ?? 10000;
  bool get isMatchReady => dailySteps >= stepGoal;

  StepService() {
    _startMidnightChecker();
    WidgetsBinding.instance.addObserver(this);
  }

  void updateRepo(SessionRepository? repo) {
    if (_repo == null && repo != null) {
      _repo = repo;
      _initService();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshFromIsar();
    }
  }

  Future<void> _refreshFromIsar() async {
    if (_repo == null) return;
    _userStats = await _repo!.getUserStats();
    if (_userStats != null && _userStats!.dailySteps != _currentSteps) {
      _currentSteps = _userStats!.dailySteps;
      notifyListeners(); // This triggers the Catch-up animation seamlessly
    }
  }

  Future<void> _initService() async {
    if (_repo == null) return;
    
    // Check and request activity recognition permission
    if (await Permission.activityRecognition.isDenied) {
      await Permission.activityRecognition.request();
    }

    await _refreshFromIsar();
    _checkMidnightReset();

    // Start listening to pedometer
    _stepSubscription = Pedometer.stepCountStream.listen((StepCount event) {
      _handleNewSensorValue(event.steps);
    }, onError: (error) {
      print("Step Sensor Error: \$error");
    });
  }

  Future<void> _handleNewSensorValue(int totalSensorSteps) async {
    final prefs = await SharedPreferences.getInstance();
    int? savedLast = prefs.getInt('last_sensor_steps');

    if (savedLast == null) {
      await prefs.setInt('last_sensor_steps', totalSensorSteps);
      return;
    }

    int diff = totalSensorSteps - savedLast;
    if (diff < 0) {
      // Sensor reset, likely device reboot
      diff = totalSensorSteps;
    }

    if (diff > 0) {
      _currentSteps += diff;
      await prefs.setInt('last_sensor_steps', totalSensorSteps);
      
      _checkMidnightReset();
      _saveCurrentSteps();
    }
  }

  Future<void> _saveCurrentSteps() async {
    if (_userStats != null && _repo != null) {
      _userStats!.dailySteps = _currentSteps;
      _userStats!.lastResetDate = DateTime.now();
      await _repo!.saveUserStats(_userStats!);
      notifyListeners();
    }
  }

  void _startMidnightChecker() {
    _midnightCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkMidnightReset();
    });
  }

  void _checkMidnightReset() {
    if (_userStats == null || _repo == null) return;

    final now = DateTime.now();
    final lastReset = _userStats!.lastResetDate;

    if (lastReset != null) {
      if (now.year != lastReset.year || now.month != lastReset.month || now.day != lastReset.day) {
        _performResetAndArchive(lastReset);
      }
    } else {
      _userStats!.lastResetDate = now;
      _saveCurrentSteps();
    }
  }

  Future<void> _performResetAndArchive(DateTime dateToArchive) async {
    final archivedSteps = _currentSteps;
    
    _currentSteps = 0;
    _userStats!.dailySteps = 0;
    _userStats!.lastResetDate = DateTime.now();
    await _repo!.saveUserStats(_userStats!);

    if (archivedSteps > 0) {
      final session = WorkoutSession()
        ..timestamp = DateTime(dateToArchive.year, dateToArchive.month, dateToArchive.day, 23, 59)
        ..sportType = SportType.custom
        ..steps = archivedSteps
        ..heartRateReadings = []
        ..averageBpm = 0
        ..peakBpm = 0
        ..timeInTargetZone = 0
        ..grade = '-'
        ..durationSeconds = 0
        ..comboNames = ['Daily Steps'];
        
      await _repo!.saveSession(session);
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stepSubscription?.cancel();
    _midnightCheckTimer?.cancel();
    super.dispose();
  }
}
