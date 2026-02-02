import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/workout_manager.dart';
import 'src/screens/dashboard_screen.dart';
import 'src/screens/history_screen.dart';

import 'package:google_fonts/google_fonts.dart';

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
      ],
      child: MaterialApp(
        title: 'Hilt Mobile',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.green,
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

  final _screens = const [
    DashboardScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HILT KING"),
        leading: _index != 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _index = 0),
              )
            : null,
      ),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.timer), label: 'Timer'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
