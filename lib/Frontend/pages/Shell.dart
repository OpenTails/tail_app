import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';
import 'package:tail_app/Backend/Bluetooth/btMessage.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';
import 'package:tail_app/Frontend/Widgets/scan_for_new_device.dart';
import 'package:tail_app/Frontend/Widgets/snack_bar_overlay.dart';
import 'package:upgrader/upgrader.dart';

import '../../Backend/AutoMove.dart';
import '../../constants.dart';
import '../../main.dart';
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
  //NavDestination(sequencesPage(), const Icon(Icons.list_outlined), const Icon(Icons.list), "/moveLists"),
  //NavDestination(joyStickPage(), const Icon(Icons.gamepad_outlined), const Icon(Icons.gamepad), "/joystick"),
  NavDestination(moreTitle(), const Icon(Icons.menu), const Icon(Icons.menu_open), "/more"),
];

class NavigationDrawerExample extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const NavigationDrawerExample(this.child, this.location, {super.key});

  @override
  ConsumerState<NavigationDrawerExample> createState() => _NavigationDrawerExampleState();
}

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
  if (SentryHive.box(settings).get(showAccurateBattery, defaultValue: showAccurateBatteryDefault)) {
    return Text('${level.toInt()}%');
  }
  if (level < 0) {
    return const Icon(Icons.battery_unknown);
  }
  if (level < 12.5) {
    return Flash(infinite: true, child: const Icon(Icons.battery_0_bar));
  } else if (level < 25) {
    return Flash(
      infinite: true,
      child: const Icon(Icons.battery_1_bar),
    );
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

class _NavigationDrawerExampleState extends ConsumerState<NavigationDrawerExample> {
  int screenIndex = 0;
  bool showAppBar = true;
  final InAppReview inAppReview = InAppReview.instance;

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
        child: ValueListenableBuilder(
      valueListenable: SentryHive.box(settings).listenable(keys: [shouldDisplayReview]),
      builder: (BuildContext context, Box<dynamic> value, Widget? child) {
        if (value.get(shouldDisplayReview, defaultValue: shouldDisplayReviewDefault) && !value.get(hasDisplayedReview, defaultValue: hasDisplayedReviewDefault)) {
          inAppReview.isAvailable().then(
            (isAvailable) {
              if (isAvailable && value.get(shouldDisplayReview, defaultValue: shouldDisplayReviewDefault) && !value.get(hasDisplayedReview, defaultValue: hasDisplayedReviewDefault)) {
                inAppReview.requestReview();
                Future(
                  // Don't refresh widget in same frame
                  () {
                    SentryHive.box(settings).put(hasDisplayedReview, true);
                    SentryHive.box(settings).put(shouldDisplayReview, false);
                  },
                );
              }
            },
          );
        }

        return child!;
      },
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 90 * MediaQuery.textScalerOf(context).scale(1), end: showAppBar ? 90 * MediaQuery.textScalerOf(context).scale(1) : 0),
        duration: animationTransitionDuration,
        builder: (BuildContext context, double size, Widget? child) {
          return AdaptiveScaffold(
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
            body: (_) => SafeArea(
              bottom: false,
              top: false,
              child: SnackBarOverlay(
                child: widget.child,
              ),
            ),
            // smallBody: (_) => SafeArea(
            //   bottom: false,
            //   top: false,
            //   child: SnackBarOverlay(
            //     child: widget.child,
            //   ),
            // ),
            // Define a default secondaryBody.
            //secondaryBody: AdaptiveScaffold.emptyBuilder,
            // Override the default secondaryBody during the smallBreakpoint to be
            // empty. Must use AdaptiveScaffold.emptyBuilder to ensure it is properly
            // overridden.
            smallSecondaryBody: AdaptiveScaffold.emptyBuilder,
            appBar: AppBar(
              actions: [
                IconButton(
                  onPressed: () => setState(() => showAppBar = !showAppBar),
                  icon: const Icon(Icons.device_hub),
                  selectedIcon: const Icon(Icons.device_hub_outlined),
                  tooltip: shellDeviceBarToggleLabel(),
                )
              ],
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(size),
                child: Center(
                  child: AnimatedCrossFade(
                    firstChild: const DeviceStatusWidget(),
                    secondChild: Container(),
                    duration: animationTransitionDuration,
                    crossFadeState: showAppBar ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  ),
                ),
              ),
              title: GestureDetector(
                onTap: () => setState(() => showAppBar = !showAppBar),
                child: Text(title()),
              ),
              leading: const Image(image: AssetImage('assets/copilot_fox_icon.png')),
            ),
          );
        },
      ),
    ));
  }
}

