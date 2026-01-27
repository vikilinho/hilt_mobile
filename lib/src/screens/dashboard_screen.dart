import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hilt_core/hilt_core.dart';
import '../workout_manager.dart';
import '../football_library.dart'; // Import library
import '../services/bike_connector_service.dart';
import '../widgets/heart_rate_pulse.dart';
import 'post_workout_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription? _sub;

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
      body: AnimatedContainer(
        duration: const Duration(seconds: 1),
        color: pulseColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ListView(
              children: [
                // Workout Header & Selector
                if (state == null)
                  Column(
                    children: [
                      Text(
                        profile.displayName.isNotEmpty
                            ? profile.displayName.toUpperCase()
                            : "SELECT DRILL",
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (ctx) => ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    "Football Training",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                ...FootballLibrary.presets.map(
                                  (p) => ListTile(
                                    title: Text(p.displayName),
                                    subtitle: Text("${p.blocks.length} Blocks"),
                                    onTap: () {
                                      manager.loadPreset(p);
                                      Navigator.pop(ctx);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.sports_soccer),
                        label: const Text("CHANGE WORKOUT"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Target BPM Slider
                if (state == null)
                  Column(
                    children: [
                      Text(
                        "TARGET BPM: ${profile.targetHeartRate}",
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Slider(
                        value: profile.targetHeartRate.toDouble(),
                        min: 100,
                        max: 200,
                        divisions: 20,
                        label: "${profile.targetHeartRate}",
                        onChanged: (v) =>
                            manager.updateTargetHeartRate(v.round()),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Bike Integration
                if (state == null)
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

                const SizedBox(height: 24),

                // Timer & Phase
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(
                        value: state == null
                            ? 0
                            : state.timeRemaining / state.currentPhaseDuration,
                        strokeWidth: 20,
                        backgroundColor: Colors.grey.shade200,
                        color: state?.phase == WorkoutPhase.rest
                            ? Colors.blue
                            : Colors.green,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state?.phase.name.toUpperCase() ?? "READY",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          "${state?.timeRemaining ?? profile.workDuration}",
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // BPM
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "HEART RATE",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (manager.lastHeartRateTime != null &&
                        DateTime.now()
                                .difference(manager.lastHeartRateTime!)
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
                HeartRatePulse(
                  bpm: manager.currentBpm,
                  targetBpm: profile.targetHeartRate,
                  isBelowTarget: state?.isBelowTarget ?? false,
                ),

                // Session Stats (Time/Laps Left)
                if (state != null) ...[
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

                const SizedBox(height: 24),

                // Bike Stats
                if (state != null) ...[
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
                            "${manager.currentSpeedMph.toStringAsFixed(1)} mph",
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
                            "${manager.bikeDistanceMiles.toStringAsFixed(2)} miles",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Controls
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: state == null
                        ? manager.startWorkout
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
                                      // We do NOT need to push here manually, otherwise we get double screens.
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
                    child: Text(state == null ? "START WORKOUT" : "STOP"),
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
}
