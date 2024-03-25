import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging_flutter/logging_flutter.dart';

import '../../../Backend/Bluetooth/BluetoothManager.dart';
import '../../../Backend/Definitions/Device/BaseDeviceDefinition.dart';
import '../../../Backend/DeviceRegistry.dart';

class DeveloperMenu extends ConsumerStatefulWidget {
  const DeveloperMenu({super.key});

  @override
  ConsumerState<DeveloperMenu> createState() => _DeveloperMenuState();
}

class _DeveloperMenuState extends ConsumerState<DeveloperMenu> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Menu'),
      ),
      body: ListView(
        primary: true,
        children: [
          ListTile(
            title: Text(
              "Logging Debug",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            title: const Text("Logs"),
            leading: const Icon(Icons.list),
            subtitle: const Text("Application Logs"),
            onTap: () {
              LogConsole.open(context);
            },
          ),
          ListTile(
            title: const Text("Crash"),
            leading: const Icon(Icons.bug_report),
            subtitle: const Text("Test crash reporting"),
            onTap: () {
              throw Exception('Sentry Test');
            },
          ),
          ListTile(
            title: Text(
              "Gear Debug",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            title: const Text("Add Ear"),
            leading: const Icon(Icons.add),
            onTap: () {
              if (!ref.read(knownDevicesProvider).containsKey("DEV")) {
                BaseStoredDevice baseStoredDevice;
                BaseStatefulDevice statefulDevice;
                BaseDeviceDefinition? deviceDefinition = DeviceRegistry.getByService([Uuid.parse("927dee04-ddd4-4582-8e42-69dc9fbfae66")]);
                baseStoredDevice = BaseStoredDevice(deviceDefinition!.uuid, "DEV", deviceDefinition.deviceType.color.value);
                baseStoredDevice.name = getNameFromBTName(deviceDefinition.btName);
                statefulDevice = BaseStatefulDevice(deviceDefinition, baseStoredDevice, null);
                statefulDevice.deviceConnectionState.value = ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).firstOrNull?.deviceConnectionState.value ?? DeviceConnectionState.connected;
                statefulDevice.battery.value = ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).firstOrNull?.battery.value ?? 100;
                ref.read(knownDevicesProvider.notifier).add(statefulDevice);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Did not add dev gear, Gear already exists")),
                );
              }
            },
          ),
          ListTile(
            title: const Text("Add Tail"),
            leading: const Icon(Icons.add),
            onTap: () {
              if (!ref.read(knownDevicesProvider).containsKey("DEV2")) {
                BaseStoredDevice baseStoredDevice;
                BaseStatefulDevice statefulDevice;
                BaseDeviceDefinition? deviceDefinition = DeviceRegistry.getByService([Uuid.parse("3af2108b-d066-42da-a7d4-55648fa0a9b6")]);
                baseStoredDevice = BaseStoredDevice(deviceDefinition!.uuid, "DEV2", deviceDefinition.deviceType.color.value);
                baseStoredDevice.name = getNameFromBTName(deviceDefinition.btName);
                statefulDevice = BaseStatefulDevice(deviceDefinition, baseStoredDevice, null);
                statefulDevice.deviceConnectionState.value = ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).firstOrNull?.deviceConnectionState.value ?? DeviceConnectionState.connected;
                statefulDevice.battery.value = ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).firstOrNull?.battery.value ?? 100;
                ref.read(knownDevicesProvider.notifier).add(statefulDevice);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Did not add dev gear, Gear already exists")),
                );
              }
            },
          ),
          ListTile(
            title: const Text("Set Connection State"),
            leading: const Icon(Icons.bluetooth),
            trailing: DropdownMenu<DeviceConnectionState>(
              initialSelection: ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).firstOrNull?.deviceConnectionState.value ?? DeviceConnectionState.connected,
              onSelected: (value) {
                if (value != null) {
                  setState(
                    () {
                      ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).forEach(
                        (element) {
                          element.deviceConnectionState.value = value;
                        },
                      );
                    },
                  );
                }
              },
              dropdownMenuEntries: DeviceConnectionState.values
                  .map(
                    (e) => DropdownMenuEntry(value: e, label: e.name),
                  )
                  .toList(),
            ),
          ),
          ListTile(
            title: const Text("Set Battery Level"),
            leading: const Icon(Icons.battery_full),
            subtitle: Slider(
              min: -1,
              max: 100,
              value: ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).firstOrNull?.battery.value ?? 100,
              onChanged: (double value) {
                setState(
                  () {
                    ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).forEach(
                      (element) {
                        element.battery.value = value;
                      },
                    );
                  },
                );
              },
            ),
          ),
          ListTile(
            title: const Text("Set RSSI Level"),
            leading: const Icon(Icons.battery_full),
            subtitle: Slider(
              min: -80,
              max: -1,
              value: ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).firstOrNull?.rssi.value.toDouble() ?? -1,
              onChanged: (double value) {
                setState(
                  () {
                    ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).forEach(
                      (element) {
                        element.rssi.value = value.round();
                      },
                    );
                  },
                );
              },
            ),
          ),
          ListTile(
            title: const Text("Remove Dev Gear"),
            leading: const Icon(Icons.delete),
            onTap: () {
              ref.read(knownDevicesProvider).removeWhere((key, value) => key.contains("DEV"));
              ref.read(knownDevicesProvider.notifier).remove(""); // force update
            },
          ),
        ],
      ),
    );
  }
}