class ManageGear extends ConsumerStatefulWidget {
  const ManageGear({super.key, required this.ref, required this.device, required this.controller});

  final ScrollController controller;
  final WidgetRef ref;
  final BaseStatefulDevice device;

  @override
  ConsumerState<ManageGear> createState() => _ManageGearState();
}

class _ManageGearState extends ConsumerState<ManageGear> {
  late Color color;

  @override
  void initState() {
    super.initState();
    color = Color(widget.device.baseStoredDevice.color);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BuildTheme(
        Theme.of(context).brightness,
        color,
      ),
      child: ListView(
        shrinkWrap: true,
        controller: widget.controller,
        children: [
          ValueListenableBuilder(
            valueListenable: widget.device.battery,
            builder: (BuildContext context, double value, Widget? child) {
              return ExpansionTile(
                title: Text(manageDevicesBatteryGraphTitle()),
                children: [
                  SizedBox(
                    height: 200,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8, left: 8),
                      child: LineChart(
                        LineChartData(
                          titlesData: const FlTitlesData(
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          lineTouchData: const LineTouchData(enabled: false),
                          borderData: FlBorderData(show: false),
                          minY: 0,
                          maxY: 100,
                          minX: 0,
                          maxX: widget.device.stopWatch.elapsed.inSeconds.toDouble(),
                          lineBarsData: [LineChartBarData(spots: widget.device.batlevels, color: Theme.of(context).primaryColor, dotData: const FlDotData(show: false), isCurved: true, show: widget.device.batlevels.isNotEmpty)],
                        ),
                      ),
                    ),
                  )
                ],
              );
            },
          ),
          if (widget.device.hasUpdate.value || kDebugMode) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FilledButton(
                  onPressed: () {
                    context.push("/ota", extra: widget.device.baseStoredDevice.btMACAddress);
                  },
                  child: Text(manageDevicesOtaButton())),
            )
          ],
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: TextEditingController(text: widget.device.baseStoredDevice.name),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: sequencesEditName(),
                hintText: widget.device.baseDeviceDefinition.btName,
              ),
              maxLines: 1,
              maxLength: 30,
              autocorrect: false,
              onSubmitted: (nameValue) {
                setState(
                  () {
                    if (nameValue.isNotEmpty) {
                      widget.device.baseStoredDevice.name = nameValue;
                    } else {
                      widget.device.baseStoredDevice.name = widget.device.baseDeviceDefinition.btName;
                    }
                  },
                );
                widget.ref.read(knownDevicesProvider.notifier).store();
              },
            ),
          ),
          ListTile(
            title: Text(
              manageDevicesColor(),
            ),
            trailing: ColorIndicator(
              width: 44,
              height: 44,
              borderRadius: 22,
              color: Color(widget.device.baseStoredDevice.color),
            ),
            onTap: () {
              plausible.event(page: "Manage Gear/Gear Color");
              showDialog<bool>(
                context: context,
                useRootNavigator: false,
                useSafeArea: true,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                      settingsAppColor(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.device.baseStoredDevice.color = color.value;
                          ref.watch(knownDevicesProvider.notifier).store();
                        },
                        child: Text(
                          ok(),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          cancel(),
                        ),
                      )
                    ],
                    content: Wrap(
                      children: [
                        ColorPicker(
                          color: color,
                          padding: EdgeInsets.zero,
                          onColorChanged: (Color color) => setState(() => this.color = color),
                          pickersEnabled: const <ColorPickerType, bool>{
                            ColorPickerType.both: false,
                            ColorPickerType.primary: true,
                            ColorPickerType.accent: true,
                            ColorPickerType.wheel: true,
                          },
                        )
                      ],
                    ),
                  );
                },
              ).whenComplete(() => setState(() {}));
            },
          ),
          const ListTile(
            title: Divider(),
            dense: true,
          ),
          ListTile(
            title: Text(manageDevicesAutoMoveTitle()),
            subtitle: Text(manageDevicesAutoMoveSubTitle()),
            trailing: Switch(
              value: widget.device.baseStoredDevice.autoMove,
              onChanged: (bool value) {
                setState(() {
                  widget.device.baseStoredDevice.autoMove = value;
                });
                widget.ref.read(knownDevicesProvider.notifier).store();
                ChangeAutoMove(widget.device);
              },
            ),
          ),
          ListTile(
            title: Text(manageDevicesAutoMoveGroupsTitle()),
            subtitle: SegmentedButton<AutoActionCategory>(
              multiSelectionEnabled: true,
              selected: widget.device.baseStoredDevice.selectedAutoCategories.toSet(),
              onSelectionChanged: (Set<AutoActionCategory> value) {
                setState(() {
                  widget.device.baseStoredDevice.selectedAutoCategories = value.toList();
                });
                widget.ref.read(knownDevicesProvider.notifier).store();
                ChangeAutoMove(widget.device);
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
              labels: RangeLabels("${widget.device.baseStoredDevice.autoMoveMinPause.round()}", "${widget.device.baseStoredDevice.autoMoveMaxPause.round()}"),
              min: 15,
              max: 240,
              divisions: 225,
              values: RangeValues(widget.device.baseStoredDevice.autoMoveMinPause, widget.device.baseStoredDevice.autoMoveMaxPause),
              onChanged: (RangeValues value) {
                setState(() {
                  widget.device.baseStoredDevice.autoMoveMinPause = value.start;
                  widget.device.baseStoredDevice.autoMoveMaxPause = value.end;
                });
                widget.ref.read(knownDevicesProvider.notifier).store();
              },
              onChangeEnd: (values) {
                ChangeAutoMove(widget.device);
              },
            ),
          ),
          if (kDebugMode) ...[
            ListTile(
              title: const Text("Debug"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton(
                    onPressed: () {
                      context.push("/settings/developer/console", extra: widget.device);
                    },
                    child: const Text("Open console"),
                  ),
                  Text("BT MAC: ${widget.device.baseStoredDevice.btMACAddress}"),
                  Text("HW VER: ${widget.device.hwVersion.value}"),
                  Text("FW VER: ${widget.device.fwVersion.value}"),
                  Text("FW AVAIL: ${widget.device.fwInfo.value}"),
                  Text("CON ELAPSED: ${widget.device.stopWatch.elapsed}"),
                  Text("DEV UUID: ${widget.device.baseDeviceDefinition.uuid}"),
                  Text("DEV TYPE: ${widget.device.baseDeviceDefinition.deviceType}"),
                  Text("DEV FW URL: ${widget.device.baseDeviceDefinition.fwURL}"),
                ],
              ),
            ),
            ListTile(
              title: const Text("Has Update"),
              trailing: Switch(
                value: widget.device.hasUpdate.value,
                onChanged: (bool value) {
                  setState(() {
                    widget.device.hasUpdate.value = value;
                  });
                },
              ),
            ),
            ListTile(
              title: const Text("Has Glowtip"),
              trailing: Switch(
                value: widget.device.glowTip.value,
                onChanged: (bool value) {
                  setState(() {
                    widget.device.glowTip.value = value;
                  });
                },
              ),
            ),
            ListTile(
              title: const Text("Disable Autoconnect"),
              trailing: Switch(
                value: widget.device.disableAutoConnect,
                onChanged: (bool value) {
                  setState(() {
                    widget.device.disableAutoConnect = value;
                  });
                },
              ),
            ),
            ListTile(
              title: const Text("Forget on Disconnect"),
              trailing: Switch(
                value: widget.device.forgetOnDisconnect,
                onChanged: (bool value) {
                  setState(() {
                    widget.device.forgetOnDisconnect = value;
                  });
                },
              ),
            ),
            ListTile(
              title: const Text("Battery Level"),
              subtitle: Slider(
                min: -1,
                max: 100,
                onChanged: (double value) {
                  if (value == widget.device.battery.value) {
                    return;
                  }
                  setState(() {
                    widget.device.battery.value = value;
                  });
                },
                value: widget.device.battery.value,
              ),
            ),
            ListTile(
              title: const Text("Battery Charging"),
              trailing: Switch(
                value: widget.device.batteryCharging.value,
                onChanged: (bool value) {
                  setState(() {
                    widget.device.batteryCharging.value = value;
                  });
                },
              ),
            ),
            ListTile(
              title: const Text("Battery Low"),
              trailing: Switch(
                value: widget.device.batteryLow.value,
                onChanged: (bool value) {
                  setState(() {
                    widget.device.batteryLow.value = value;
                  });
                },
              ),
            ),
            ListTile(
              title: const Text("Error"),
              trailing: Switch(
                value: widget.device.error.value,
                onChanged: (bool value) {
                  setState(() {
                    widget.device.error.value = value;
                  });
                },
              ),
            ),
            ListTile(
              title: const Text("Connection State"),
              trailing: DropdownMenu<DeviceConnectionState>(
                initialSelection: widget.device.deviceConnectionState.value,
                onSelected: (value) {
                  if (value != null) {
                    setState(
                      () {
                        widget.device.deviceConnectionState.value = value;
                      },
                    );
                  }
                },
                dropdownMenuEntries: DeviceConnectionState.values
                    .map(
                      (e) => DropdownMenuEntry(value: e, label: e.name),
                    )
                    .toList(),
              ),
            ),
            ListTile(
              title: const Text("Device State"),
              trailing: DropdownMenu<DeviceState>(
                initialSelection: widget.device.deviceState.value,
                onSelected: (value) {
                  if (value != null) {
                    setState(
                      () {
                        widget.device.deviceState.value = value;
                      },
                    );
                  }
                },
                dropdownMenuEntries: DeviceState.values
                    .map(
                      (e) => DropdownMenuEntry(value: e, label: e.name),
                    )
                    .toList(),
              ),
            ),
            ListTile(
              title: const Text("RSSI Level"),
              subtitle: Slider(
                min: -80,
                max: -1,
                value: widget.device.rssi.value.toDouble(),
                onChanged: (double value) {
                  setState(
                    () {
                      widget.device.rssi.value = value.toInt();
                    },
                  );
                },
              ),
            ),
          ],
          ButtonBar(
            alignment: MainAxisAlignment.end,
            children: [
              if (widget.device.deviceConnectionState.value == DeviceConnectionState.connected) ...[
                TextButton(
                  onPressed: () {
                    setState(() {
                      widget.device.disableAutoConnect = true;
                      widget.device.connectionStateStreamSubscription?.cancel();
                    });
                    Navigator.pop(context);
                  },
                  child: Text(manageDevicesDisconnect()),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      widget.device.commandQueue.addCommand(BluetoothMessage(message: "SHUTDOWN", device: widget.device, priority: Priority.high, type: Type.system));
                    });
                    Navigator.pop(context);
                  },
                  child: Text(manageDevicesShutdown()),
                )
              ],
              if (widget.device.deviceConnectionState.value == DeviceConnectionState.disconnected && widget.device.disableAutoConnect) ...[
                TextButton(
                  onPressed: () {
                    setState(() {
                      widget.device.disableAutoConnect = false;
                    });
                    Navigator.pop(context);
                  },
                  child: Text(manageDevicesConnect()),
                ),
              ],
              TextButton(
                onPressed: () {
                  setState(() {
                    if (widget.device.deviceConnectionState.value == DeviceConnectionState.connected) {
                      widget.device.connectionStateStreamSubscription?.cancel();
                      widget.device.forgetOnDisconnect = true;
                      widget.device.disableAutoConnect = true;
                    } else {
                      ref.read(knownDevicesProvider.notifier).remove(widget.device.baseStoredDevice.btMACAddress);
                    }
                  });
                  Navigator.pop(context);
                },
                child: Text(manageDevicesForget()),
              )
            ],
          )
        ],
      ),
    );
  }
}

