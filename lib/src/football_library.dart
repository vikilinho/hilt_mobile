import 'package:hilt_core/hilt_core.dart';

class FootballLibrary {
  static List<SportProfile> get footballPresets => [
        impactSub,
        warmup,
        boxToBox,
        matchSim,
        preSeason,
      ];

  static List<SportProfile> get strengthPresets => [];

  // Combined for legacy or all-access if needed
  static List<SportProfile> get allPresets => [
        ...footballPresets,
        ...strengthPresets,
      ];
  static List<SportProfile> getStrengthPresetsForGear(GarageGear gear) {
    if (gear == GarageGear.barbell) {
      return [matchPrimer, explosivePower, strengthEngine, iron90];
    }
    if (gear == GarageGear.dumbbells) {
      return [dbGobletSquat, dbLunges, dbOverheadPress, dbRDL];
    }
    if (gear == GarageGear.bench) {
      return [benchDips, bulgarianSplitSquats, benchStepUps, benchLegRaises];
    }
    if (gear == GarageGear.noEquipment) {
      return [airSquats, walkingLunges, burpees, mountainClimbers];
    }
    return [];
  }

  static List<SportProfile> get bikePresets => [
        impactSub.copyWith(gear: GarageGear.bike),
        warmup.copyWith(gear: GarageGear.bike),
        boxToBox.copyWith(gear: GarageGear.bike),
        matchSim.copyWith(gear: GarageGear.bike),
        preSeason.copyWith(gear: GarageGear.bike),
      ];

  static List<SportProfile> get treadmillPresets => [
        matchEngine,
        tempoPitch,
        blitzFinish,
      ];

  // --- Treadmill Presets ---

  static SportProfile get matchEngine => const SportProfile(
        type: SportType.football,
        gear: GarageGear.treadmill,
        workDuration: 0,
        restDuration: 0,
        targetHeartRate: 145,
        displayName: 'Match Engine',
        blocks: [
          WorkoutBlock(
            label: 'Steady State',
            workSeconds: 2700, // 45 Minutes
            restSeconds: 0,
            iterations: 1,
            targetBpm: 145,
            coachAudio: 'treadmill_steady', // Generic steady state
          ),
        ],
      );

  static SportProfile get tempoPitch => const SportProfile(
        type: SportType.football,
        gear: GarageGear.treadmill,
        workDuration: 0,
        restDuration: 0,
        targetHeartRate: 155,
        displayName: 'Tempo Pitch',
        blocks: [
          WorkoutBlock(
            label: 'Tempo Run',
            workSeconds: 1200, // 20 Minutes
            restSeconds: 0,
            iterations: 1,
            targetBpm: 155,
            coachAudio: 'treadmill_steady',
          ),
        ],
      );

  static SportProfile get blitzFinish => const SportProfile(
        type: SportType.football,
        gear: GarageGear.treadmill,
        workDuration: 0,
        restDuration: 0,
        targetHeartRate: 165,
        displayName: 'Blitz Finish',
        blocks: [
          WorkoutBlock(
            label: 'Max Effort',
            workSeconds: 60, // 1 Minute Intervals
            restSeconds: 0,
            iterations: 5, // 5 Intervals = 5 Minutes
            targetBpm: 165,
            coachAudio: 'blitz_finish_interval', // Special cue
          ),
        ],
      );

  // --- Barbell Presets ---

  static SportProfile get matchPrimer => const SportProfile(
        type: SportType.football,
        gear: GarageGear.barbell,
        workDuration: 0,
        restDuration: 90,
        targetHeartRate: 140,
        displayName: 'Clean Press (5m)',
        animationAsset: 'assets/animations/Power Clean.json',
        blocks: [
          WorkoutBlock(
            label: 'Clean Press',
            workSeconds: 0,
            restSeconds: 90,
            iterations: 3,
            targetBpm: 145,
            animationAsset: 'assets/animations/Power Clean.json',
          ),
        ],
      );

  static SportProfile get explosivePower => const SportProfile(
        type: SportType.football,
        gear: GarageGear.barbell,
        workDuration: 0,
        restDuration: 90,
        targetHeartRate: 145,
        displayName: 'Explosive Power (15m)',
        animationAsset: 'assets/animations/Barbell Lunges.json',
        blocks: [
          WorkoutBlock(
            label: 'Barbell Back Squat',
            workSeconds: 0,
            restSeconds: 90,
            iterations: 3,
            targetBpm: 145,
            animationAsset: 'assets/animations/backsquat.json',
          ),
          WorkoutBlock(
            label: 'Barbell Push Press',
            workSeconds: 0,
            restSeconds: 90,
            iterations: 3,
            targetBpm: 150,
            animationAsset: 'assets/animations/push_press.json',
          ),
        ],
      );

