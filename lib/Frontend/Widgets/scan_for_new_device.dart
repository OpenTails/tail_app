import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

import '../../Backend/Bluetooth/BluetoothManager.dart';
import '../intnDefs.dart';

class ScanForNewDevice extends ConsumerStatefulWidget {
  const ScanForNewDevice({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ScanForNewDevice();
}

class _ScanForNewDevice extends ConsumerState<ScanForNewDevice> {
  Map<String, DiscoveredDevice> devices = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    AsyncValue<BleStatus> btStatus = ref.watch(btStatusProvider);
    if (btStatus.valueOrNull != null && btStatus.valueOrNull == BleStatus.ready) {
      final AsyncValue<DiscoveredDevice> foundDevices = ref.watch(scanForDevicesProvider);
      if (foundDevices.valueOrNull != null) {
        DiscoveredDevice? value = foundDevices.valueOrNull;
        if (value != null && !devices.containsKey(value.id)) {
          if (SentryHive.box('settings').get('autoConnectNewDevices', defaultValue: false)) {
            Future(() => ref.read(knownDevicesProvider.notifier).connect(value));
          } else {
            devices[value.id] = value;
          }
        }
      }
      return Column(
        children: [
          ListTile(
            dense: true,
            trailing: Switch(
              onChanged: (bool value) {
                setState(() {
                  SentryHive.box('settings').put('autoConnectNewDevices', value);
                });
              },
              value: SentryHive.box('settings').get('autoConnectNewDevices', defaultValue: false),
            ),
            title: Text(scanDevicesAutoConnectTitle()),
          ),
          Wrap(
            children: devices.values
                .map(
                  (e) => ListTile(
                    title: Text(getNameFromBTName(e.name)),
                    trailing: Text(e.id),
                    onTap: () {
                      ref.watch(knownDevicesProvider.notifier).connect(e);
                      setState(
                        () {
                          devices.remove(e.id);
                        },
                      );
                      //Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          ),
          Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(scanDevicesScanMessage()),
                    )
                  ],
                ),
              )),
        ],
      );
    } else {
      return Center(
        child: Text(actionsNoBluetooth()), //TODO: More detail
      );
    }
  }
}
