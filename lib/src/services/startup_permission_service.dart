import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_permission_gate.dart';
import 'health_sync_service.dart';

class StartupPermissionService {
  StartupPermissionService._();

  static Future<void>? _requestInFlight;
  static bool _didRequestForProcess = false;

  static Future<void> requestAppStartupPermissions({
    required HealthSyncService healthSyncService,
  }) {
    if (_didRequestForProcess) {
      return Future.value();
    }

    final inFlight = _requestInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final request = _requestAppStartupPermissions(
      healthSyncService: healthSyncService,
    );
    _requestInFlight = request;

    return request.whenComplete(() {
      _didRequestForProcess = true;
      _requestInFlight = null;
    });
  }

  static Future<void> _requestAppStartupPermissions({
    required HealthSyncService healthSyncService,
  }) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    await _requestPermission(
      Permission.activityRecognition,
      label: 'activity recognition',
    );

    await healthSyncService.fetchDailySteps(
      interactiveAuthorization: true,
    );
  }

  static Future<void> _requestPermission(
    Permission permission, {
    required String label,
  }) async {
    try {
      final status = await AppPermissionGate.request(
        permission,
        label: label,
      );
      if (status.isPermanentlyDenied) {
        debugPrint(
          '[StartupPermissions] $label permission is permanently denied.',
        );
        return;
      }

      debugPrint('[StartupPermissions] $label permission: $status');
    } catch (error) {
      debugPrint(
        '[StartupPermissions] Unable to request $label permission: $error',
      );
    }
  }
}
