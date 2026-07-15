import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_permission_gate.dart';

class HealthAuthorization {
  static Future<bool>? _stepReadAuthorization;
  static DateTime? _lastDeniedAt;

  static Future<bool> ensureStepReadAccess(
    Health health, {
    bool interactive = true,
  }) async {
    if (!interactive) {
      return hasStepReadAccess(health);
    }

    final deniedAt = _lastDeniedAt;
    if (deniedAt != null &&
        DateTime.now().difference(deniedAt) < const Duration(seconds: 10)) {
      return false;
    }

    final pending = _stepReadAuthorization;
    if (pending != null) {
      return pending;
    }

    final future = AppPermissionGate.run(
      () => _requestStepReadAccess(health),
      label: 'health step read',
    );
    _stepReadAuthorization = future;

    try {
      return await future;
    } finally {
      if (identical(_stepReadAuthorization, future)) {
        _stepReadAuthorization = null;
      }
    }
  }

  static Future<bool> hasStepReadAccess(Health health) async {
    debugPrint('[HealthAuth] Checking existing step read access.');
    await health.configure();

    if (Platform.isAndroid) {
      final activityPermission = await Permission.activityRecognition.status;
      debugPrint(
        '[HealthAuth] Activity recognition status: $activityPermission',
      );
      if (!activityPermission.isGranted) {
        return false;
      }
    }

    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];
    final hasPermissions =
        await health.hasPermissions(types, permissions: permissions);
    debugPrint('[HealthAuth] Health step hasPermissions: $hasPermissions');
    return hasPermissions == true;
  }

  static Future<bool> _requestStepReadAccess(Health health) async {
    debugPrint('[HealthAuth] Requesting step read access.');
    await health.configure();

    if (Platform.isAndroid) {
      final activityPermission = await Permission.activityRecognition.request();
      debugPrint(
        '[HealthAuth] Activity recognition request result: $activityPermission',
      );
      if (!activityPermission.isGranted) {
        debugPrint('[HealthAuth] Activity recognition permission not granted.');
        _lastDeniedAt = DateTime.now();
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }

    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];

    final hasPermissions =
        await health.hasPermissions(types, permissions: permissions);
    debugPrint(
        '[HealthAuth] Health step hasPermissions before request: $hasPermissions');
    if (hasPermissions == true) {
      return true;
    }

    final granted =
        await health.requestAuthorization(types, permissions: permissions);
    debugPrint('[HealthAuth] Health step request result: $granted');
    if (!granted) {
      debugPrint('[HealthAuth] Health Connect step permission not granted.');
      _lastDeniedAt = DateTime.now();
    } else {
      _lastDeniedAt = null;
    }
    return granted;
  }
}
