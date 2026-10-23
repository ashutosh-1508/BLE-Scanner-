import 'package:ble_scanner/ble_controller.dart';
import 'package:ble_scanner/device_detail_screen.dart';
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
    return GetMaterialApp(
      title: 'BLE Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const BLE(),
    );
  }
}

class BLE extends StatefulWidget {
  const BLE({super.key});

  @override
  State<BLE> createState() => _BLEState();
}

class _BLEState extends State<BLE> {
  String _getDeviceDisplayName(ScanResult data) {
    if (data.advertisementData.advName.isNotEmpty) {
      return data.advertisementData.advName;
    }
    if (data.device.platformName.isNotEmpty) {
      return data.device.platformName;
    }
    if (data.device.advName.isNotEmpty) {
      return data.device.advName;
    }
    return 'Unknown Device';
  }

  void _onDeviceSelected(
    BleController controller,
    ScanResult data,
    String name,
  ) {
    final isAlreadyConnected =
        controller.currentDevice.value?.remoteId == data.device.remoteId &&
        controller.connectionState.value == BluetoothConnectionState.connected;

    if (!isAlreadyConnected) {
      controller.connectToDevice(data.device, displayName: name);
    }

    Get.to(
      () => DeviceDetailScreen(device: data.device, deviceDisplayName: name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BleController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scanner'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          StreamBuilder<bool>(
            stream: controller.isScanning,
            initialData: controller.isScanningNow,
            builder: (context, snapshot) {
              final isScanning = snapshot.data ?? false;
              if (isScanning) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Scan Devices',
                onPressed: () => controller.scanDevices(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Scanning progress indicator
          StreamBuilder<bool>(
            stream: controller.isScanning,
            initialData: controller.isScanningNow,
            builder: (context, snapshot) {
              final isScanning = snapshot.data ?? false;
              if (isScanning) {
                return const LinearProgressIndicator();
              }
              return const SizedBox(height: 2);
            },
          ),

          // Banner for active connected device (if any)
          Obx(() {
            final activeDevice = controller.currentDevice.value;
            final state = controller.connectionState.value;

            if (activeDevice != null &&
                state == BluetoothConnectionState.connected) {
              final name = controller.currentDeviceName.value.isNotEmpty
                  ? controller.currentDeviceName.value
                  : activeDevice.remoteId.str;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Connected to Device',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Get.to(
                          () => DeviceDetailScreen(
                            device: activeDevice,
                            deviceDisplayName: name,
                          ),
                        );
                      },
                      child: const Text('VIEW'),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          // Discovered devices list
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: controller.scanResult,
              builder: (context, snapshot) {
                final devices = snapshot.data ?? [];

                return StreamBuilder<bool>(
                  stream: controller.isScanning,
                  initialData: controller.isScanningNow,
                  builder: (context, scanSnapshot) {
                    final isScanning = scanSnapshot.data ?? false;

                    if (devices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isScanning
                                  ? Icons.bluetooth_searching
                                  : Icons.bluetooth_disabled,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isScanning
                                  ? 'Searching for nearby BLE devices...'
                                  : 'No devices found.\nTap "Scan Devices" to start scanning.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: devices.length,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      itemBuilder: (context, index) {
                        final data = devices[index];
                        final name = _getDeviceDisplayName(data);
                        final id = data.device.remoteId.str;
                        final rssi = data.rssi;
                        final isConnectable =
                            data.advertisementData.connectable;

                        return Obx(() {
                          final isTargetConnected =
                              controller.currentDevice.value?.remoteId ==
                                  data.device.remoteId &&
                              controller.connectionState.value ==
                                  BluetoothConnectionState.connected;
                          final isTargetConnecting =
                              controller.currentDevice.value?.remoteId ==
                                  data.device.remoteId &&
                              controller.isConnecting.value;

                          return Card(
                            elevation: 1.5,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isTargetConnected
                                  ? const BorderSide(
                                      color: Colors.green,
                                      width: 1.5,
                                    )
                                  : BorderSide.none,
                            ),
                            child: ListTile(
                              onTap: () =>
                                  _onDeviceSelected(controller, data, name),
                              leading: CircleAvatar(
                                backgroundColor: isTargetConnected
                                    ? Colors.green.shade100
                                    : Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                child: Icon(
                                  name == 'Unknown Device'
                                      ? Icons.bluetooth
                                      : Icons.devices,
                                  color: isTargetConnected
                                      ? Colors.green.shade800
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    id,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.signal_cellular_alt,
                                        size: 14,
                                        color: rssi > -70
                                            ? Colors.green
                                            : (rssi > -85
                                                  ? Colors.orange
                                                  : Colors.red),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$rssi dBm',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (isConnectable) ...[
                                        const SizedBox(width: 8),
                                        const Text(
                                          '• Connectable',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: isTargetConnecting
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : (isTargetConnected
                                        ? const Chip(
                                            label: Text(
                                              'CONNECTED',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            backgroundColor: Colors.transparent,
                                            side: BorderSide(
                                              color: Colors.green,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          )
                                        : ElevatedButton(
                                            onPressed: () => _onDeviceSelected(
                                              controller,
                                              data,
                                              name,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                            ),
                                            child: const Text('Connect'),
                                          )),
                            ),
                          );
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Scan button at the bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<bool>(
              stream: controller.isScanning,
              initialData: controller.isScanningNow,
              builder: (context, snapshot) {
                final isScanning = snapshot.data ?? false;

                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isScanning
                          ? Colors.redAccent
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => controller.scanDevices(),
                    icon: isScanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      isScanning ? 'Stop Scanning' : 'Scan Devices',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
