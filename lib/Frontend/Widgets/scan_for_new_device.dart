import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../Backend/Bluetooth/known_devices.dart';
import '../../Backend/Device/bluetooth_uart_services_list.dart';
import '../../Backend/Device/common_device_stuffs.dart';
import '../../Backend/Device/device_definition.dart';
import '../../Backend/Device/device_type_enum.dart';
import '../../Backend/Device/stateful/connected_gear.dart';
import '../../Backend/Device/stored_device.dart';
import '../../Backend/analytics.dart';
import '../../Backend/Device/device_registry.dart';
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
                              .where((element) {
                                if (isDeveloperEnabled) {
                                  return true;
                                } else {
                                  return [
                                    "EG2",
                                    "MiTail",
                                  ].contains(element.btName);
                                }
                              })
                              .map(
                                (e) => DropdownMenuEntry(
                                  value: e,
                                  label: getNameFromBTName(e.btName),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      ListTile(
                        title: Text(convertToUwU(scanRemoveDemoGear())),
                        leading: const Icon(Icons.delete),
                        onTap: () async {
                          KnownDevices.instance.removeDevGear();
                          if (KnownDevices.instance.state.values
                              .where(
                                (element) =>
                                    element.deviceConnectionState.value ==
                                    ConnectivityState.connected,
                              )
                              .isEmpty) {}
                          context.pop();
                        },
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

  Future<void> createDemoGear(DeviceDefinition value) async {
    String btMac = "DEV${value.deviceType.translatedName}";
    if (KnownDevices.instance.state.containsKey(btMac)) {
      return;
    }
    StoredDevice storedDevice;
    StatefulDevice statefulDevice;
    storedDevice = StoredDevice(
      value.uuid,
      btMac,
      value.deviceType.color().toARGB32(),
    )..name = getNameFromBTName(value.btName);
    statefulDevice = StatefulDevice(value, storedDevice);

    // Has to be added before updating connection state
    await KnownDevices.instance.add(statefulDevice);

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

  @override
  void initState() {
    super.initState();
    anyKnownGear = KnownDevices.instance.state.isNotEmpty;
    Scan.instance.beginScan(scanReason: ScanReason.addGear);
  }

  @override
  void deactivate() {
    Scan.instance.stopActiveScan();
    super.deactivate();
  }

  bool anyGearFound = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: KnownDevices.instance,
      builder: (BuildContext context, Widget? child) {
        Iterable<String> knownDeviceIds = KnownDevices.instance.state.keys;
        return StreamBuilder<List<ScanResult>>(
          stream: FlutterBluePlus.scanResults,
          builder:
              (BuildContext context, AsyncSnapshot<List<ScanResult>> snapshot) {
                List<ScanResult> list = [];
                if (snapshot.hasData) {
                  list = snapshot.data!
                      .where(
                        (test) =>
                            !knownDeviceIds.contains(test.device.remoteId.str),
                      )
                      .toList();
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: list.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                        ScanResult e = list[index];
                                        return ListTile(
                                          title: Text(
                                            convertToUwU(
                                              getNameFromBTName(
                                                e.device.platformName,
                                              ),
                                            ),
                                          ),
                                          trailing: Text(
                                            isDeveloperEnabled
                                                ? e.device.remoteId.str
                                                : "",
                                          ),
                                          onTap: () async {
                                            await e.device.connect();
                                            analyticsEvent(
                                              name: "Connect New Gear",
                                              props: {
                                                "Gear Type":
                                                    e.device.platformName,
                                                "Onboarding in Progress":
                                                    (!widget.popOnConnect)
                                                        .toString(),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.select_all,
                                            color: getTextColor(
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
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
}
