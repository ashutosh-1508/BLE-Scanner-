import 'package:ble_scanner/ble_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

class DeviceDetailScreen extends StatelessWidget {
  final BluetoothDevice device;
  final String deviceDisplayName;

  const DeviceDetailScreen({
    super.key,
    required this.device,
    required this.deviceDisplayName,
  });

  IconData _getBatteryIcon(int level) {
    if (level >= 80) return Icons.battery_full;
    if (level >= 60) return Icons.battery_6_bar;
    if (level >= 40) return Icons.battery_4_bar;
    if (level >= 20) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor(int level) {
    if (level >= 50) return Colors.green;
    if (level >= 20) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BleController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          deviceDisplayName.isNotEmpty ? deviceDisplayName : 'Device Battery',
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Obx(() {
            final isConnected =
                controller.connectionState.value ==
                BluetoothConnectionState.connected;
            final isBusy =
                controller.isConnecting.value ||
                controller.isDisconnecting.value;

            if (isBusy) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            if (isConnected) {
              return IconButton(
                icon: const Icon(Icons.link_off),
                tooltip: 'Disconnect',
                onPressed: () => controller.disconnectDevice(),
              );
            } else {
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reconnect',
                onPressed: () => controller.reconnectDevice(),
              );
            }
          }),
        ],
      ),
      body: Obx(() {
        final state = controller.connectionState.value;
        final isConnected = state == BluetoothConnectionState.connected;
        final isConnecting = controller.isConnecting.value;
        final isDisconnecting = controller.isDisconnecting.value;
        final batteryLevel = controller.batteryLevel.value;
        final isReadingBattery = controller.isReadingBattery.value;
        final hasBatteryService = controller.hasBatteryService.value;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          radius: 24,
                          child: Icon(
                            Icons.bluetooth,
                            size: 28,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deviceDisplayName.isNotEmpty
                                    ? deviceDisplayName
                                    : 'Unknown Device',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                device.remoteId.str,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    Row(
                      children: [
                        const Text(
                          'Connection Status:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isConnected
                                ? Colors.green.withValues(alpha: 0.12)
                                : (isConnecting
                                      ? Colors.orange.withValues(alpha: 0.12)
                                      : (isDisconnecting
                                            ? Colors.grey.withValues(
                                                alpha: 0.12,
                                              )
                                            : Colors.red.withValues(
                                                alpha: 0.12,
                                              ))),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isConnected
                                  ? Colors.green
                                  : (isConnecting
                                        ? Colors.orange
                                        : (isDisconnecting
                                              ? Colors.grey
                                              : Colors.red)),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isConnecting || isDisconnecting) ...[
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: isConnecting
                                        ? Colors.orange
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ] else ...[
                                Icon(
                                  isConnected
                                      ? Icons.check_circle
                                      : Icons.cancel_outlined,
                                  size: 14,
                                  color: isConnected
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                isConnecting
                                    ? 'Connecting...'
                                    : (isConnected
                                          ? 'Connected'
                                          : (isDisconnecting
                                                ? 'Disconnecting...'
                                                : 'Disconnected')),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isConnected
                                      ? Colors.green.shade800
                                      : (isConnecting
                                            ? Colors.orange.shade800
                                            : (isDisconnecting
                                                  ? Colors.grey.shade800
                                                  : Colors.red.shade800)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (isConnected) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => controller.disconnectDevice(),
                              icon: const Icon(Icons.link_off, size: 18),
                              label: const Text('Disconnect'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isConnecting
                                  ? null
                                  : () => controller.reconnectDevice(),
                              icon: const Icon(Icons.sync, size: 18),
                              label: Text(
                                isConnecting ? 'Connecting...' : 'Reconnect',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'Battery Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (isReadingBattery) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Reading device battery level...',
                        style: TextStyle(fontSize: 15, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (batteryLevel != null) ...[
              Card(
                elevation: 3,
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.green.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getBatteryIcon(batteryLevel),
                            size: 64,
                            color: _getBatteryColor(batteryLevel),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$batteryLevel%',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: _getBatteryColor(batteryLevel),
                                ),
                              ),
                              const Text(
                                'Battery Level',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Standard Battery Service (0x180F)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => controller.readBatteryLevel(),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (hasBatteryService == false) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.battery_unknown,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Battery Service Not Supported',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'This device does not advertise the standard Bluetooth Battery Service (UUID 0x180F / 0x2A19).',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else if (!isConnected) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.bluetooth_disabled,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Connect to this device to read its battery level.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}
