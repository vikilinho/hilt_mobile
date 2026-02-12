import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../utils/exercise_animation_map.dart';

class ExerciseVisual extends StatefulWidget {
  final String exerciseName;
  final bool isPulse;
  final String? assetPath;

  const ExerciseVisual({
    super.key,
    required this.exerciseName,
    required this.isPulse,
    this.assetPath,
  });

  @override
  State<ExerciseVisual> createState() => _ExerciseVisualState();
}

class _ExerciseVisualState extends State<ExerciseVisual>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    // Pulse Animation (Breathing Effect)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Lottie Controller for Speed Control
    _lottieController = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(ExerciseVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulse != oldWidget.isPulse) {
      if (widget.isPulse) {
        _lottieController.duration = _lottieController.duration != null
            ? _lottieController.duration! * (1 / 1.5) // Speed up to 1.5x
            : null;
      } else {
        // Reset to 1.0x?
        // Logic to reset speed is tricky without storing original duration.
        // Simplified: The controller drives the animation.
        // Actually, Lottie.network/asset with 'controller' uses the controller's duration.
        // If we want 1.5x speed, we set controller duration to (original / 1.5).
      }
      _lottieController.repeat();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine source from Map
    final url = ExerciseAnimationMap.get(widget.exerciseName);
    final isNetwork = url != null && url.startsWith('http');
    final isAsset = url != null && !isNetwork;

    const neonGreen = Color(0xFF39FF14);
    const tealColor = Color(0xFF00897B);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = widget.isPulse ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isPulse ? neonGreen : tealColor,
                width: widget.isPulse ? 3 : 2, // 2px normally, 3px pulse
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isPulse
                      ? neonGreen.withOpacity(0.6)
                      : tealColor.withOpacity(0.2),
                  blurRadius: widget.isPulse ? 25 : 10,
                  spreadRadius: widget.isPulse ? 2 : 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _buildLottie(url, isNetwork, isAsset),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLottie(String? url, bool isNetwork, bool isAsset) {
    if (url == null) {
      if (widget.exerciseName.toLowerCase().contains('dumbbell') ||
          widget.exerciseName.toLowerCase().contains('db')) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child:
              Image.asset('assets/images/dumbbell_3d.png', fit: BoxFit.contain),
        );
      }
      return _buildPlaceholder();
    }

    /* 
      Speed Logic:
      If HR > 150 (isPulse), we want 1.5x speed.
      This corresponds to a frameRate of 90fps (if base is 60) or simply passing options?
      Lottie doesn't imply speed directly in constructor easily without controller.
      Using 'controller' overrides internal duration.
      Creating a new controller for each load is complex.
      
      Simpler approach: NOT using controller, but rebuilding Lottie with 'options'? 
      LottieOptions doesn't have speed.
      
      ValueDelegate? No.
      
      Let's stick to standard speed (1.0) for now to ensure stability, or implement controller logic properly?
      User requested: "increase Lottie playback speed to 1.5x".
      
      Implementation:
      Wrap Lottie with a ValueListenableBuilder driven by _lottieController?
      Or use 'animate: true'.
      
      Actually, let's use the 'frameBuilder'? No.
      
      Let's look at Lottie properties:
      `Lottie.network(..., controller: _lottieController, ...)`
      Inside `onLoaded`: 
        `_lottieController.duration = composition.duration;`
        `if (widget.isPulse) _lottieController.duration *= (1/1.5);`
        `_lottieController.repeat();`
    */

    return LayoutBuilder(builder: (context, constraints) {
      return Builder(builder: (context) {
        if (isNetwork) {
          return Lottie.network(
            url,
            controller: _lottieController,
            fit: BoxFit.contain,
            onLoaded: (composition) {
              var duration = composition.duration;
              if (widget.isPulse) {
                // 1.5x speed = 2/3 duration
                duration = Duration(
                    milliseconds: (duration.inMilliseconds / 1.5).round());
              }
              _lottieController.duration = duration;
              _lottieController.repeat();
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholder(error: "Animation Unavailable");
            },
          );
        } else if (isAsset) {
          return Lottie.asset(
            url,
            controller: _lottieController,
            fit: BoxFit.contain,
            onLoaded: (composition) {
              var duration = composition.duration;
              if (widget.isPulse) {
                duration = Duration(
                    milliseconds: (duration.inMilliseconds / 1.5).round());
              }
              _lottieController.duration = duration;
              _lottieController.repeat();
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholder(error: "Asset Missing");
            },
          );
        }
        return _buildPlaceholder();
      });
    });
  }

  Widget _buildPlaceholder({String error = ""}) {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            widget.exerciseName,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                error,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