  static SportProfile get strengthEngine => const SportProfile(
        type: SportType.football,
        gear: GarageGear.barbell,
        workDuration: 0,
        restDuration: 90,
        targetHeartRate: 150,
        displayName: 'Strength Engine (30m)',
        animationAsset: 'assets/animations/deadlift.json',
        blocks: [
          WorkoutBlock(
            label: 'Barbell Back Squat',
            workSeconds: 0,
            restSeconds: 90,
            iterations: 5,
            targetBpm: 150,
            animationAsset: 'assets/animations/backsquat.json',
          ),
          WorkoutBlock(
            label: 'Barbell Deadlift',
            workSeconds: 0,
            restSeconds: 90,
            iterations: 5,
            targetBpm: 155,
            animationAsset: 'assets/animations/deadlift.json',
          ),
        ],
      );

  static SportProfile get iron90 => const SportProfile(
        type: SportType.football,
        gear: GarageGear.barbell,
        workDuration: 0,
        restDuration: 90,
        targetHeartRate: 155,
        displayName: 'The Iron 90 (45m)',
        animationAsset: 'assets/animations/backsquat.json',
        blocks: [
          WorkoutBlock(
            label: 'Barbell Back Squat',
            workSeconds: 0,
            restSeconds: 90,
            iterations: 4,
            targetBpm: 150,
            animationAsset: 'assets/animations/backsquat.json',
          ),
          WorkoutBlock(
            label: 'Power Clean',
            workSeconds: 0,
            restSeconds: 90,
            iterations: 4,
            targetBpm: 155,
            animationAsset: 'assets/animations/Power Clean.json',
          ),
          WorkoutBlock(
            label: 'Barbell Deadlift',
            workSeconds: 0,
            restSeconds: 90,
            iterations: 4,
            targetBpm: 155,
            animationAsset: 'assets/animations/deadlift.json',
          ),
          WorkoutBlock(
            label: 'Barbell Push Press',
            workSeconds: 0,
            restSeconds: 90,
            iterations: 4,
            targetBpm: 150,
            animationAsset: 'assets/animations/push_press.json',
          ),
        ],
      );

  // --- Dumbbell Presets ---

  static SportProfile get dbGobletSquat => const SportProfile(
        type: SportType.football,
        gear: GarageGear.dumbbells,
        workDuration: 0,
        restDuration: 60,
        targetHeartRate: 155, // 150+ for Grade A
        displayName: 'Dumbbell Goblet Squat',
        animationAsset: 'assets/animations/dumbellsquat.json',
        blocks: [
          WorkoutBlock(
            label: 'Dumbbell Goblet Squat',
            workSeconds: 60,
            restSeconds: 60,
            iterations: 3,
            targetBpm: 155,
          ),
        ],
      );

  static SportProfile get dbLunges => const SportProfile(
        type: SportType.football,
        gear: GarageGear.dumbbells,
        workDuration: 0,
        restDuration: 60,
        targetHeartRate: 155,
        displayName: 'Dumbbell Lunges',
        animationAsset: 'assets/animations/dumbelllunges.json',
        blocks: [
          WorkoutBlock(
            label: 'Dumbbell Lunges',
            workSeconds: 60,
            restSeconds: 60,
            iterations: 4,
            targetBpm: 155,
            coachAudio: 'switch_legs_halfway', // Logic in WorkoutManager
          ),
        ],
      );

  static SportProfile get dbOverheadPress => const SportProfile(
        type: SportType.football,
        gear: GarageGear.dumbbells,
        workDuration: 0,
        restDuration: 60,
        targetHeartRate: 155,
        displayName: 'Dumbbell Overhead Press',
        animationAsset: 'assets/animations/dumbelloverheadpress.json',
        blocks: [
          WorkoutBlock(
            label: 'Dumbbell Overhead Press',
            workSeconds: 45,
            restSeconds: 60,
            iterations: 3,
            targetBpm: 155,
          ),
        ],
      );

  static SportProfile get dbRDL => const SportProfile(
        type: SportType.football,
        gear: GarageGear.dumbbells,
        workDuration: 0,
        restDuration: 60,
        targetHeartRate: 155,
        displayName: 'Dumbbell Romanian Deadlift',
        animationAsset: 'assets/animations/dumbellRomania.json',
        blocks: [
          WorkoutBlock(
            label: 'Dumbbell Romanian Deadlift',
            workSeconds: 60,
            restSeconds: 60,
            iterations: 3,
            targetBpm: 155,
          ),
        ],
      );

