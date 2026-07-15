import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'src/l10n/app_localizations.dart';
import 'src/workout_manager.dart';
import 'src/hydration_manager.dart';
import 'src/screens/dashboard_screen.dart';
import 'src/screens/hydration_tab_shell.dart';
import 'src/screens/history_screen.dart';
import 'src/screens/workout_selection_screen.dart';
import 'src/services/step_service.dart';
import 'src/services/health_sync_service.dart';
import 'src/services/startup_permission_service.dart';

const String _promoInitialTab = String.fromEnvironment(
  'PROMO_INITIAL_TAB',
  defaultValue: 'home',
);

Future<void> main() async {
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
        ChangeNotifierProvider(create: (_) => HydrationManager()),
        ChangeNotifierProxyProvider<WorkoutManager, StepService>(
          lazy: false,
          create: (_) => StepService(),
          update: (_, manager, stepService) {
            stepService!.updateDependencies(manager);
            return stepService;
          },
        ),
        ProxyProvider2<WorkoutManager, StepService, HealthSyncService>(
          lazy: false,
          create: (_) => HealthSyncService(_.read<StepService>()),
          update: (_, manager, stepService, healthService) {
            healthService?.updateDependencies(manager);
            return healthService ?? HealthSyncService(stepService);
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => context.l10n.text('appTitle'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.light,
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
  int _index = _initialTabIndexForPromo(_promoInitialTab);
  bool _didRequestStartupPermissions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enableForegroundWakelock());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_requestStartupPermissions());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_enableForegroundWakelock());
      context.read<HydrationManager>().refreshToday();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(WakelockPlus.disable());
    }
  }

  Future<void> _enableForegroundWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (error) {
      debugPrint('[HiltMobileApp] Unable to keep screen awake: $error');
    }
  }

  Future<void> _requestStartupPermissions() async {
    if (_didRequestStartupPermissions || !mounted) return;
    _didRequestStartupPermissions = true;

    await StartupPermissionService.requestAppStartupPermissions(
      healthSyncService: context.read<HealthSyncService>(),
    );
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
          const HydrationTabShell(),
          const SafeArea(
            child: HistoryScreen(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home),
            label: context.l10n.text('home'),
          ),
          NavigationDestination(
              icon: const Icon(Icons.fitness_center),
              label: context.l10n.text('workouts')),
          NavigationDestination(
            icon: const _HydrationNavIcon(),
            selectedIcon: const _HydrationNavIcon(selected: true),
            label: context.l10n.text('hydration'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: context.l10n.text('history'),
          ),
        ],
      ),
    );
  }
}

int _initialTabIndexForPromo(String value) {
  switch (value.toLowerCase()) {
    case 'workouts':
      return 1;
    case 'hydration':
      return 2;
    case 'history':
      return 3;
    case 'home':
    default:
      return 0;
  }
}

class _HydrationNavIcon extends StatelessWidget {
  const _HydrationNavIcon({this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? const Color(0xFF00897B) : const Color(0xFF2A9D8F);

    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (selected)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFD9F3EE),
                    Color(0xFFAEE4DB),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          Icon(
            selected ? Icons.water_drop_rounded : Icons.water_drop_outlined,
            color: accent,
            size: selected ? 20 : 22,
          ),
          Positioned(
            right: 2,
            top: 3,
            child: Container(
              width: selected ? 6 : 5,
              height: selected ? 6 : 5,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD86C),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
