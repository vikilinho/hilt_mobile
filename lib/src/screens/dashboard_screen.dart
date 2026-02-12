import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hilt_core/hilt_core.dart';
import '../workout_manager.dart';

import '../services/bike_connector_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../widgets/heart_rate_pulse.dart';
import '../widgets/strength_visual_guide.dart'; // Import library
import '../widgets/equipment_selector.dart';
import 'post_workout_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback?
      onRequestWorkoutSelection; // Kept for compatibility if needed, but unused internally now

  const DashboardScreen({super.key, this.onRequestWorkoutSelection});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription? _sub;
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sub = context
          .read<WorkoutManager>()
          .onSessionComplete
          .listen(_onSessionComplete);
    });
  }

  void _onSessionComplete(WorkoutSession session) {
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostWorkoutSummaryScreen(
            session: session,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WorkoutManager>();
    final state = manager.workoutState;
    final profile = manager.profile;

    // Pulse Red if true
    final pulseColor = (state?.isBelowTarget ?? false)
        ? Colors.red.withOpacity(0.2)
        : Colors.transparent;

    return Scaffold(
      appBar: state != null
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: Text(
                manager.profile.displayName.isNotEmpty
                    ? (manager.profile.gear == GarageGear.treadmill
                        ? "${manager.profile.displayName} (${manager.profile.blocks.fold(0, (p, b) => p + b.workSeconds * b.iterations + b.restSeconds * b.iterations) ~/ 60}M)"
                            .toUpperCase()
                        : manager.profile.displayName)
                    : 'Workout',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text("Stop Workout?"),
                      content: const Text(
                        "Do you want to stop this workout?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text("CANCEL"),
                        ),
                        FilledButton(
                          onPressed: () {
                            manager.stopWorkout(save: false);
                            Navigator.pop(dialogContext);
                            widget.onRequestWorkoutSelection?.call();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text("STOP WORKOUT"),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          : null, // No app bar when not in workout
      body: AnimatedContainer(
        duration: const Duration(seconds: 1),
        color: pulseColor,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24.0,
              state == null ? 48.0 : 24.0, // Extra top padding when no app bar
              24.0,
              24.0,
            ),
            child: ListView(
              children: [
                // Back Button moved to AppBar

                // Old Select Session Button Removed

                const SizedBox(
                    height: 56), // Increased spacing for visual breathing room

                // Bike Integration (Only if Bike is selected)
                if (state == null && profile.gear == GarageGear.bike)
                  StreamBuilder(
                    stream: manager.bikeService.statusStream,
                    initialData: manager.bikeService.status,
                    builder: (context, snapshot) {
                      final status = snapshot.data;
                      final isConnected =
                          status == BikeConnectionStatus.connected;
                      final isScanning =
                          status == BikeConnectionStatus.scanning ||
                              status == BikeConnectionStatus.connecting;

                      return Column(
                        children: [
                          if (isConnected)
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.directions_bike,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "BIKE CONNECTED",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          else if (status == BikeConnectionStatus.bluetoothOff)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  FlutterBluePlus.turnOn(), // Prompt to turn on
                              icon: const Icon(Icons.bluetooth_disabled,
                                  color: Colors.red),
                              label: const Text("ENABLE BLUETOOTH",
                                  style: TextStyle(color: Colors.red)),
                            )
                          else if (status == BikeConnectionStatus.unauthorized)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  openAppSettings(), // Open settings
                              icon: const Icon(Icons.security,
                                  color: Colors.orange),
                              label: const Text("GRANT PERMISSIONS",
                                  style: TextStyle(color: Colors.orange)),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed:
                                  isScanning ? null : manager.connectToBike,
                              icon: isScanning
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.link),
                              label: Text(
                                isScanning ? "SCANNING..." : "CONNECT BIKE",
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                if (state == null && profile.gear == GarageGear.bike)
                  const SizedBox(height: 24),

                // Form Guide Animation (Strength Only)
                if (state?.phase == WorkoutPhase.strengthWork ||
                    state?.phase == WorkoutPhase.rest && profile.isStrength)
                  StrengthVisualGuide(
                    profile: profile,
                    phase: state?.phase ?? WorkoutPhase.strengthWork,
                    currentHeartRate: manager.currentBpm,
                    currentAnimationAsset: state?.animationAsset,
                    currentExerciseLabel: state?.blockLabel,
                  ),

                // Timer & Phase OR Weekly Goal Hub
                if (state?.phase == WorkoutPhase.strengthWork)
                  _buildStrengthInput(context, manager)
                else if (state != null)
                  // Active Workout Timer
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 250,
                        height: 250,
                        child: CircularProgressIndicator(
                          value: (state.currentPhaseDuration == 0)
                              ? 0
                              : state.timeRemaining /
                                  state.currentPhaseDuration,
                          strokeWidth: 20,
                          backgroundColor: Colors.grey.shade200,
                          color: state.phase == WorkoutPhase.rest
                              ? Colors.blue
                              : Colors.green,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (profile.gear == GarageGear.treadmill &&
                              state.phase != WorkoutPhase.rest) ...[
                            // TREADMILL WORK PHASE: Show TARGET BPM
                            Text(
                              "TARGET BPM",
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              "${profile.targetHeartRate}",
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ] else ...[
                            // REST / OTHER / NON-TREADMILL: Show Timer
                            Text(
                              state.phase.name.toUpperCase(),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              "${state.timeRemaining}",
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ]
                        ],
                      ),
                    ],
                  )
                else
                // Weekly Goal Hub (Idle State)
                // If Treadmill layout is active (check manager state/profile)
                // Using profile.gear check since we are in idle state
                if (profile.gear == GarageGear.treadmill &&
                    manager.hasUserSelectedProfile)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00897B).withOpacity(0.2),
                              width: 20,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "TARGET BPM", // Label
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[600],
                                      letterSpacing: 1.2,
                                    ),
                              ),
                              Text(
                                "${profile.targetHeartRate}", // Value
                                style: Theme.of(context)
                                    .textTheme
                                    .displayLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      fontSize: 64,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Regular Weekly Goal Hub
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 32.0), // Centering Padding
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 250,
                          height: 250,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0, end: manager.weeklyProgressPercent),
                            duration: const Duration(seconds: 1),
                            builder: (context, value, _) =>
                                CircularProgressIndicator(
                              value: value,
                              strokeWidth: 20,
                              backgroundColor: Colors.grey.shade200,
                              color: const Color(0xFF00897B),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getWeeklyGoalLabel(
                                  manager.weeklySessionsCompleted),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                    letterSpacing: 1.2,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${manager.weeklySessionsCompleted} / ${manager.weeklyGoal}",
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24), // Reduced from 32

                // BPM (Hide during Rest as it's shown above)
                if (state?.phase != WorkoutPhase.rest) ...[
                  const SizedBox(height: 16),

                  // Heart Rate Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Current BPM Pulse
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "HEART RATE",
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              if (manager.lastHeartRateTime != null &&
                                  DateTime.now()
                                          .difference(
                                              manager.lastHeartRateTime!)
                                          .inSeconds <
                                      5)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          HeartRatePulse(
                            bpm: manager.currentBpm,
                            targetBpm: profile.targetHeartRate,
                            isBelowTarget: state?.isBelowTarget ?? false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],

                // Session Stats (Time/Laps Left) - Only for Cardio
                if (state != null && !profile.isStrength) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            "TIME LEFT",
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            _formatDuration(state.workoutTimeRemaining),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      if (state.totalIntervalsInBlock > 0)
                        Column(
                          children: [
                            Text(
                              "LAPS LEFT",
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              "${state.totalIntervalsInBlock - state.currentIntervalIndex + 1}",
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 16), // Reduced from 24

                // Bike/Treadmill Stats - Only for Cardio
                if (state != null && !profile.isStrength) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            "SPEED",
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            profile.gear == GarageGear.treadmill
                                ? "${((manager.currentSpeedKmh ?? 0) * 0.621371).toStringAsFixed(1)} mph"
                                : "${manager.currentSpeedMph.toStringAsFixed(1)} mph",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            "DIST",
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            profile.gear == GarageGear.treadmill
                                ? "${(manager.treadmillHandler.cumulativeDistanceMiles).toStringAsFixed(2)} miles"
                                : "${manager.bikeDistanceMiles.toStringAsFixed(2)} miles",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Equipment Selector
                const SizedBox(height: 16),

                // Equipment Status Pill (Triggers Modal)
                // SHOW ONLY IF SESSION SELECTED (manager.hasUserSelectedProfile)
                if (state == null && manager.hasUserSelectedProfile)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          bottom: 16.0), // Reduced from 24
                      child: InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (context) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        24, 24, 24, 0),
                                    child: Text(
                                      "SELECT EQUIPMENT",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                    ),
                                  ),
                                  EquipmentSelector(
                                    selectedGear: manager.activeEquipment,
                                    onEquipmentSelected: (gear) {
                                      manager.setActiveEquipment(gear);
                                      Navigator.pop(context);
                                    },
                                    showLabel: false,
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.grey.shade300, width: 1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getIconForGear(manager.activeEquipment),
                                size: 18,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getNameForGear(manager.activeEquipment)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Controls
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: state == null
                        ? () {
                            // Dynamic Action:
                            // If NO selection -> Go to Select Session Screen
                            // If HAS selection -> Start Workout

                            if (!manager.hasUserSelectedProfile) {
                              widget.onRequestWorkoutSelection?.call();
                            } else {
                              manager.startWorkout();
                            }
                          }
                        : () {
                            showDialog(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text("End Workout?"),
                                content: const Text(
                                  "Do you want to save this session to your history?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    child: const Text("CANCEL"),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      manager.stopWorkout(save: false);
                                      Navigator.pop(dialogContext);
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text("DISCARD"),
                                  ),
                                  FilledButton(
                                    onPressed: () async {
                                      // 1. Close Dialog
                                      Navigator.pop(dialogContext);

                                      // 2. Stop & Save
                                      final session = await manager.stopWorkout(
                                        save: true,
                                      );

                                      // 3. Navigate is handled by the stream listener 'onSessionComplete'
                                      if (session != null) {
                                        // Just close dialog, the listener will handle the rest
                                      }
                                    },
                                    child: const Text("SAVE & END"),
                                  ),
                                ],
                              ),
                            );
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          state == null ? Colors.black : Colors.red,
                    ),
                    child: Text(state == null
                        ? (manager.hasUserSelectedProfile
                            ? "START WORKOUT"
                            : "SELECT SESSION")
                        : "STOP"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildStrengthInput(BuildContext context, WorkoutManager manager) {
    // Bench and No-Equipment exercises are bodyweight only - no weight input needed
    final isBodyweight = manager.profile.gear == GarageGear.bench ||
        manager.profile.gear == GarageGear.noEquipment;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, // Changed to white
        border: Border.all(
          color: const Color(0xFF00897B), // Green border
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00897B).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Set Info
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  () {
                    final currentSet = manager.currentSetInBlock;
                    final totalSets =
                        manager.workoutState?.totalIntervalsInBlock ?? 0;
                    return totalSets > 0
                        ? "SET ${currentSet + 1}/$totalSets"
                        : "SET --";
                  }(),
                  style: const TextStyle(
                    color: Color(0xFF00897B), // Green text
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "LOG LOAD",
                  style: const TextStyle(
                    color: Color(0xFF00897B), // Green text
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Weight Input - Hide for bodyweight exercises
          if (!isBodyweight) ...[
            Expanded(
              flex: 3,
              child: _buildCompactInput(
                controller: _weightController,
                label: "KG",
                isDecimal: true,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Reps Input
          Expanded(
            flex: 3,
            child: _buildCompactInput(
              controller: _repsController,
              label: "REPS",
              isDecimal: false,
            ),
          ),
          const SizedBox(width: 8),

          // Log Button (Check Mark)
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00897B).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton.filled(
              onPressed: () {
                final weight = isBodyweight
                    ? 0.0
                    : (double.tryParse(_weightController.text) ?? 0);
                final reps = int.tryParse(_repsController.text) ?? 0;
                if (reps > 0) {
                  manager.logStrengthSet(weight, reps);
                  if (!isBodyweight) _weightController.clear();
                  _repsController.clear();
                  FocusScope.of(context).unfocus();
                }
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF00897B),
                side: const BorderSide(
                  color: Color(0xFF00897B), // Green border
                  width: 2,
                ),
                padding: EdgeInsets.zero,
                minimumSize: const Size(40, 40),
              ),
              icon: const Icon(Icons.check,
                  size: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInput({
    required TextEditingController controller,
    required String label,
    required bool isDecimal,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white, // Changed to solid white
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        keyboardType: isDecimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF00897B), // Changed to green
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        cursorColor: const Color(0xFF00897B), // Changed cursor to green too
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          border: InputBorder.none,
          hintText: "0",
          hintStyle: TextStyle(
            color: const Color(0xFF00897B).withOpacity(0.3), // Green hint
            fontSize: 16,
          ),
          suffixText: label,
          suffixStyle: const TextStyle(
            color: Color(0xFF00897B), // Green suffix
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  IconData _getIconForGear(GarageGear gear) {
    switch (gear) {
      case GarageGear.noEquipment:
        return Icons.bolt;
      case GarageGear.dumbbells:
        return Icons.grid_view;
      case GarageGear.barbell:
        return Icons.iron;
      case GarageGear.bench:
        return Icons.horizontal_rule;
      default:
        return Icons.bolt;
    }
  }

  String _getNameForGear(GarageGear gear) {
    switch (gear) {
      case GarageGear.noEquipment:
        return "No-Equipment";
      case GarageGear.dumbbells:
        return "Dumbbell";
      case GarageGear.barbell:
        return "Barbell";
      case GarageGear.bench:
        return "Bench";
      default:
        return "None";
    }
  }

  String _getWeeklyGoalLabel(int sessions) {
    if (sessions <= 1) return "START STRONG";
    if (sessions <= 3) return "MATCH FIT";
    return "ELITE DRIVE";
  }

  void _showWorkoutSettings(BuildContext context, WorkoutManager manager) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "WORKOUT SETTINGS",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "TARGET BPM: ${manager.profile.targetHeartRate}",
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Slider(
                    value: manager.profile.targetHeartRate.toDouble(),
                    min: 100,
                    max: 200,
                    divisions: 20,
                    label: "${manager.profile.targetHeartRate}",
                    onChanged: (v) {
                      manager.updateTargetHeartRate(v.round());
                      setState(() {});
                    },
                    activeColor: const Color(0xFF00897B),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Close modal
                      widget.onRequestWorkoutSelection?.call();
                    },
                    icon: const Icon(Icons.search),
                    label: const Text("BROWSE WORKOUTS"),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
