import 'package:double_back_to_close_app/double_back_to_close_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';
import 'package:tail_app/Frontend/Widgets/scan_for_new_device.dart';
import 'package:tail_app/Frontend/Widgets/snack_bar_overlay.dart';
import 'package:upgrader/upgrader.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../Backend/AutoMove.dart';
import '../intnDefs.dart';

/// Flutter code sample for [NavigationDrawer].

@immutable
class NavDestination {
  const NavDestination(this.label, this.icon, this.selectedIcon, this.path);

  final String label;
  final Widget icon;
  final Widget selectedIcon;
  final String path;
}

List<NavDestination> destinations = <NavDestination>[
  NavDestination(actionsPage(), const Icon(Icons.widgets_outlined), const Icon(Icons.widgets), "/"),
  NavDestination(triggersPage(), const Icon(Icons.sensors_outlined), const Icon(Icons.sensors), "/triggers"),
  NavDestination(sequencesPage(), const Icon(Icons.list_outlined), const Icon(Icons.list), "/moveLists"),
  NavDestination(joyStickPage(), const Icon(Icons.gamepad_outlined), const Icon(Icons.gamepad), "/joystick"),
  NavDestination(settingsPage(), const Icon(Icons.settings_outlined), const Icon(Icons.settings), "/settings"),
];

class NavigationDrawerExample extends ConsumerStatefulWidget {
  Widget child;
  String location;

  NavigationDrawerExample(this.child, this.location, {super.key});

  @override
  ConsumerState<NavigationDrawerExample> createState() => _NavigationDrawerExampleState();
}

