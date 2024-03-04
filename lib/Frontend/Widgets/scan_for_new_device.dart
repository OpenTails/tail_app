import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

import '../../Backend/Bluetooth/BluetoothManager.dart';
import '../../main.dart';
import '../intnDefs.dart';

class ScanForNewDevice extends ConsumerStatefulWidget {
  ScanForNewDevice({super.key, required this.scrollController});

  ScrollController scrollController;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ScanForNewDevice();
}

class _ScanForNewDevice extends ConsumerState<ScanForNewDevice> {
  Map<String, DiscoveredDevice> devices = {};

  @override
  void initState() {
    devices = {};
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
          devices[value.id] = value;
        }
      }
      return Column(
        children: [
          ListView.builder(
            shrinkWrap: true,
            controller: widget.scrollController,
            itemCount: devices.values.length,
            itemBuilder: (BuildContext context, int index) {
              DiscoveredDevice e = devices.values.toList()[index];
              return FadeIn(
                delay: const Duration(milliseconds: 100),
                child: ListTile(
                  title: Text(getNameFromBTName(e.name)),
                  trailing: Text(e.id),
                  onTap: () {
                    ref.watch(knownDevicesProvider.notifier).connect(e);
                    plausible.event(name: "Connect New Gear", props: {"Gear Type": e.name});
                    setState(
                      () {
                        devices.remove(e.id);
                      },
                    );
                    Navigator.pop(context);
                  },
                ),
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
