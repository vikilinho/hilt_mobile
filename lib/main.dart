import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/workout_manager.dart';
import 'src/screens/dashboard_screen.dart';
import 'src/screens/history_screen.dart';
import 'src/screens/workout_selection_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'src/services/step_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hilt_core/hilt_core.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final event = await Pedometer.stepCountStream.first;
      final currentSensorSteps = event.steps;

      int? savedLast = prefs.getInt('last_sensor_steps');
      if (savedLast == null) {
        // Initial boot/install: Save the baseline and exit gracefully
        await prefs.setInt('last_sensor_steps', currentSensorSteps);
        return Future.value(true);
      }

      int delta = currentSensorSteps - savedLast;

      if (delta < 0) {
        // Device rebooted, sensor reset to 0
        delta = currentSensorSteps;
      }

      if (delta > 0) {
        final dir = await getApplicationDocumentsDirectory();
        final isar = await Isar.open(
          [WorkoutSessionSchema, UserStatsSchema],
          directory: dir.path,
        );
        final repo = SessionRepository(isar);
        final stats = await repo.getUserStats();

        final now = DateTime.now();
        final lastReset = stats.lastResetDate;

        if (lastReset != null && 
            (now.day != lastReset.day || 
             now.month != lastReset.month || 
             now.year != lastReset.year)) {
          
          // Archive the previous day's steps before resetting
          if (stats.dailySteps > 0) {
            final session = WorkoutSession()
              ..timestamp = DateTime(lastReset.year, lastReset.month, lastReset.day, 23, 59)
              ..sportType = SportType.custom
              ..steps = stats.dailySteps
              ..heartRateReadings = []
              ..averageBpm = 0
              ..peakBpm = 0
              ..timeInTargetZone = 0
              ..grade = '-'
              ..durationSeconds = 0
              ..comboNames = ['Daily Steps'];
            await repo.saveSession(session);
          }

          stats.dailySteps = delta;
          stats.lastResetDate = now;
        } else {
          stats.dailySteps += delta;
        }

        await repo.saveUserStats(stats);
        await prefs.setInt('last_sensor_steps', currentSensorSteps);
      }
    } catch (e) {
      print("[WorkManager] Error: $e");
    }
    return Future.value(true);
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
  Workmanager().registerPeriodicTask(
    "step_sync_task",
    "background_step_sync",
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: true,
      requiresDeviceIdle: false,
    ),
  );
  runApp(const HiltMobileApp());
}

class HiltMobileApp extends StatelessWidget {
  const HiltMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkoutManager()),
        ChangeNotifierProxyProvider<WorkoutManager, StepService>(
          create: (_) => StepService(),
          update: (_, manager, stepService) {
            stepService!.updateDependencies(manager);
            return stepService;
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Hilt Mobile',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.light,
          textTheme: GoogleFonts.interTextTheme(),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            onRequestWorkoutSelection: () => setState(() => _index = 1),
          ),
          SafeArea(
            child: WorkoutSelectionScreen(
              onWorkoutStarted: () => setState(() => _index = 0),
              isVisible: _index == 1,
            ),
          ),
          SafeArea(
            child: HistoryScreen(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center), label: 'Workouts'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
