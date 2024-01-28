import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

import '../../Backend/Bluetooth/BluetoothManager.dart';
import '../../Backend/Settings.dart';
import '../intnDefs.dart';

class ScanForNewDevice extends ConsumerStatefulWidget {
  const ScanForNewDevice({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ScanForNewDevice();
}

class _ScanForNewDevice extends ConsumerState<ScanForNewDevice> {
  final ScrollController _controller = ScrollController();
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
          if (ref.read(preferencesProvider).autoConnectNewDevices) {
            Future(() => ref.read(knownDevicesProvider.notifier).connect(value));
          } else {
            devices[value.id] = value;
          }
        }
      }
      List<DiscoveredDevice> devicesList = devices.values.toList();
      return Column(
        children: [
          ListTile(
            dense: true,
            trailing: Switch(
              onChanged: (bool value) {
                setState(() {
                  ref.read(preferencesProvider).autoConnectNewDevices = value;
                });
                ref.read(preferencesProvider.notifier).store();
              },
              value: ref.read(preferencesProvider).autoConnectNewDevices,
            ),
            title: Text(scanDevicesAutoConnectTitle()),
          ),
          ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            controller: _controller,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(getNameFromBTName(devicesList[index].name)),
                trailing: Text(devicesList[index].id),
                onTap: () {
                  ref.watch(knownDevicesProvider.notifier).connect(devicesList[index]);
                  setState(() {
                    devices.remove(devicesList[index].id);
                  });
                  //Navigator.pop(context);
                },
              );
            },
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
