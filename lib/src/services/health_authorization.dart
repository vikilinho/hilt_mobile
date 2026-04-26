import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthAuthorization {
  static Future<bool>? _stepReadAuthorization;
  static DateTime? _lastDeniedAt;

  static Future<bool> ensureStepReadAccess(Health health) async {
    final deniedAt = _lastDeniedAt;
    if (deniedAt != null &&
        DateTime.now().difference(deniedAt) < const Duration(seconds: 10)) {
      return false;
    }

    final pending = _stepReadAuthorization;
    if (pending != null) {
      return pending;
    }

    final future = _requestStepReadAccess(health);
    _stepReadAuthorization = future;

    try {
      return await future;
    } finally {
      if (identical(_stepReadAuthorization, future)) {
        _stepReadAuthorization = null;
      }
    }
  }

  static Future<bool> _requestStepReadAccess(Health health) async {
    await health.configure();

    if (Platform.isAndroid) {
      final activityPermission = await Permission.activityRecognition.request();
      if (!activityPermission.isGranted) {
        debugPrint('[HealthAuth] Activity recognition permission not granted.');
        _lastDeniedAt = DateTime.now();
        return false;
      }
    }

    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];

    final hasPermissions =
        await health.hasPermissions(types, permissions: permissions);
    if (hasPermissions == true) {
      return true;
    }

    final granted =
        await health.requestAuthorization(types, permissions: permissions);
    if (!granted) {
      debugPrint('[HealthAuth] Health Connect step permission not granted.');
      _lastDeniedAt = DateTime.now();
    } else {
      _lastDeniedAt = null;
    }
    return granted;
  }
}
