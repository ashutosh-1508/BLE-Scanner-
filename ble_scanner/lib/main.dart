import 'package:ble_scanner/ble_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Get.put(BleController());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const BLE());
  }
}

class BLE extends StatefulWidget {
  const BLE({super.key});

  @override
  State<BLE> createState() => _BLEState();
}

class _BLEState extends State<BLE> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: Text('BLE Devices')),
        body: GetBuilder<BleController>(
          builder: (BleController controller) {
            return Center(
              child: Column(
                spacing: 4,
                children: [
                  Expanded(
                    child: StreamBuilder<List<ScanResult>>(
                      stream: controller.scanResult,
                      builder: (context, snapshot) {
                        final devices = snapshot.data ?? [];

                        if (devices.isEmpty) {
                          return const Center(child: Text('No devices found'));
                        }

                        return ListView.builder(
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            final data = devices[index];

                            return Card(
                              child: ListTile(
                                title: Text(
                                  data.device.advName.isNotEmpty
                                      ? data.device.advName
                                      : data.device.remoteId.toString(),
                                ),
                                trailing: Text('${data.rssi} dBm'),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => controller.scanDevices(),
                    child: const Text('Scan'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
