import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/device_registry.dart';
import '../../Backend/logging_wrappers.dart';
import '../../Backend/analytics.dart';
import '../../constants.dart';
import '../../gen/assets.gen.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';
import 'lottie_lazy_load.dart';
import 'tutorial_card.dart';

class ScanForNewDevice extends ConsumerStatefulWidget {
  const ScanForNewDevice({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ScanForNewDevice();
}

class _ScanForNewDevice extends ConsumerState<ScanForNewDevice> {
  @override
  void deactivate() {
    ref.read(scanProvider.notifier).stopScan();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      builder: (context, scrollController) {
        return ValueListenableBuilder(
          valueListenable: isBluetoothEnabled,
          builder: (BuildContext context, bool value, Widget? child) {
            if (value) {
              return ListView(
                shrinkWrap: true,
                controller: scrollController,
                children: [
                  ListTile(
                    title: Text(
                      convertToUwU(scanDevicesTitle()),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ScanGearList(),
                  if (HiveProxy.getOrDefault(settings, showDemoGear, defaultValue: showDemoGearDefault)) ...[
                    ExpansionTile(
                      title: Text(convertToUwU(scanDemoGear())),
                      children: [
                        PageInfoCard(
                          text: scanDemoGearTip(),
                        ),
                        ListTile(
                          leading: const Icon(Icons.add),
                          subtitle: DropdownMenu<BaseDeviceDefinition>(
                            initialSelection: null,
                            expandedInsets: EdgeInsets.zero,
                            label: Text(convertToUwU(scanAddDemoGear())),
                            onSelected: (value) async {
                              if (value != null) {
                                setState(
                                  () {
                                    BaseStoredDevice baseStoredDevice;
                                    BaseStatefulDevice statefulDevice;
                                    baseStoredDevice = BaseStoredDevice(value.uuid, "DEV${value.deviceType.translatedName}", value.deviceType.color(ref: ref).toARGB32())
                                      ..name = getNameFromBTName(value.btName);
                                    statefulDevice = BaseStatefulDevice(value, baseStoredDevice);
                                    statefulDevice.deviceConnectionState.value = ConnectivityState.connected;
                                    if (value.deviceType == DeviceType.ears) {
                                      statefulDevice.bluetoothUartService.value = uartServices.firstWhere(
                                        (element) => element.label == "Legacy Ears",
                                      );
                                    } else {
                                      statefulDevice.bluetoothUartService.value = uartServices.firstWhere(
                                        (element) => element.label == "TailCoNTROL",
                                      );
                                    }
                                    int code = Random().nextInt(899999) + 100000;
                                    baseStoredDevice.conModePin = code.toString();
                                    if (!ref.read(knownDevicesProvider).containsKey(baseStoredDevice.btMACAddress)) {
                                      ref.read(knownDevicesProvider.notifier).add(statefulDevice);
                                    }
                                    context.pop();
                                  },
                                );
                              }
                            },
                            dropdownMenuEntries: DeviceRegistry.allDevices.map((e) => DropdownMenuEntry(value: e, label: getNameFromBTName(e.btName))).toList(),
                          ),
                        ),
                        ListTile(
                          title: Text(convertToUwU(scanRemoveDemoGear())),
                          leading: const Icon(Icons.delete),
                          onTap: () async {
                            ref.read(knownDevicesProvider.notifier).removeDevGear();
                            if (ref
                                .read(knownDevicesProvider)
                                .values
                                .where(
                                  (element) => element.deviceConnectionState.value == ConnectivityState.connected,
                                )
                                .isEmpty) {}
                            context.pop();
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              );
            } else {
              return Center(
                child: Text(convertToUwU(actionsNoBluetooth())), //TODO: More detail
              );
            }
          },
        );
      },
      expand: false,
      initialChildSize: 0.5,
    );
  }
}

class ScanGearList extends ConsumerStatefulWidget {
  const ScanGearList({super.key, this.popOnConnect = true});
  final bool popOnConnect;
  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ScanGearListState();
}

class _ScanGearListState extends ConsumerState<ScanGearList> {
  bool anyKnownGear = false;

  @override
  void initState() {
    super.initState();
    anyKnownGear = ref.read(knownDevicesProvider).isNotEmpty;
    ref.read(scanProvider.notifier).beginScan(scanReason: ScanReason.addGear);
  }

  @override
  void deactivate() {
    ref.read(scanProvider.notifier).stopActiveScan();
    super.deactivate();
  }

  bool anyGearFound = false;

  @override
  Widget build(BuildContext context) {
    Iterable<String> knownDeviceIds = ref.watch(knownDevicesProvider).keys;
    return StreamBuilder<List<ScanResult>>(
      stream: FlutterBluePlus.scanResults,
      builder: (BuildContext context, AsyncSnapshot<List<ScanResult>> snapshot) {
        List<ScanResult> list = [];
        if (snapshot.hasData) {
          list = snapshot.data!.where((test) => !knownDeviceIds.contains(test.device.remoteId.str)).toList();
          anyGearFound = list.isNotEmpty;
        }
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
                            convertToUwU(scanDevicesFoundTitle()),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: list.length,
                          itemBuilder: (BuildContext context, int index) {
                            ScanResult e = list[index];
                            return ListTile(
                              title: Text(convertToUwU(getNameFromBTName(e.device.advName))),
                              trailing: Text(HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault) ? e.device.remoteId.str : ""),
                              onTap: () async {
                                await e.device.connect();
                                analyticsEvent(name: "Connect New Gear", props: {"Gear Type": e.device.advName, "Onboarding in Progress": widget.popOnConnect!.toString()});
                                if (context.mounted && widget.popOnConnect) {
                                  Navigator.pop(context);
                                }
                              },
                            );
                          },
                        ),
                        if (list.length > 1) ...[
                          Center(
                            child: FilledButton(
                              onPressed: () async {
                                for (ScanResult scanResult in list) {
                                  scanResult.device.connect();
                                }
                                if (widget.popOnConnect) {
                                  Navigator.pop(context);
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.select_all,
                                    color: getTextColor(Theme.of(context).colorScheme.primary),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                  ),
                                  Text(
                                    convertToUwU(scanConnectToAllButtonLabel()),
                                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                                          color: getTextColor(Theme.of(context).colorScheme.primary),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                      LottieLazyLoad(
                        asset: Assets.tailcostickers.tailCoStickersFile144834340,
                        width: 200,
                        renderCache: false,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          //Show a different message during onboarding
                          convertToUwU(widget.popOnConnect ? scanDevicesScanMessage() : scanDevicesOnboardingScanMessage()),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
