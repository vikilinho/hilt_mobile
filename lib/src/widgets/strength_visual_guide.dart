import 'package:flutter/material.dart';
import 'package:hilt_core/hilt_core.dart';
import 'exercise_visual.dart';
import 'heart_rate_pulse.dart';

/// Visual guide widget that displays exercise form animations during strength workouts
/// Updates Layout during Rest Phase to show HBM.
class StrengthVisualGuide extends StatefulWidget {
  final SportProfile profile;
  final WorkoutPhase phase;
  final int currentHeartRate;
  final String? currentAnimationAsset;
  final String? currentExerciseLabel;

  const StrengthVisualGuide({
    super.key,
    required this.profile,
    required this.phase,
    required this.currentHeartRate,
    this.currentAnimationAsset,
    this.currentExerciseLabel,
  });

  @override
  State<StrengthVisualGuide> createState() => _StrengthVisualGuideState();
}

class _StrengthVisualGuideState extends State<StrengthVisualGuide> {
  @override
  Widget build(BuildContext context) {
    String exerciseName = widget.profile.displayName;

    // Block-level override removed to ensure consistent workout animation.

    // Determine Pulse (Intensity > 150)
    final isPulse = widget.currentHeartRate >= 150;

    if (widget.phase == WorkoutPhase.rest) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: SizedBox(
            width: 150, // Constrain width so FittedBox scales reasonably
            height: 150,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Padding(
                padding: const EdgeInsets.all(20.0), // Padding for shadow
                child: HeartRatePulse(
                  bpm: widget.currentHeartRate,
                  targetBpm: widget.profile.targetHeartRate,
                  isBelowTarget:
                      widget.currentHeartRate < widget.profile.targetHeartRate,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          // Exercise Visual
          SizedBox(
            height: 250,
            child: ExerciseVisual(
              exerciseName: exerciseName,
              isPulse: isPulse,
              // Intentionally ommit assetPath to force lookup by exerciseName (Profile Name or Recovery)
            ),
          ),
        ],
      ),
    );
  }
}