class _NavigationDrawerExampleState extends ConsumerState<NavigationDrawerExample> {
  int screenIndex = 0;
  var controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0x00000000))
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          // Update loading bar.
        },
        onPageStarted: (String url) {},
        onPageFinished: (String url) {},
      ),
    )
    ..loadRequest(Uri.parse('https://thetailcompany.com/'));

  Widget getSignal(int rssi) {
    if (rssi < -2) {
      return const Icon(Icons.signal_cellular_alt);
    } else if (rssi <= -45) {
      return const Icon(Icons.signal_cellular_alt_2_bar);
    } else if (rssi < -65) {
      return const Icon(Icons.signal_cellular_alt_1_bar);
    } else {
      return const Icon(Icons.signal_cellular_connected_no_internet_0_bar);
    }
  }

  Widget getBattery(double level) {
    if (level < 0) {
      return const Icon(Icons.battery_unknown);
    }
    if (level < 12.5) {
      return const Icon(Icons.battery_0_bar);
    } else if (level < 25) {
      return const Icon(Icons.battery_1_bar);
    } else if (level < 37.5) {
      return const Icon(Icons.battery_2_bar);
    } else if (level < 50) {
      return const Icon(Icons.battery_3_bar);
    } else if (level < 62.5) {
      return const Icon(Icons.battery_4_bar);
    } else if (level < 75) {
      return const Icon(Icons.battery_5_bar);
    } else if (level < 87.5) {
      return const Icon(Icons.battery_6_bar);
    } else {
      return const Icon(Icons.battery_full);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      child: AdaptiveScaffold(
        // An option to override the default breakpoints used for small, medium,
        // and large.
        smallBreakpoint: const WidthPlatformBreakpoint(end: 700),
        mediumBreakpoint: const WidthPlatformBreakpoint(begin: 700, end: 1000),
        largeBreakpoint: const WidthPlatformBreakpoint(begin: 1000),
        useDrawer: false,
        appBarBreakpoint: const WidthPlatformBreakpoint(begin: 0),
        selectedIndex: screenIndex,
        onSelectedIndexChange: (int index) {
          setState(() {
            screenIndex = index;
            return GoRouter.of(context).go(destinations[index].path);
          });
        },
        destinations: destinations.map(
          (NavDestination destination) {
            return NavigationDestination(
              label: destination.label,
              icon: destination.icon,
              selectedIcon: destination.selectedIcon,
              tooltip: destination.label,
            );
          },
        ).toList(),
        body: (_) => DoubleBackToCloseApp(
          snackBar: SnackBar(
            content: Text(doubleBack()),
          ),
          child: SafeArea(
            bottom: false,
            top: false,
            child: SnackBarOverlay(
              child: widget.child,
            ),
          ),
        ),
        smallBody: (_) => DoubleBackToCloseApp(
          snackBar: SnackBar(
            content: Text(doubleBack()),
          ),
          child: SafeArea(
            bottom: false,
            top: false,
            child: SnackBarOverlay(
              child: widget.child,
            ),
          ),
        ),
        // Define a default secondaryBody.
        secondaryBody: AdaptiveScaffold.emptyBuilder,
        // Override the default secondaryBody during the smallBreakpoint to be
        // empty. Must use AdaptiveScaffold.emptyBuilder to ensure it is properly
        // overridden.
        smallSecondaryBody: AdaptiveScaffold.emptyBuilder,
        appBar: AppBar(
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ref
                      .watch(knownDevicesProvider)
                      .values
                      .map(
                        (BaseStatefulDevice e) => buildDeviceCard(e, context),
                      )
                      .toList()
                    ..add(
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              height: 50,
                              width: ref.watch(knownDevicesProvider).values.length > 1 ? 200 : 100,
                              child: Center(
                                child: Text(
                                  "Scan For New Devices",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              useRootNavigator: false,
                              builder: (BuildContext context) {
                                return SimpleDialog(
                                  title: Text("Scan For New Devices"),
                                  children: [
                                    const ScanForNewDevice(),
                                    Center(
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: Text(ok()),
                                      ),
                                    )
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                ),
              ),
            ),
          ),
          title: Text(title()),
        ),
      ),
    );
  }

  Card buildDeviceCard(BaseStatefulDevice e, BuildContext context) {
    // Auto connect to known devices
    if (ref.watch(btStatusProvider).valueOrNull == BleStatus.ready) {
      ref.watch(scanForDevicesProvider);
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      color: e.deviceConnectionState.value == DeviceConnectionState.connected ? e.baseDeviceDefinition.deviceType.color : null,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              enableDrag: true,
              isDismissible: true,
              builder: (BuildContext context) {
                return StatefulBuilder(
                  builder: (BuildContext context, setState) {
                    return Wrap(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: TextField(
                            controller: TextEditingController(text: e.baseStoredDevice.name),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: sequencesEditName(),
                              hintText: e.baseDeviceDefinition.btName,
                            ),
                            maxLines: 1,
                            maxLength: 30,
                            autocorrect: false,
                            onSubmitted: (nameValue) {
                              setState(
                                () {
                                  if (nameValue.isNotEmpty) {
                                    e.baseStoredDevice.name = nameValue;
                                  } else {
                                    e.baseStoredDevice.name = e.baseDeviceDefinition.btName;
                                  }
                                },
                              );
                              ref.read(knownDevicesProvider.notifier).store();
                            },
                          ),
                        ),
                        ListTile(
                          title: Text(manageDevicesAutoMoveTitle()),
                          subtitle: Text(manageDevicesAutoMoveSubTitle()),
                          trailing: Switch(
                            value: e.baseStoredDevice.autoMove,
                            onChanged: (bool value) {
                              setState(() {
                                e.baseStoredDevice.autoMove = value;
                              });
                              ref.read(knownDevicesProvider.notifier).store();
                              ChangeAutoMove(e);
                            },
                          ),
                        ),
                        ListTile(
                          title: Text(manageDevicesAutoMoveGroupsTitle()),
                          subtitle: SegmentedButton<AutoActionCategory>(
                            multiSelectionEnabled: true,
                            selected: e.baseStoredDevice.selectedAutoCategories.toSet(),
                            onSelectionChanged: (Set<AutoActionCategory> value) {
                              setState(() {
                                e.baseStoredDevice.selectedAutoCategories = value.toList();
                              });
                              ref.read(knownDevicesProvider.notifier).store();
                              ChangeAutoMove(e);
                            },
                            segments: AutoActionCategory.values.map<ButtonSegment<AutoActionCategory>>(
                              (AutoActionCategory value) {
                                return ButtonSegment<AutoActionCategory>(
                                  value: value,
                                  label: Text(value.friendly),
                                );
                              },
                            ).toList(),
                          ),
                        ),
                        ListTile(
                            title: Text(manageDevicesAutoMovePauseTitle()),
                            subtitle: RangeSlider(
                              labels: RangeLabels(manageDevicesAutoMovePauseSliderLabel(e.baseStoredDevice.autoMoveMinPause.round()), manageDevicesAutoMovePauseSliderLabel(e.baseStoredDevice.autoMoveMaxPause.round())),
                              min: 15,
                              max: 240,
                              values: RangeValues(e.baseStoredDevice.autoMoveMinPause, e.baseStoredDevice.autoMoveMaxPause),
                              onChanged: (RangeValues value) {
                                setState(() {
                                  e.baseStoredDevice.autoMoveMinPause = value.start;
                                  e.baseStoredDevice.autoMoveMaxPause = value.end;
                                });
                                ref.read(knownDevicesProvider.notifier).store();
                              },
                              onChangeEnd: (values) {
                                ChangeAutoMove(e);
                              },
                            )),
                        ListTile(
                          title: Text(manageDevicesAutoMoveNoPhoneTitle()),
                          subtitle: Slider(
                            value: e.baseStoredDevice.noPhoneDelayTime,
                            min: 1,
                            max: 60,
                            onChanged: (double value) {
                              setState(() {
                                e.baseStoredDevice.noPhoneDelayTime = value;
                              });
                              ref.read(knownDevicesProvider.notifier).store();
                            },
                            label: manageDevicesAutoMoveNoPhoneSliderLabel(e.baseStoredDevice.noPhoneDelayTime.round()),
                          ),
                        ),
                        ButtonBar(
                          alignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  e.connectionStateStreamSubscription = null;
                                });
                              },
                              child: Text(manageDevicesDisconnect()),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  e.connectionStateStreamSubscription = null;
                                });
                                ref.watch(knownDevicesProvider.notifier).remove(e.baseStoredDevice.btMACAddress);
                              },
                              child: Text(manageDevicesForget()),
                            )
                          ],
                        )
                      ],
                    );
                  },
                );
              });
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            height: 50,
            width: 100,
            child: Stack(
              children: [
                Text(e.baseStoredDevice.name),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: MultiValueListenableBuilder(
                    builder: (BuildContext context, List<dynamic> values, Widget? child) {
                      if (e.deviceConnectionState.value == DeviceConnectionState.connected) {
                        return getBattery(e.battery.value);
                      } else {
                        return Text(e.deviceConnectionState.value.name);
                      }
                    },
                    valueListenables: [e.battery, e.deviceConnectionState],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: MultiValueListenableBuilder(
                    builder: (BuildContext context, List<dynamic> values, Widget? child) {
                      if (e.deviceConnectionState.value == DeviceConnectionState.connected) {
                        return getSignal(e.rssi.value);
                      }
                      return Container();
                    },
                    valueListenables: [e.rssi, e.deviceConnectionState],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
/*
)*/
