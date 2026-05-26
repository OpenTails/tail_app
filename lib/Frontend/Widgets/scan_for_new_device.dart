import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../Backend/Bluetooth/known_devices.dart';
import '../../Backend/Device/bluetooth_uart_services_list.dart';
import '../../Backend/Device/device_definition.dart';
import '../../Backend/Device/device_registry.dart';
import '../../Backend/Device/device_type_enum.dart';
import '../../Backend/Device/stateful/connected_gear.dart';
import '../../Backend/Device/stored_device.dart';
import '../../Backend/analytics.dart';
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

  Future<void> createDemoGear(DeviceDefinition value) async {
    String btMac = "DEV${value.deviceType.translatedName}";
    if (KnownDevices.instance.state.containsKey(btMac)) {
      return;
    }
    StoredDevice storedDevice = StoredDevice(
      value.uuid,
      btMac,
      value.deviceType.color().toARGB32(),
    )..name = value.friendlyName;
    StatefulDevice statefulDevice = StatefulDevice(value, storedDevice);

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
  List<BluetoothDevice> foundSystemDevices = [];

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
                List<BluetoothDevice> foundDevices = [];
                if (snapshot.hasData) {
                  foundDevices = snapshot.data!
                      .where(
                        (scanResult) => !knownDeviceIds.contains(
                          scanResult.device.remoteId.str,
                        ),
                      )
                      .map((scanResult) => scanResult.device)
                      .toList();
                  foundDevices.addAll(foundSystemDevices);
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: foundDevices.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                        BluetoothDevice e = foundDevices[index];
                                        return ListTile(
                                          title: Text(
                                            convertToUwU(
                                              DeviceRegistry.getByName(
                                                    e.platformName,
                                                  )?.friendlyName ??
                                                  "",
                                            ),
                                          ),
                                          trailing: Text(
                                            isDeveloperEnabled
                                                ? e.remoteId.str
                                                : "",
                                          ),
                                          onTap: () async {
                                            await e.connect();
                                            analyticsEvent(
                                              name: "Connect New Gear",
                                              props: {
                                                "Gear Type": e.platformName,
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
                                if (foundDevices.length > 1) ...[
                                  Center(
                                    child: FilledButton(
                                      onPressed: () async {
                                        for (BluetoothDevice bluetoothDevice
                                            in foundDevices) {
                                          bluetoothDevice.connect();
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

  Future<void> getSystemDevices() async {
    foundSystemDevices =
        await FlutterBluePlus.systemDevices(
          DeviceRegistry.fbpGearServices,
        ).then(
          (value) => value
              .where(
                (bluetoothDevice) => !KnownDevices.instance.state.containsKey(
                  bluetoothDevice.remoteId.str,
                ),
              )
              .where(
                (bluetoothDevice) =>
                    DeviceRegistry.getByName(bluetoothDevice.platformName) !=
                    null,
              )
              .toList(),
        );
    if (foundSystemDevices.isNotEmpty && mounted && context.mounted) {
      setState(() {});
    }
  }
}
