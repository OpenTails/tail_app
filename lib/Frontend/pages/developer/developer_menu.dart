import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';

import '../../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../../Backend/Definitions/Device/device_definition.dart';
import '../../../Backend/device_registry.dart';
import '../../../constants.dart';

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
            title: const Text("Throw an error"),
            leading: const Icon(Icons.bug_report),
            subtitle: const Text("Sends an error to sentry"),
            onTap: () {
              throw Exception('Sentry Test');
            },
          ),
          ListTile(
            title: Text(
              "Internal Settings Debug",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            title: const Text(hasCompletedOnboarding),
            trailing: Switch(
              value: SentryHive.box(settings).get(hasCompletedOnboarding, defaultValue: hasCompletedOnboarding),
              onChanged: (bool value) {
                setState(
                  () {
                    SentryHive.box(settings).put(hasCompletedOnboarding, value);
                  },
                );
              },
            ),
          ),
          ListTile(
            title: const Text(shouldDisplayReview),
            trailing: Switch(
              value: SentryHive.box(settings).get(shouldDisplayReview, defaultValue: shouldDisplayReviewDefault),
              onChanged: (bool value) {
                setState(
                  () {
                    SentryHive.box(settings).put(shouldDisplayReview, value);
                  },
                );
              },
            ),
          ),
          ListTile(
            title: const Text(hasDisplayedReview),
            trailing: Switch(
              value: SentryHive.box(settings).get(hasDisplayedReview, defaultValue: hasDisplayedReviewDefault),
              onChanged: (bool value) {
                setState(
                  () {
                    SentryHive.box(settings).put(hasDisplayedReview, value);
                  },
                );
              },
            ),
          ),
          ListTile(
            title: const Text(gearDisconnectCount),
            subtitle: Slider(
              divisions: 6,
              max: 6,
              min: 0,
              value: SentryHive.box(settings).get(gearDisconnectCount, defaultValue: gearDisconnectCountDefault).toDouble(),
              onChanged: (double value) {
                setState(() {
                  SentryHive.box(settings).put(gearDisconnectCount, value.toInt());
                });
              },
            ),
          ),
          ListTile(
            title: const Text(firstLaunchSensors),
            trailing: Switch(
              value: SentryHive.box(settings).get(firstLaunchSensors, defaultValue: firstLaunchSensorsDefault),
              onChanged: (bool value) {
                setState(
                  () {
                    SentryHive.box(settings).put(firstLaunchSensors, value);
                  },
                );
              },
            ),
          ),
          ListTile(
            title: const Text(showDebugging),
            trailing: Switch(
              value: SentryHive.box(settings).get(showDebugging, defaultValue: showDebuggingDefault),
              onChanged: (bool value) {
                setState(
                  () {
                    SentryHive.box(settings).put(showDebugging, value);
                    context.pop();
                  },
                );
              },
            ),
          ),
          ListTile(
            title: Text(
              "Gear Debug",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            title: const Text("Add new Device"),
            leading: const Icon(Icons.add),
            trailing: DropdownMenu<BaseDeviceDefinition>(
              initialSelection: null,
              onSelected: (value) {
                if (value != null) {
                  setState(
                    () {
                      BaseStoredDevice baseStoredDevice;
                      BaseStatefulDevice statefulDevice;
                      baseStoredDevice = BaseStoredDevice(value.uuid, "DEV${value.deviceType.name}", value.deviceType.color.value);
                      baseStoredDevice.name = getNameFromBTName(value.btName);
                      statefulDevice = BaseStatefulDevice(value, baseStoredDevice, null);
                      if (!ref.read(knownDevicesProvider).containsKey(baseStoredDevice.btMACAddress)) {
                        ref.read(knownDevicesProvider.notifier).add(statefulDevice);
                      }
                    },
                  );
                }
              },
              dropdownMenuEntries: DeviceRegistry.allDevices.map((e) => DropdownMenuEntry(value: e, label: e.btName)).toList(),
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
            title: const Text("isAnyGearConnected"),
            trailing: Switch(
              value: isAnyGearConnected.value,
              onChanged: (bool value) {
                setState(
                  () {
                    isAnyGearConnected.value = value;
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
