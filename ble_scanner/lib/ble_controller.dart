import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class BleController extends GetxController {
  Future<void> scanDevices() async {
    try {
      print('BLE: Requesting permissions');

      final scanPermission = await Permission.bluetoothScan.request();

      final connectPermission = await Permission.bluetoothConnect.request();

      if (!scanPermission.isGranted || !connectPermission.isGranted) {
        print('BLE: Bluetooth permissions not granted');
        return;
      }

      print('BLE: Starting 10-second scan');

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      print('BLE: Scan started successfully');
    } catch (e) {
      print('BLE scan error: $e');
    }
  }

  Stream<List<ScanResult>> get scanResult => FlutterBluePlus.scanResults;

  @override
  void onInit() {
    super.onInit();

    FlutterBluePlus.scanResults.listen((results) {
      print('BLE: Devices found = ${results.length}');

      for (final result in results) {
        print(
          'BLE: Name=${result.device.advName}, '
          'ID=${result.device.remoteId}, '
          'RSSI=${result.rssi}',
        );
      }
    });
  }
}
