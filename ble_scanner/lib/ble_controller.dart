import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class BleController extends GetxController {
  // Streams
  Stream<List<ScanResult>> get scanResult => FlutterBluePlus.scanResults;
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;
  bool get isScanningNow => FlutterBluePlus.isScanningNow;

  final Rx<BluetoothDevice?> currentDevice = Rx<BluetoothDevice?>(null);
  final RxString currentDeviceName = ''.obs;
  final Rx<BluetoothConnectionState> connectionState =
      BluetoothConnectionState.disconnected.obs;
  final RxBool isConnecting = false.obs;
  final RxBool isDisconnecting = false.obs;
  final RxString connectionError = ''.obs;

  final Rx<int?> batteryLevel = Rx<int?>(null);
  final RxBool isReadingBattery = false.obs;
  final Rx<bool?> hasBatteryService = Rx<bool?>(null);

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  bool _isExplicitDisconnect = false;

  Future<bool> _requestPermissions() async {
    if (kIsWeb) {
      return true;
    }

    if (Platform.isAndroid) {
      final permissions = <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ];

      final statuses = await permissions.request();

      final scanGranted =
          statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final connectGranted =
          statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      final locationGranted = statuses[Permission.location]?.isGranted ?? false;

      final hasAndroid12Permissions = scanGranted && connectGranted;
      final hasLegacyPermissions = locationGranted;

      if (!hasAndroid12Permissions && !hasLegacyPermissions) {
        Get.snackbar(
          'Permissions Required',
          'Please grant Bluetooth and Location permissions in App Settings to scan for devices.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
        );
        return false;
      }
      return true;
    }

    return true;
  }

  /// Scans for nearby BLE devices.
  Future<void> scanDevices() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
        return;
      }

      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        Get.snackbar(
          'Bluetooth Unsupported',
          'Bluetooth is not supported or not available on this device.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
        );
        return;
      }

      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        return;
      }

      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        if (!kIsWeb && Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
            adapterState = await FlutterBluePlus.adapterState
                .firstWhere((s) => s == BluetoothAdapterState.on)
                .timeout(
                  const Duration(seconds: 5),
                  onTimeout: () => adapterState,
                );
          } catch (e) {
            debugPrint('BLE: turnOn error: $e');
          }
        }

        if (adapterState != BluetoothAdapterState.on) {
          Get.snackbar(
            'Bluetooth Disabled',
            'Please turn on Bluetooth to scan for nearby devices.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orangeAccent,
            colorText: Colors.white,
            margin: const EdgeInsets.all(12),
          );
          return;
        }
      }

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );
    } catch (e) {
      debugPrint('BLE scan error: $e');
      Get.snackbar(
        'Scan Error',
        'Could not start BLE scan: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  /// Connects to a selected BLE device and checks for the battery service.
  Future<void> connectToDevice(
    BluetoothDevice device, {
    String? displayName,
  }) async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      _isExplicitDisconnect = false;
      currentDevice.value = device;
      currentDeviceName.value = displayName ?? device.advName;
      isConnecting.value = true;
      connectionError.value = '';

      await _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        connectionState.value = state;

        if (state == BluetoothConnectionState.disconnected) {
          batteryLevel.value = null;
          hasBatteryService.value = null;

          if (!_isExplicitDisconnect) {
            Get.snackbar(
              'Device Disconnected',
              'Lost connection to "${currentDeviceName.value.isNotEmpty ? currentDeviceName.value : device.remoteId.str}".',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.redAccent,
              colorText: Colors.white,
              duration: const Duration(seconds: 5),
              mainButton: TextButton(
                onPressed: () => reconnectDevice(),
                child: const Text(
                  'RECONNECT',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }
        }
      });

      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      connectionState.value = BluetoothConnectionState.connected;

      await readBatteryLevel();
    } catch (e) {
      debugPrint('BLE: Connection error: $e');
      connectionState.value = BluetoothConnectionState.disconnected;
      connectionError.value = e.toString();
      Get.snackbar(
        'Connection Failed',
        'Could not connect to "${currentDeviceName.value.isNotEmpty ? currentDeviceName.value : device.remoteId.str}": $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        mainButton: TextButton(
          onPressed: () => reconnectDevice(),
          child: const Text(
            'RETRY',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } finally {
      isConnecting.value = false;
    }
  }

  Future<void> disconnectDevice() async {
    final device = currentDevice.value;
    if (device == null) return;

    try {
      _isExplicitDisconnect = true;
      isDisconnecting.value = true;
      await device.disconnect();
      connectionState.value = BluetoothConnectionState.disconnected;
      batteryLevel.value = null;
      hasBatteryService.value = null;
    } catch (e) {
      debugPrint('BLE: Disconnect error: $e');
      Get.snackbar(
        'Disconnect Error',
        'Error disconnecting from device: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isDisconnecting.value = false;
    }
  }

  Future<void> reconnectDevice() async {
    final device = currentDevice.value;
    if (device != null) {
      await connectToDevice(device, displayName: currentDeviceName.value);
    }
  }

  Future<void> readBatteryLevel() async {
    final device = currentDevice.value;
    if (device == null ||
        connectionState.value != BluetoothConnectionState.connected) {
      return;
    }

    try {
      isReadingBattery.value = true;
      final services = await device.discoverServices();

      for (final service in services) {
        final sUuid = service.serviceUuid.str.toLowerCase();
        if (sUuid == '180f') {
          for (final characteristic in service.characteristics) {
            final cUuid = characteristic.characteristicUuid.str.toLowerCase();
            if (cUuid == '2a19') {
              hasBatteryService.value = true;
              final value = await characteristic.read();
              if (value.isNotEmpty) {
                batteryLevel.value = value[0];
              }
              return;
            }
          }
        }
      }
      hasBatteryService.value = false;
    } catch (e) {
      debugPrint('BLE: Error reading battery level: $e');
      Get.snackbar(
        'Battery Read Error',
        'Could not read battery level: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isReadingBattery.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();

    FlutterBluePlus.scanResults.listen((results) {
      log('BLE: Devices found = ${results.length}');
    });
  }

  @override
  void onClose() {
    _connectionSubscription?.cancel();
    super.onClose();
  }
}
