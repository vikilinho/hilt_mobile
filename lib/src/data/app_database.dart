import 'package:hilt_core/hilt_core.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

class AppDatabase {
  AppDatabase._();

  static Future<Isar>? _opening;

  static Future<Isar> open() {
    final existing = Isar.getInstance();
    if (existing != null) return Future.value(existing);
    return _opening ??= _openInternal();
  }

  static Future<Isar> _openInternal() async {
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open(
      [
        WorkoutSessionSchema,
        UserStatsSchema,
        DailyActivitySchema,
        HydrationEntrySchema,
        HydrationDaySchema,
        HydrationProfileSchema,
      ],
      directory: dir.path,
    );
  }
}
