import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';

Future<void> initializeTestIsarCore() async {
  final homeDir = Platform.environment['HOME'];
  final cachedLibraryPath = homeDir == null
      ? null
      : '$homeDir/.pub-cache/hosted/pub.dev/'
          'isar_community_flutter_libs-3.3.2/macos/libisar.dylib';

  if (cachedLibraryPath != null && File(cachedLibraryPath).existsSync()) {
    await Isar.initializeIsarCore(
      libraries: {
        Abi.current(): cachedLibraryPath,
      },
    );
    return;
  }

  await Isar.initializeIsarCore(download: true);
}
