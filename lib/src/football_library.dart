import 'package:hilt_core/hilt_core.dart';

class FootballLibrary {
  static List<SportProfile> get presets => [
        impactSub,
        warmup,
        boxToBox,
        matchSim,
        preSeason,
      ];

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
          // 1. First Half: 20m. Assuming standard 30/30 for now as not specified, or 15/15 like 2nd half?
          // Request said "Phase 2 intervals must be 15s Sprint / 15s Rest".
          // Implicitly Phase 1 might be standard or different?
          // Let's make First Half 30/30 (Standard) -> 20m = 20 iterations
          WorkoutBlock(
            label: 'First Half',
            workSeconds: 30,
            restSeconds: 30,
            iterations: 20, // 20m
            targetBpm: 155,
          ),
          // 2. Half Time: 5m Low Intensity. 1 iteration of 0 work / 300 rest?
          // Or Work with low target? Let's do 5m Rest.
          WorkoutBlock(
            label: 'Half Time',
            workSeconds: 0,
            restSeconds: 300, // 5m
            iterations: 1,
            targetBpm: 110,
            coachAudio: 'half_time',
          ),
          // 3. Second Half: 20m. 15s/15s.
          // 15+15=30s cycle. 20m * 60 / 30 = 40 iterations.
          WorkoutBlock(
            label: 'Second Half',
            workSeconds: 15,
            restSeconds: 15,
            iterations: 40,
            targetBpm: 160, // Maybe higher intensity?
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