class DeviceStatusWidget extends ConsumerStatefulWidget {
  const DeviceStatusWidget({super.key});

  @override
  ConsumerState<DeviceStatusWidget> createState() => _DeviceStatusWidgetState();
}

class _DeviceStatusWidgetState extends ConsumerState<DeviceStatusWidget> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ref
              .watch(knownDevicesProvider)
              .values
              .map(
                (BaseStatefulDevice e) => (BaseStatefulDevice e, BuildContext context) {
                  // Auto connect to known devices
                  if (ref.watch(btStatusProvider).valueOrNull == BleStatus.ready) {
                    ref.watch(scanForDevicesProvider);
                  }
                  return FadeIn(
                    child: ValueListenableBuilder(
                      valueListenable: e.deviceConnectionState,
                      builder: (BuildContext context, DeviceConnectionState value, Widget? child) {
                        return Flash(
                          animate: value == DeviceConnectionState.connected,
                          child: ValueListenableBuilder(
                            valueListenable: e.hasUpdate,
                            builder: (BuildContext context, bool value, Widget? child) {
                              return Badge(
                                isLabelVisible: value,
                                largeSize: 35,
                                backgroundColor: Theme.of(context).primaryColor,
                                label: const Icon(Icons.system_update),
                                child: child,
                              );
                            },
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              color: e.deviceConnectionState.value == DeviceConnectionState.connected ? Color(e.baseStoredDevice.color) : Theme.of(context).cardColor,
                              child: InkWell(
                                onTap: () {
                                  plausible.event(page: "Manage Gear");
                                  showModalBottomSheet(
                                    context: context,
                                    showDragHandle: true,
                                    isScrollControlled: true,
                                    enableDrag: true,
                                    isDismissible: true,
                                    builder: (BuildContext context) {
                                      return DraggableScrollableSheet(
                                        expand: false,
                                        initialChildSize: 0.7,
                                        builder: (BuildContext context, ScrollController scrollController) {
                                          return ManageGear(
                                            ref: ref,
                                            device: e,
                                            controller: scrollController,
                                          );
                                        },
                                      );
                                    },
                                  ).then((value) {
                                    setState(() {}); //force widget update
                                    return;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: SizedBox(
                                    height: 50,
                                    width: 100,
                                    child: Stack(
                                      children: [
                                        Text(
                                          e.baseStoredDevice.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(top: 16),
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: AnimatedCrossFade(
                                              firstChild: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  ValueListenableBuilder(
                                                    valueListenable: e.battery,
                                                    builder: (BuildContext context, value, Widget? child) {
                                                      return AnimatedSwitcher(
                                                        duration: animationTransitionDuration,
                                                        child: getBattery(e.battery.value),
                                                      );
                                                    },
                                                  ),
                                                  ValueListenableBuilder(
                                                    valueListenable: e.batteryCharging,
                                                    builder: (BuildContext context, value, Widget? child) {
                                                      return AnimatedCrossFade(
                                                        firstChild: const Icon(Icons.power),
                                                        secondChild: Container(),
                                                        crossFadeState: e.deviceConnectionState.value == DeviceConnectionState.connected && e.batteryCharging.value ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                                        duration: animationTransitionDuration,
                                                      );
                                                    },
                                                  ),
                                                  ValueListenableBuilder(
                                                    valueListenable: e.rssi,
                                                    builder: (BuildContext context, value, Widget? child) {
                                                      return AnimatedSwitcher(
                                                        duration: animationTransitionDuration,
                                                        child: getSignal(e.rssi.value),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                              secondChild: const Icon(Icons.bluetooth_disabled),
                                              crossFadeState: value == DeviceConnectionState.connected ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                              duration: animationTransitionDuration,
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }(e, context),
              )
              .toList()
            ..add(
              FadeIn(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 50 * MediaQuery.textScalerOf(context).scale(1),
                        width: ref.watch(knownDevicesProvider).values.length > 1 ? 100 * MediaQuery.textScalerOf(context).scale(1) : 200 * MediaQuery.textScalerOf(context).scale(1),
                        child: Center(
                          child: Text(
                            scanDevicesTitle(),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    onTap: () {
                      plausible.event(page: "Scan For New Gear");
                      showModalBottomSheet(
                        context: context,
                        showDragHandle: true,
                        isScrollControlled: true,
                        enableDrag: true,
                        isDismissible: true,
                        builder: (BuildContext context) {
                          return DraggableScrollableSheet(
                            initialChildSize: 0.5,
                            expand: false,
                            builder: (BuildContext context, ScrollController scrollController) {
                              return Column(
                                children: [
                                  ListTile(
                                    title: Text(scanDevicesTitle()),
                                  ),
                                  Expanded(
                                      child: ScanForNewDevice(
                                    scrollController: scrollController,
                                  )),
                                ],
                              );
                            },
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
    );
  }
}
