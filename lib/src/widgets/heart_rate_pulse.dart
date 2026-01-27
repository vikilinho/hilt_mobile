import 'package:flutter/material.dart';

class HeartRatePulse extends StatefulWidget {
  final int bpm;
  final int targetBpm;
  final bool isBelowTarget;

  const HeartRatePulse({
    super.key,
    required this.bpm,
    required this.targetBpm,
    required this.isBelowTarget,
  });

  @override
  State<HeartRatePulse> createState() => _HeartRatePulseState();
}

class _HeartRatePulseState extends State<HeartRatePulse> {
  // Use a key to force rebuild/restart animation when duration changes significantly?
  // Or just let TweenAnimationBuilder handle it.
  // TweenAnimationBuilder handles duration changes gracefully by interpolating to new target.
  // But for a continuous loop, we need to toggle the target value (0 <-> 1).

  double _targetValue = 1.0;

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Duration
    // If BPM is 0, use a slow "resting" breathe (e.g. 20 BPM pace = 3s)
    // Formula: 60 / BPM = seconds per beat.
    // We want the pulse (up and down) to fit within this beat?
    // Or just the "Up" phase?
    // Let's make the full cycle (0->1->0) match the beat duration.
    // So one phase is half that.

    final safeBpm = widget.bpm > 0 ? widget.bpm : 20; // 3s period if 0
    final beatDurationMs = (60000 / safeBpm).round();
    final phaseDuration = Duration(milliseconds: beatDurationMs ~/ 2);

    // 2. Determine Color/Intensity
    // If BPM > Target (and not 0), Warning/High Intensity (Red)
    // If BPM <= Target, Normal (Green/Black) - User requested Green/Black logic?
    // User request: "If BPM > Target, make the pulse more sharp and rapid."
    // User request: "If BPM is 0, the pulse should be a slow, steady fade."

    // Let's decide colors based on the "isBelowTarget" flag passed from Dashboard
    // Dashboard Logic:
    // isBelowTarget = true -> Red (Too low? Wait, Dashboard logic is "Pulse RED if BELOW target"?)
    // Let's re-read Dashboard logic:
    // "Pulse Red if true ... pulseColor = (state?.isBelowTarget ?? false) ? Colors.red : Transparent"
    // Actually, usually "Below Target" means work harder.
    // Let's stick to the widget inputs.

    final isHighIntensity = widget.bpm > widget.targetBpm;
    final pulseColor = widget.isBelowTarget
        ? Colors.red
        : (isHighIntensity ? Colors.red : Colors.green);

    // Curve
    final curve = isHighIntensity ? Curves.easeInOutCubic : Curves.easeInOut;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: _targetValue),
      duration: phaseDuration,
      curve: curve,
      onEnd: () {
        if (mounted) {
          setState(() {
            _targetValue = _targetValue == 1.0 ? 0.0 : 1.0;
          });
        }
      },
      builder: (context, value, child) {
        // Value goes 0 -> 1 -> 0
        // Scale Shadow/Glow
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: pulseColor.withOpacity(0.3 * value),
                blurRadius: 20 * value,
                spreadRadius: 5 * value,
              ),
            ],
          ),
          child: Text(
            "${widget.bpm}",
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
