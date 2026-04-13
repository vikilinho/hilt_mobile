import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/workout_manager.dart';
import 'src/screens/dashboard_screen.dart';
import 'src/screens/history_screen.dart';
import 'src/screens/workout_selection_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'src/services/step_service.dart';
import 'src/services/health_sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        ProxyProvider2<WorkoutManager, StepService, HealthSyncService>(
          create: (_) => HealthSyncService(_.read<StepService>()),
          update: (_, manager, stepService, healthService) {
             healthService?.updateDependencies(manager);
             return healthService ?? HealthSyncService(stepService);
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<WorkoutManager>().syncStepHistory();
      context.read<HealthSyncService>().fetchDailySteps();
    }
  }

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
          const SafeArea(
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
