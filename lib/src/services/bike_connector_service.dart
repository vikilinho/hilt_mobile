import 'dart:async';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum BikeConnectionStatus { disconnected, scanning, connecting, connected }

class BikeConnectorService {
  BluetoothDevice? _connectedDevice;
  final _statusController = StreamController<BikeConnectionStatus>.broadcast();
  final _dataController = StreamController<IndoorBike>.broadcast();

  Stream<BikeConnectionStatus> get statusStream => _statusController.stream;
  Stream<IndoorBike> get dataStream => _dataController.stream;

  BikeConnectionStatus _status = BikeConnectionStatus.disconnected;
  BikeConnectionStatus get status => _status;

  BikeConnectorService() {
    _statusController.add(_status);
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> scanAndConnect() async {
    await requestPermissions();

    if (_status == BikeConnectionStatus.scanning ||
        _status == BikeConnectionStatus.connecting) {
      return;
    }

    _updateStatus(BikeConnectionStatus.scanning);

    StreamSubscription? scanSubscription;
    bool found = false;

    try {
      // 1. Listen to results
      scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        if (found) return;

        for (final result in results) {
          final device = result.device;
          final name = device.platformName.toUpperCase();

          // Check for Slunse specifically OR standard FTMS
          bool isTarget = name.contains("SLUNSE") ||
              name.contains("KINOMAP") ||
              result.advertisementData.serviceUuids.contains(Guid("1826"));

          if (isTarget) {
            found = true;
            await scanSubscription?.cancel();
            // Stop scanning before connecting
            await FlutterBluePlus.stopScan();
            await connect(device);
            break;
          }
        }
      });

      // 2. Start Broad Scan (No filters)
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // 3. Timeout
      await Future.delayed(const Duration(seconds: 10));
      if (!found) {
        await scanSubscription.cancel();
        if (_status != BikeConnectionStatus.connected) {
          _updateStatus(BikeConnectionStatus.disconnected);
        }
      }
    } catch (e) {
      print("Scan Error: $e");
      await scanSubscription?.cancel();
      _updateStatus(BikeConnectionStatus.disconnected);
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    _updateStatus(BikeConnectionStatus.connecting);

    try {
      await FTMS.connectToFTMSDevice(device);
      _connectedDevice = device;
      _updateStatus(BikeConnectionStatus.connected);

      // Start listening for data
      await FTMS.useDeviceDataCharacteristic(device, (DeviceData data) {
        if (data is IndoorBike) {
          _dataController.add(data);
        }
      });
    } catch (e) {
      print("Connection Error: $e");
      _updateStatus(BikeConnectionStatus.disconnected);
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await FTMS.disconnectFromFTMSDevice(_connectedDevice!);
      _connectedDevice = null;
    }
    _updateStatus(BikeConnectionStatus.disconnected);
  }

  void _updateStatus(BikeConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }
}