  // --- Bench Presets ---

  static SportProfile get benchDips => const SportProfile(
        type: SportType.football,
        gear: GarageGear.bench,
        workDuration: 0,
        restDuration: 60,
        targetHeartRate: 155,
        displayName: 'Bench Dips',
        animationAsset: 'assets/animations/Bench Dips.json',
        blocks: [
          WorkoutBlock(
            label: 'Bench Dips',
            workSeconds: 45,
            restSeconds: 60,
            iterations: 3,
            targetBpm: 155,
          ),
        ],
      );

  static SportProfile get bulgarianSplitSquats => const SportProfile(
        type: SportType.football,
        gear: GarageGear.bench,
        workDuration: 0,
        restDuration: 60,
        targetHeartRate: 155,
        displayName: 'Bulgarian Split Squats',
        animationAsset: 'assets/animations/Bulgarian Split Squats.json',
        blocks: [
          WorkoutBlock(
            label: 'Bulgarian Split Squats',
            workSeconds: 60,
            restSeconds: 60,
            iterations: 3,
            targetBpm: 155,
            coachAudio: 'switch_legs_halfway',
          ),
        ],
      );

  static SportProfile get benchStepUps => const SportProfile(
        type: SportType.football,
        gear: GarageGear.bench,
        workDuration: 0,
        restDuration: 60,
        targetHeartRate: 155,
        displayName: 'Bench Step-Ups',
        animationAsset: 'assets/animations/Bench Step-Ups.json',
        blocks: [
          WorkoutBlock(
            label: 'Bench Step-Ups',
            workSeconds: 60,
            restSeconds: 60,
            iterations: 4,
            targetBpm: 155,
            coachAudio: 'switch_legs_halfway',
          ),
        ],
      );

  static SportProfile get benchLegRaises => const SportProfile(
        type: SportType.football,
        gear: GarageGear.bench,
        workDuration: 0,
        restDuration: 60,
        targetHeartRate: 155,
        displayName: 'Bench Leg Raises',
        animationAsset: 'assets/animations/Bench Leg Raises.json',
        blocks: [
          WorkoutBlock(
            label: 'Bench Leg Raises',
            workSeconds: 45,
            restSeconds: 60,
            iterations: 3,
            targetBpm: 155,
          ),
        ],
      );

  // --- No-Equipment / Bodyweight Presets ---

  static SportProfile get airSquats => const SportProfile(
        type: SportType.football,
        gear: GarageGear.noEquipment,
        workDuration: 45,
        restDuration: 30,
        targetHeartRate: 130,
        displayName: 'Air Squats',
        animationAsset: 'assets/animations/Air Squats.json',
        blocks: [
          WorkoutBlock(
            label: 'Air Squats',
            workSeconds: 45,
            restSeconds: 30,
            iterations: 4,
            targetBpm: 130,
            animationAsset: 'assets/animations/Air Squats.json',
          ),
        ],
      );

  static SportProfile get walkingLunges => const SportProfile(
        type: SportType.football,
        gear: GarageGear.noEquipment,
        workDuration: 45,
        restDuration: 30,
        targetHeartRate: 130,
        displayName: 'Walking Lunges',
        animationAsset: 'assets/animations/Walking Lunges.json',
        blocks: [
          WorkoutBlock(
            label: 'Walking Lunges',
            workSeconds: 45,
            restSeconds: 30,
            iterations: 4,
            targetBpm: 130,
            animationAsset: 'assets/animations/Walking Lunges.json',
          ),
        ],
      );

  static SportProfile get burpees => const SportProfile(
        type: SportType.football,
        gear: GarageGear.noEquipment,
        workDuration: 45,
        restDuration: 40,
        targetHeartRate: 130,
        displayName: 'Burpees',
        animationAsset: 'assets/animations/Burpees.json',
        blocks: [
          WorkoutBlock(
            label: 'Burpees',
            workSeconds: 45,
            restSeconds: 40,
            iterations: 4,
            targetBpm: 130,
            animationAsset: 'assets/animations/Burpees.json',
          ),
        ],
      );

