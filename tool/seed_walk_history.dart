import 'dart:ffi';
import 'dart:io';

import 'package:hilt_core/hilt_core.dart';
import 'package:isar_community/isar.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr
        .writeln('Usage: dart run tool/seed_walk_history.dart <documents-dir>');
    exitCode = 64;
    return;
  }

  final documentsDir = args.first;
  final directory = Directory(documentsDir);
  if (!directory.existsSync()) {
    stderr.writeln('Directory does not exist: $documentsDir');
    exitCode = 66;
    return;
  }

  final toolDir = File(Platform.script.toFilePath()).parent;
  final bundledLibraryPath =
      toolDir.parent.uri.resolve('libisar.dylib').toFilePath();
  final homeDir = Platform.environment['HOME'];
  final cachedLibraryPath = homeDir == null
      ? null
      : '$homeDir/.pub-cache/hosted/pub.dev/'
          'isar_community_flutter_libs-3.3.2/macos/libisar.dylib';
  final isarLibraryPath =
      cachedLibraryPath != null && File(cachedLibraryPath).existsSync()
          ? cachedLibraryPath
          : bundledLibraryPath;
  await Isar.initializeIsarCore(
    libraries: {
      Abi.current(): isarLibraryPath,
    },
  );

  final isar = await Isar.open(
    [WorkoutSessionSchema, UserStatsSchema, DailyActivitySchema],
    directory: documentsDir,
  );

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 23, 59);
  final sampleSessions = <WorkoutSession>[
    _buildWalkSession(
      timestamp: today.subtract(const Duration(days: 1)),
      steps: 12400,
      calories: 496,
      distance: 5.8,
    ),
    _buildWalkSession(
      timestamp: today.subtract(const Duration(days: 3)),
      steps: 8300,
      calories: 332,
      distance: 3.9,
    ),
    _buildWalkSession(
      timestamp: today.subtract(const Duration(days: 8)),
      steps: 9100,
      calories: 364,
      distance: 4.3,
    ),
  ];

  await isar.writeTxn(() async {
    final existingSessions = await isar.workoutSessions.where().findAll();
    final walkIds = existingSessions
        .where(
            (session) => session.comboNames?.contains('Daily Steps') ?? false)
        .map((session) => session.id)
        .toList();

    if (walkIds.isNotEmpty) {
      await isar.workoutSessions.deleteAll(walkIds);
    }

    await isar.workoutSessions.putAll(sampleSessions);
  });

  await isar.close();
  stdout.writeln(
    'Seeded ${sampleSessions.length} walk history entries into $documentsDir',
  );
}

WorkoutSession _buildWalkSession({
  required DateTime timestamp,
  required int steps,
  required double calories,
  required double distance,
}) {
  return WorkoutSession()
    ..timestamp = timestamp
    ..sportType = SportType.custom
    ..heartRateReadings = const []
    ..averageBpm = 0
    ..peakBpm = 0
    ..timeInTargetZone = 0
    ..grade = steps >= 10000 ? 'A' : 'B'
    ..steps = steps
    ..calories = calories
    ..distance = distance
    ..comboNames = ['Daily Steps']
    ..comboTransitionSeconds = const [];
}
