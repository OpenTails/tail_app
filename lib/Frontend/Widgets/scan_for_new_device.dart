import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../main.dart';
import '../intn_defs.dart';

class ScanForNewDevice extends ConsumerStatefulWidget {
  const ScanForNewDevice({super.key, required this.scrollController});

  final ScrollController scrollController;

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
      return ListView(
        controller: widget.scrollController,
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
                    Spin(
                      infinite: true,
                      duration: const Duration(seconds: 1, milliseconds: 500),
                      child: Transform.flip(
                        flipX: true,
                        child: Lottie.asset(
                          width: 200,
                          'assets/tailcostickers/tgs/TailCoStickers_file_144834340.tgs',
                          decoder: LottieComposition.decodeGZip,
                        ),
                      ),
                    ),
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
