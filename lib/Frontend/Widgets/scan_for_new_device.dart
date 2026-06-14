import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Bluetooth/known_devices.dart';
import '../../Backend/Device/device_definition.dart';
import '../../Backend/Device/device_registry.dart';
import '../../Backend/analytics.dart';
import '../../Backend/utilities/demo_gear_helpers.dart';
import '../../Backend/utilities/settings.dart';
import '../../assets.dart';
import '../../constants.dart';
import '../theme_helpers.dart';
import '../translation_string_definitions.dart';
import 'lottie_lazy_load.dart';
import 'tutorial_card.dart';

class ScanForNewDevice extends StatefulWidget {
  const ScanForNewDevice({super.key});

  @override
  State<StatefulWidget> createState() => _ScanForNewDevice();
}

class _ScanForNewDevice extends State<ScanForNewDevice> {
  @override
  void deactivate() {
    Scan.instance.stopScan();
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
                  ExpansionTile(
                    title: Text(convertToUwU(scanDemoGear())),
                    children: [
                      PageInfoCard(text: scanDemoGearTip()),
                      ListTile(
                        leading: const Icon(Icons.add),
                        subtitle: DropdownMenu<DeviceDefinition>(
                          initialSelection: null,
                          expandedInsets: EdgeInsets.zero,
                          label: Text(convertToUwU(scanAddDemoGear())),
                          onSelected: (value) async {
                            if (value != null) {
                              setState(() {
                                createDemoGear(value);
                                context.pop();
                              });
                            }
                          },
                          dropdownMenuEntries: DeviceRegistry.allDevices
                              .where((deviceDefinition) {
                                if (isDeveloperEnabled) {
                                  return true;
                                } else {
                                  return deviceDefinition.enableDemo;
                                }
                              })
                              .map(
                                (e) => DropdownMenuEntry(
                                  value: e,
                                  label: e.friendlyName,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            } else {
              return Center(
                child: Text(
                  convertToUwU(actionsNoBluetooth()),
                ), //TODO: More detail
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

class ScanGearList extends StatefulWidget {
  const ScanGearList({super.key, this.popOnConnect = true});

  final bool popOnConnect;

  @override
  State<StatefulWidget> createState() => _ScanGearListState();
}

class _ScanGearListState extends State<ScanGearList> {
  bool anyKnownGear = false;
  List<BleDevice> foundSystemDevices = [];

  @override
  void initState() {
    super.initState();
    anyKnownGear = KnownDevices.instance.state.isNotEmpty;
    Scan.instance.beginScan(scanReason: ScanReason.addGear);
    getSystemDevices();
  }

  @override
  void deactivate() {
    Scan.instance.stopActiveScan();
    super.deactivate();
  }

  bool anyGearFound = false;
  List<BleDevice> foundDevices = [];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: KnownDevices.instance,
      builder: (BuildContext context, Widget? child) {
        Iterable<String> knownDeviceIds = KnownDevices.instance.state.keys;
        return StreamBuilder<BleDevice>(
          stream: UniversalBle.scanStream,
          builder: (BuildContext context, AsyncSnapshot<BleDevice> snapshot) {
            if (snapshot.hasData) {
              BleDevice foundDevice = snapshot.data!;
              if (!knownDeviceIds.contains(foundDevice.deviceId) &&
                  !foundDevices
                      .map((e) => e.deviceId)
                      .any((element) => element == foundDevice.deviceId)) {
                foundDevices.add(foundDevice);
              }
              anyGearFound = foundDevices.isNotEmpty;
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
                              itemCount: foundDevices.length,
                              itemBuilder: (BuildContext context, int index) {
                                BleDevice e = foundDevices[index];
                                return ListTile(
                                  title: Text(
                                    convertToUwU(
                                      DeviceRegistry.getByName(
                                            e.name ?? "",
                                          )?.friendlyName ??
                                          "",
                                    ),
                                  ),
                                  trailing: Text(
                                    isDeveloperEnabled ? e.deviceId : "",
                                  ),
                                  onTap: () async {
                                    await createAndConnect(
                                      e.deviceId,
                                      e.name ?? "",
                                    );
                                    analyticsEvent(
                                      name: "Connect New Gear",
                                      props: {
                                        "Gear Type": e.name ?? "",
                                        "Onboarding in Progress":
                                            (!widget.popOnConnect).toString(),
                                      },
                                    );
                                    if (context.mounted &&
                                        widget.popOnConnect) {
                                      Navigator.pop(context);
                                    }
                                  },
                                );
                              },
                            ),
                            if (foundDevices.length > 1) ...[
                              Center(
                                child: FilledButton(
                                  onPressed: () async {
                                    for (BleDevice bluetoothDevice
                                        in foundDevices) {
                                      await createAndConnect(
                                        bluetoothDevice.deviceId,
                                        bluetoothDevice.name ?? "",
                                      );
                                    }
                                    if (widget.popOnConnect &&
                                        mounted &&
                                        context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.select_all,
                                        color: getTextColor(
                                          Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                      ),
                                      Text(
                                        convertToUwU(
                                          scanConnectToAllButtonLabel(),
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge!
                                            .copyWith(
                                              color: getTextColor(
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
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
                  crossFadeState: anyGearFound
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
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
                            asset: Assets.tailcostickers.spinningCrumpet,
                            width: 200,
                            renderCache: false,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              //Show a different message during onboarding
                              convertToUwU(
                                widget.popOnConnect
                                    ? scanDevicesScanMessage()
                                    : scanDevicesOnboardingScanMessage(),
                              ),
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
      },
    );
  }

  Future<void> getSystemDevices() async {
    foundSystemDevices = await UniversalBle.getSystemDevices().then(
      (value) => value
          .where(
            (bluetoothDevice) => !KnownDevices.instance.state.containsKey(
              bluetoothDevice.deviceId,
            ),
          )
          .where(
            (bluetoothDevice) =>
                DeviceRegistry.getByName(bluetoothDevice.name ?? "") != null,
          )
          .toList(),
    );
    if (foundSystemDevices.isNotEmpty && mounted && context.mounted) {
      setState(() {
        foundDevices.addAll(foundSystemDevices);
      });
    }
  }
}
