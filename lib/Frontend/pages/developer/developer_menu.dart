import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging_flutter/logging_flutter.dart';

import '../../../Backend/Bluetooth/BluetoothManager.dart';
import '../../../Backend/Definitions/Device/BaseDeviceDefinition.dart';
import '../../../Backend/DeviceRegistry.dart';

class DeveloperMenu extends ConsumerStatefulWidget {
  const DeveloperMenu({super.key});

  //TODO: Show hidden device state/values
  //TODO: Steal Snacks
  //TODO: Backup/Restore json
  @override
  ConsumerState<DeveloperMenu> createState() => _DeveloperMenuState();
}

class _DeveloperMenuState extends ConsumerState<DeveloperMenu> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Menu'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
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
                baseStoredDevice = BaseStoredDevice(deviceDefinition!.uuid, "DEV");
                baseStoredDevice.name = getNameFromBTName(deviceDefinition.btName);
                statefulDevice = BaseStatefulDevice(deviceDefinition, baseStoredDevice, null);
                statefulDevice.deviceConnectionState.value = ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).firstOrNull?.deviceConnectionState.value ?? DeviceConnectionState.connected;
                statefulDevice.battery.value = ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).firstOrNull?.battery.value ?? 100;
                ref.read(knownDevicesProvider.notifier).add(statefulDevice);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: AwesomeSnackbarContent(title: "Gear already Exists", message: "Did not add dev gear, Gear already exists", contentType: ContentType.failure),
                  ),
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
                baseStoredDevice = BaseStoredDevice(deviceDefinition!.uuid, "DEV2");
                baseStoredDevice.name = getNameFromBTName(deviceDefinition.btName);
                statefulDevice = BaseStatefulDevice(deviceDefinition, baseStoredDevice, null);
                statefulDevice.deviceConnectionState.value = ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).firstOrNull?.deviceConnectionState.value ?? DeviceConnectionState.connected;
                statefulDevice.battery.value = ref.read(knownDevicesProvider).values.where((element) => element.baseStoredDevice.btMACAddress.contains("DEV")).firstOrNull?.battery.value ?? 100;
                ref.read(knownDevicesProvider.notifier).add(statefulDevice);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    elevation: 0,
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.transparent,
                    content: AwesomeSnackbarContent(title: "Gear already Exists", message: "Did not add dev gear, Gear already exists", contentType: ContentType.failure),
                  ),
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
            title: const Text("Remove Dev Gear"),
            leading: const Icon(Icons.delete),
            onTap: () {
              ref.read(knownDevicesProvider).removeWhere((key, value) => key.contains("DEV"));
              ref.read(knownDevicesProvider.notifier).remove(""); // force update
            },
          ),
          ListTile(
            title: Text(
              "Stored JSON",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
/*          ListTile( //TODO: debug hive box
            title: const Text("Triggers"),
            onTap: () {
              context.push('/settings/developer/json', extra: const JsonEncoder.withIndent("    ").convert(prefs.getStringList("triggers")));
            },
          ),
          ListTile(
            title: const Text("Sequences"),
            onTap: () {
              context.push('/settings/developer/json', extra: const JsonEncoder.withIndent("    ").convert(prefs.getStringList("sequences")));
            },
          ),
          ListTile(
            title: const Text("Devices"),
            onTap: () {
              context.push('/settings/developer/json', extra: const JsonEncoder.withIndent("    ").convert(prefs.getStringList("devices")));
            },
          ),
          ListTile(
            title: const Text("Settings"),
            onTap: () {
              context.push('/settings/developer/json', extra: prefs.getString("settings"));
            },
          )*/
        ],
      ),
    );
  }
}