  static SportProfile get mountainClimbers => const SportProfile(
        type: SportType.football,
        gear: GarageGear.noEquipment,
        workDuration: 45,
        restDuration: 35,
        targetHeartRate: 130,
        displayName: 'Mountain Climbers',
        animationAsset: 'assets/animations/Mountain Climbers.json',
        blocks: [
          WorkoutBlock(
            label: 'Mountain Climbers',
            workSeconds: 45,
            restSeconds: 35,
            iterations: 4,
            targetBpm: 130,
            animationAsset: 'assets/animations/Mountain Climbers.json',
          ),
        ],
      );

  // --- Football Presets ---

  static SportProfile get impactSub => const SportProfile(
        type: SportType.football,
        workDuration: 0, // Ignored by blocks
        restDuration: 0,
        targetHeartRate: 160,
        displayName: 'Impact Sub (10m)',
        blocks: [
          WorkoutBlock(
            label: 'Impact Sub',
            workSeconds: 20,
            restSeconds: 40,
            iterations: 10, // 10 minutes * 60 / 60s cycle = 10
            targetBpm: 160,
            coachAudio: 'high_urgency',
          ),
        ],
      );

  static SportProfile get warmup => const SportProfile(
        type: SportType.football,
        workDuration: 0,
        restDuration: 0,
        targetHeartRate: 140,
        displayName: 'Warmup (5m)',
        blocks: [
          WorkoutBlock(
            label: 'Warmup',
            workSeconds: 20,
            restSeconds: 40,
            iterations: 5, // 5 minutes * 60 / 60s cycle = 5
            targetBpm: 140,
            coachAudio: 'high_urgency',
          ),
        ],
      );

  static SportProfile get boxToBox => const SportProfile(
        type: SportType.football,
        workDuration: 0,
        restDuration: 0,
        targetHeartRate: 150,
        displayName: 'Box-to-Box (20m)',
        blocks: [
          WorkoutBlock(
            label: 'Box-to-Box',
            workSeconds: 30,
            restSeconds: 30,
            iterations: 20, // 20m * 60 / 60s cycle = 20
            targetBpm: 150,
          ),
        ],
      );

  static SportProfile get matchSim => const SportProfile(
        type: SportType.football,
        workDuration: 0,
        restDuration: 0,
        targetHeartRate: 155,
        displayName: 'Match Sim (45m)',
        blocks: [
          // First Half: 20m (30s work/30s rest)
          WorkoutBlock(
            label: 'First Half',
            workSeconds: 30,
            restSeconds: 30,
            iterations: 20,
            targetBpm: 155,
          ),
          // Half Time: 5m (0s work/300s rest)
          WorkoutBlock(
            label: 'Half Time',
            workSeconds: 0,
            restSeconds: 300,
            iterations: 1,
            targetBpm: 110,
            coachAudio: 'half_time',
          ),
          // Second Half: 20m (15s work/15s rest)
          WorkoutBlock(
            label: 'Second Half',
            workSeconds: 15,
            restSeconds: 15,
            iterations: 40,
            targetBpm: 160,
            coachAudio: 'match_sim_half',
          ),
        ],
      );

  static SportProfile get preSeason => const SportProfile(
        type: SportType.football,
        workDuration: 0,
        restDuration: 0,
        targetHeartRate: 155,
        displayName: 'Pre-Season (60m)',
        blocks: [
          // 6 Blocks Alternating 1m/1m and 30s/30s. Each block 10m.
          // Block 1: 1m/1m. 2m cycle. 10m = 5 iterations.
          WorkoutBlock(
              label: 'Block 1 (Long)',
              workSeconds: 60,
              restSeconds: 60,
              iterations: 5,
              targetBpm: 150),
          // Block 2: 30s/30s. 1m cycle. 10m = 10 iterations.
          WorkoutBlock(
              label: 'Block 2 (Short)',
              workSeconds: 30,
              restSeconds: 30,
              iterations: 10,
              targetBpm: 160),
          // Block 3: 1m/1m
          WorkoutBlock(
              label: 'Block 3 (Long)',
              workSeconds: 60,
              restSeconds: 60,
              iterations: 5,
              targetBpm: 150),
          // Block 4: 30s/30s
          WorkoutBlock(
              label: 'Block 4 (Short)',
              workSeconds: 30,
              restSeconds: 30,
              iterations: 10,
              targetBpm: 160),
          // Block 5: 1m/1m
          WorkoutBlock(
              label: 'Block 5 (Long)',
              workSeconds: 60,
              restSeconds: 60,
              iterations: 5,
              targetBpm: 150),
          // Block 6: 30s/30s
          WorkoutBlock(
              label: 'Block 6 (Short)',
              workSeconds: 30,
              restSeconds: 30,
              iterations: 10,
              targetBpm: 160),
        ],
      );
}
