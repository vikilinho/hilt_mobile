import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hilt_core/hilt_core.dart';
import '../workout_manager.dart';
import '../football_library.dart';
import '../services/bike_connector_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class WorkoutSelectionScreen extends StatefulWidget {
  final VoidCallback onWorkoutStarted;
  final bool isSelectionMode;

  const WorkoutSelectionScreen({
    super.key,
    required this.onWorkoutStarted,
    this.isSelectionMode = false,
    this.isVisible = true,
  });

  final bool isVisible;

  @override
  State<WorkoutSelectionScreen> createState() => _WorkoutSelectionScreenState();
}

class _WorkoutSelectionScreenState extends State<WorkoutSelectionScreen>
    with TickerProviderStateMixin {
  // 0: Category Selection, 1: Drill Selection
  int _step = 0;
  List<SportProfile> _currentList = [];
  String _categoryTitle = "";

  // Animation controllers for entrance
  late AnimationController _cardioController;
  late AnimationController _strengthController;
  late AnimationController _listController; // Controller for sub-category lists
  late Animation<double> _cardioSlide;
  late Animation<double> _cardioFade;
  late Animation<double> _strengthSlide;
  late Animation<double> _strengthFade;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _cardioController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _strengthController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _listController = AnimationController(
      duration: const Duration(
          milliseconds: 600), // Slightly longer for staggered list
      vsync: this,
    );

    // Create slide animations (30px up)
    _cardioSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _cardioController, curve: Curves.easeOut),
    );

    _strengthSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _strengthController, curve: Curves.easeOut),
    );

    // Create fade animations
    _cardioFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardioController, curve: Curves.easeIn),
    );

    _strengthFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _strengthController, curve: Curves.easeIn),
    );

    // Start initial animations
    _playEntranceAnimations();
  }

  void _playEntranceAnimations() {
    // Reset and play animations
    _cardioController.reset();
    _strengthController.reset();

    _cardioController.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _strengthController.forward();
    });
  }

  @override
  void dispose() {
    _cardioController.dispose();
    _strengthController.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(WorkoutSelectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isVisible && widget.isVisible && _step == 0) {
      _playEntranceAnimations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Custom Header (Only for sub-pages)
        if (_step > 0)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_step == 2) {
                        _step =
                            1; // Back to Sub-Category (Equipment or Cardio Type)
                        // Reset Title Base
                        if (_categoryTitle.contains("Strength")) {
                          _categoryTitle = "Strength";
                        } else {
                          _categoryTitle = "Cardio";
                        }
                      } else {
                        _step = 0; // Back to Main Category
                        // Replay entrance animations
                        Future.microtask(() => _playEntranceAnimations());
                      }
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
                Text(
                  _categoryTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),

        // Main Content
        Expanded(
          child: _step == 0
              ? _buildCategories()
              : _step == 1
                  ? (_categoryTitle == "Cardio"
                      ? _buildCardioSelector()
                      : _buildEquipmentSelector())
                  : _buildDrillList(),
        ),
      ],
    );
  }

  Widget _buildCategories() {
    return ListView(
      padding: EdgeInsets.zero, // Padding handled internally
      children: [
        // Hero Heading
        Padding(
          padding: const EdgeInsets.only(top: 60, left: 25, bottom: 40),
          child: Text(
            "SELECT TRAINING",
            style: const TextStyle(
              fontFamily:
                  'Classic', // Assuming Classic font is available, else fallback
              fontWeight: FontWeight.bold,
              fontSize: 30,
              letterSpacing: 1.5,
            ),
          ),
        ),

        // Animated Cardio Card
        AnimatedBuilder(
          animation: _cardioController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _cardioSlide.value),
              child: Opacity(
                opacity: _cardioFade.value,
                child: child,
              ),
            );
          },
          child: RepaintBoundary(
            child: _CategoryCard(
              title: "Cardio",
              subtitle: "Bike, Running, Football",
              icon: Icons.directions_run,
              gradient: const LinearGradient(
                colors: [Colors.green, Colors.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              primaryColor: Colors.green,
              onTap: () {
                setState(() {
                  _categoryTitle = "Cardio";
                  _step = 1; // Go to Cardio Type Selector
                  _listController.forward(from: 0); // Trigger list animation
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 20), // Increased spacing

        // Animated Strength Card
        AnimatedBuilder(
          animation: _strengthController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _strengthSlide.value),
              child: Opacity(
                opacity: _strengthFade.value,
                child: child,
              ),
            );
          },
          child: RepaintBoundary(
            child: _CategoryCard(
              title: "Strength",
              subtitle: "Weights, Power, Explosiveness",
              icon: Icons.fitness_center,
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.indigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              primaryColor: Colors.blue,
              onTap: () {
                setState(() {
                  _categoryTitle = "Strength";
                  _step = 1; // Go to Equipment Selector
                  _listController.forward(from: 0); // Trigger list animation
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 24), // Bottom padding
      ],
    );
  }

  Widget _buildCardioSelector() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildAnimatedItem(
          _CategoryCard(
            title: "Stationary Bike",
            subtitle: "Match Sim, Box-to-Box",
            icon: Icons.directions_bike,
            gradient: const LinearGradient(
              colors: [Colors.purple, Colors.deepPurpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            primaryColor: Colors.purple,
            onTap: () => _selectCardioType(FootballLibrary.bikePresets, "Bike"),
            enableShine: false,
          ),
          0,
        ),
        const SizedBox(height: 16),
        _buildAnimatedItem(
          _CategoryCard(
            title: "Treadmill",
            subtitle: "Sprints, Intervals",
            icon: Icons.directions_run,
            gradient: const LinearGradient(
              colors: [Colors.blueGrey, Colors.black87],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            primaryColor: Colors.blueGrey,
            onTap: () => _selectCardioType(
                FootballLibrary.treadmillPresets, "Treadmill"),
            enableShine: false,
          ),
          1,
        ),
        const SizedBox(height: 16),
        _buildAnimatedItem(
          _CategoryCard(
            title: "No-Equipment",
            subtitle: "Squats, Lunges, Climbers",
            icon: Icons.directions_run,
            gradient: const LinearGradient(
              colors: [Colors.orange, Colors.deepOrange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            primaryColor: Colors.orange,
            onTap: () => _selectCardioType(
                FootballLibrary.getStrengthPresetsForGear(
                    GarageGear.noEquipment),
                "No-Equipment"),
            enableShine: false,
          ),
          2,
        ),
      ],
    );
  }

  void _selectCardioType(List<SportProfile> list, String title) {
    setState(() {
      _currentList = list;
      _categoryTitle = "Cardio - $title";
      _step = 2;
    });
  }

  Widget _buildEquipmentSelector() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildAnimatedItem(
          _CategoryCard(
            title: "Barbell",
            subtitle: "Squats, Cleans, Deadlifts",
            icon: Icons.fitness_center,
            gradient: const LinearGradient(
              colors: [Color(0xFF78909C), Color(0xFF37474F)], // Steel Blue Grey
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            primaryColor: const Color(0xFF78909C),
            onTap: () => _selectEquipment(GarageGear.barbell, "Barbell"),
            enableShine: false,
          ),
          0,
        ),
        const SizedBox(height: 16),
        _buildAnimatedItem(
          _CategoryCard(
            title: "Dumbbell",
            subtitle: "Squats, Lunges, Press",
            icon: Icons.fitness_center,
            gradient: const LinearGradient(
              colors: [Colors.teal, Colors.tealAccent], // Distinct color for DB
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            primaryColor: Colors.teal,
            onTap: () => _selectEquipment(GarageGear.dumbbells, "Dumbbell"),
            enableShine: false,
          ),
          1,
        ),
        const SizedBox(height: 16),
        _buildAnimatedItem(
          _CategoryCard(
            title: "Bench",
            subtitle: "Dips, Split Squats, Step-Ups",
            icon: Icons.weekend,
            gradient: const LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            primaryColor: Colors.deepPurple,
            onTap: () => _selectEquipment(GarageGear.bench, "Bench"),
            enableShine: false,
          ),
          2,
        ),
      ],
    );
  }

  void _selectEquipment(GarageGear gear, String title) {
    setState(() {
      _currentList = FootballLibrary.getStrengthPresetsForGear(gear);
      _categoryTitle = "Strength - $title";
      _step = 2;
    });
  }

  Widget _buildDrillList() {
    if (_categoryTitle.contains("Bike")) {
      return Column(
        children: [
          _buildBikeConnectionStatus(),
          Expanded(child: _buildListItems()),
        ],
      );
    }
    return _buildListItems();
  }

  Widget _buildBikeConnectionStatus() {
    final manager = context.watch<WorkoutManager>();
    return StreamBuilder(
      stream: manager.bikeService.statusStream,
      initialData: manager.bikeService.status,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final isConnected = status == BikeConnectionStatus.connected;
        final isScanning = status == BikeConnectionStatus.scanning ||
            status == BikeConnectionStatus.connecting;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              if (isConnected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        "BIKE CONNECTED",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else if (status == BikeConnectionStatus.bluetoothOff)
                OutlinedButton.icon(
                  onPressed: () => FlutterBluePlus.turnOn(),
                  icon: const Icon(Icons.bluetooth_disabled, color: Colors.red),
                  label: const Text("ENABLE BLUETOOTH",
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                )
              else if (status == BikeConnectionStatus.unauthorized)
                OutlinedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.security, color: Colors.orange),
                  label: const Text("GRANT PERMISSIONS",
                      style: TextStyle(color: Colors.orange)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: isScanning ? null : manager.connectToBike,
                  icon: isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bluetooth),
                  label: Text(isScanning ? "CONNECTING..." : "CONNECT BIKE"),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListItems() {
    return ListView.builder(
      itemCount: _currentList.length,
      itemBuilder: (context, index) {
        final profile = _currentList[index];
        return ListTile(
          leading: Icon(
            profile.isStrength ? Icons.fitness_center : Icons.sports_soccer,
            color: profile.isStrength ? Colors.blue : Colors.green,
          ),
          title: Text(profile.displayName),
          subtitle: Text(profile.isStrength
              ? "${profile.blocks.fold(0, (sum, block) => sum + block.iterations)} Sets"
              : "${profile.blocks.length} Blocks"),
          onTap: () {
            // Start the workout!
            final manager = context.read<WorkoutManager>();
            manager.loadPreset(profile);

            if (widget.isSelectionMode) {
              Navigator.pop(context); // Just select and return
            } else {
              manager.startWorkout();
              // Notify parent to switch tabs
              widget.onWorkoutStarted();
            }
          },
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }

  Widget _buildAnimatedItem(Widget child, int index) {
    return AnimatedBuilder(
      animation: _listController,
      builder: (context, child) {
        // Calculate interval for this item (staggered)
        final double start = (index * 0.1).clamp(0.0, 0.8);
        final double end = (start + 0.4).clamp(0.0, 1.0);

        final Animation<double> fade =
            Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _listController,
            curve: Interval(start, end, curve: Curves.easeIn),
          ),
        );

        final Animation<Offset> slide =
            Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
                .animate(
          CurvedAnimation(
            parent: _listController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        );

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final Color primaryColor;
  final VoidCallback onTap;
  final bool enableShine;

  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.primaryColor,
    required this.onTap,
    this.enableShine = true,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  double _shadowSpread = 0.0;
  Color _shadowColor = Colors.black12;

  late AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    if (widget.enableShine) {
      _shineController.repeat();
    }
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.97;
      _shadowSpread = 15.0;
      _shadowColor = widget.primaryColor.withOpacity(0.4);
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
      _shadowSpread = 0.0;
      _shadowColor = Colors.black12;
    });
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
      _shadowSpread = 0.0;
      _shadowColor = Colors.black12;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _shadowColor,
                blurRadius: 10,
                spreadRadius: _shadowSpread,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: widget.gradient,
              ),
              child: Stack(
                children: [
                  // Background Icon Decoration
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      widget.icon,
                      size: 140,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),

                  // Glass Shine Overlay
                  if (widget.enableShine)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _shineController,
                        builder: (context, child) {
                          // Animate the gradient from left to right (-1.0 to 2.0)
                          // Only active during the first 40% of the duration (1.6s)
                          final double progress = _shineController.value;
                          if (progress > 0.4) return const SizedBox();

                          // Map 0.0-0.4 to -1.5 to 2.5
                          final double slide = ((progress / 0.4) * 4.0) - 1.5;

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment(slide - 1.0, -1.0),
                                end: Alignment(slide, 1.0),
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  Colors.white.withOpacity(0.15),
                                  Colors.white.withOpacity(0.0),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child:
                              Icon(widget.icon, color: Colors.white, size: 32),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 24,
                    top: 24,
                    child: Icon(Icons.arrow_forward, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
