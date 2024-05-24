import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';

import '../../Backend/device_registry.dart';
import '../../constants.dart';
import '../../gen/assets.gen.dart';
import '../../main.dart';
import '../intn_defs.dart';
import 'lottie_lazy_load.dart';

class ScanForNewDevice extends ConsumerStatefulWidget {
  const ScanForNewDevice({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ScanForNewDevice();
}

class _ScanForNewDevice extends ConsumerState<ScanForNewDevice> {
  bool anyKnownGear = false;

  @override
  void initState() {
    beginScan();
    super.initState();
    anyKnownGear = ref.read(knownDevicesProvider).isNotEmpty;
  }

  @override
  void dispose() {
    super.dispose();
    if (!SentryHive.box(settings).get(alwaysScanning, defaultValue: alwaysScanningDefault) || !anyKnownGear) {
      stopScan();
    }
  }

  bool anyGearFound = false;

  @override
  Widget build(BuildContext context) {
    Iterable<String> knownDeviceIds = ref.read(knownDevicesProvider).keys;
    return ValueListenableBuilder(
      valueListenable: isBluetoothEnabled,
      builder: (BuildContext context, bool value, Widget? child) {
        if (value) {
          return ListView(
            controller: widget.scrollController,
            children: [
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBluePlus.scanResults,
                builder: (BuildContext context, AsyncSnapshot<List<ScanResult>> snapshot) {
                  anyGearFound = snapshot.hasData && snapshot.data!.isNotEmpty && snapshot.data!.where((test) => !knownDeviceIds.contains(test.device.remoteId.str)).isNotEmpty;
                  return ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      AnimatedCrossFade(
                        firstChild: anyGearFound
                            ? ListView(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                children: [
                                  ListTile(
                                    title: Text(
                                      scanDevicesFoundTitle(),
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: snapshot.data!.where((test) => !knownDeviceIds.contains(test.device.remoteId.str)).length,
                                    itemBuilder: (BuildContext context, int index) {
                                      ScanResult e = snapshot.data!.where((test) => !knownDeviceIds.contains(test.device.remoteId.str)).toList()[index];
                                      return ListTile(
                                        title: Text(getNameFromBTName(e.device.advName)),
                                        trailing: Text(SentryHive.box(settings).get(showDebugging, defaultValue: showDebuggingDefault) ? e.device.remoteId.str : ""),
                                        onTap: () async {
                                          await e.device.connect();
                                          plausible.event(name: "Connect New Gear", props: {"Gear Type": e.device.advName});
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                      );
                                    },
                                  )
                                ],
                              )
                            : Container(),
                        secondChild: Container(),
                        crossFadeState: anyGearFound ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                        duration: animationTransitionDuration,
                      ),
                      AnimatedOpacity(
                        opacity: anyGearFound ? 0.5 : 1,
                        duration: animationTransitionDuration,
                        child: Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Center(
                              child: Column(
                                children: [
                                  Spin(
                                    infinite: true,
                                    duration: const Duration(seconds: 1, milliseconds: 500),
                                    child: Transform.flip(
                                      flipX: true,
                                      child: LottieLazyLoad(
                                        asset: Assets.tailcostickers.tailCoStickersFile144834340,
                                        width: 200,
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
                      ),
                    ],
                  );
                },
              ),
              if (SentryHive.box(settings).get(showDebugging, defaultValue: showDebuggingDefault)) ...[
                ListTile(
                  title: const Text("Add demo gear"),
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
                            statefulDevice = BaseStatefulDevice(value, baseStoredDevice);
                            statefulDevice.deviceConnectionState.value = ConnectivityState.connected;
                            isAnyGearConnected.value = true;
                            if (!ref.read(knownDevicesProvider).containsKey(baseStoredDevice.btMACAddress)) {
                              ref.read(knownDevicesProvider.notifier).add(statefulDevice);
                            }
                            context.pop();
                          },
                        );
                      }
                    },
                    dropdownMenuEntries: DeviceRegistry.allDevices.map((e) => DropdownMenuEntry(value: e, label: e.btName)).toList(),
                  ),
                ),
                ListTile(
                  title: const Text("Remove demo gear"),
                  leading: const Icon(Icons.delete),
                  onTap: () {
                    ref.read(knownDevicesProvider).removeWhere((key, value) => key.contains("DEV"));
                    ref.read(knownDevicesProvider.notifier).remove(""); // force update
                    if (ref
                        .read(knownDevicesProvider)
                        .values
                        .where(
                          (element) => element.deviceConnectionState.value == ConnectivityState.connected,
                        )
                        .isEmpty) {
                      isAnyGearConnected.value = false;
                    }
                  },
                ),
              ]
            ],
          );
        } else {
          return Center(
            child: Text(actionsNoBluetooth()), //TODO: More detail
          );
        }
      },
    );
  }
}
