import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionGate {
  AppPermissionGate._();

  static Future<void> _tail = Future<void>.value();

  static Future<T> run<T>(
    Future<T> Function() request, {
    String label = 'permission',
  }) {
    final previous = _tail.catchError((_) {});
    final next = previous.then((_) => request());
    _tail = next.then<void>((_) {}).catchError((error) {
      debugPrint('[AppPermissionGate] $label request failed: $error');
    });
    return next;
  }

  static Future<PermissionStatus> request(
    Permission permission, {
    required String label,
  }) {
    return run(
      () async {
        final status = await permission.status;
        if (status.isGranted ||
            status.isLimited ||
            status.isPermanentlyDenied) {
          return status;
        }

        return permission.request();
      },
      label: label,
    );
  }
}
