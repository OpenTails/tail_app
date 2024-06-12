import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_message.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Frontend/Widgets/back_button_to_close.dart';
import 'package:tail_app/Frontend/Widgets/known_gear_scan_controller.dart';
import 'package:tail_app/Frontend/Widgets/logging_shake.dart';
import 'package:tail_app/Frontend/Widgets/snack_bar_overlay.dart';
import 'package:upgrader/upgrader.dart';

import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../../main.dart';
import '../Widgets/base_card.dart';
import '../Widgets/known_gear.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';

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
  NavDestination(homePage(), const Icon(Icons.home_outlined), const Icon(Icons.home), "/"),
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

class _NavigationDrawerExampleState extends ConsumerState<NavigationDrawerExample> {
  int screenIndex = 0;
  bool showAppBar = true;
  final InAppReview inAppReview = InAppReview.instance;

  @override
  Widget build(BuildContext context) {
    setupSystemColor(context);
    return LoggingShake(
      child: BackButtonToClose(
        child: UpgradeAlert(
          child: ValueListenableBuilder(
            valueListenable: SentryHive.box(settings).listenable(keys: [shouldDisplayReview]),
            builder: (BuildContext context, Box<dynamic> value, Widget? child) {
              if (value.get(shouldDisplayReview, defaultValue: shouldDisplayReviewDefault) && !value.get(hasDisplayedReview, defaultValue: hasDisplayedReviewDefault)) {
                inAppReview.isAvailable().then(
                  (isAvailable) {
                    if (isAvailable && value.get(shouldDisplayReview, defaultValue: shouldDisplayReviewDefault) && !value.get(hasDisplayedReview, defaultValue: hasDisplayedReviewDefault) && mounted) {
                      inAppReview.requestReview();
                      Future(
                        // Don't refresh widget in same frame
                        () {
                          HiveProxy.put(settings, hasDisplayedReview, true);
                          HiveProxy.put(settings, shouldDisplayReview, false);
                        },
                      );
                    }
                  },
                );
              }

              return child!;
            },
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
                setState(
                  () {
                    screenIndex = index;
                    return GoRouter.of(context).go(destinations[index].path);
                  },
                );
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
                title: const DeviceStatusWidget(),
                centerTitle: true,
                leadingWidth: 0,
                titleSpacing: 0,
                toolbarHeight: 100 * MediaQuery.textScalerOf(context).scale(1),
              ),
            ),
          ),
        ),
      ),
    );
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
      data: buildTheme(
        Theme.of(context).brightness,
        color,
      ),
      child: ListView(
        shrinkWrap: true,
        controller: widget.controller,
        children: [
          if (widget.device.baseDeviceDefinition.unsupported) ...[
            BaseCard(
              elevation: 3,
              color: Colors.red,
              child: ListTile(
                leading: const Icon(
                  Icons.warning,
                  color: Colors.white,
                ),
                trailing: const Icon(
                  Icons.warning,
                  color: Colors.white,
                ),
                title: Text(
                  noLongerSupported(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          ],
          if (widget.device.mandatoryOtaRequired.value) ...[
            BaseCard(
              elevation: 3,
              color: Colors.red,
              child: InkWell(
                onTap: () {
                  context.push("/ota", extra: widget.device.baseStoredDevice.btMACAddress);
                },
                child: ListTile(
                  leading: const Icon(
                    Icons.warning,
                    color: Colors.white,
                  ),
                  trailing: const Icon(
                    Icons.warning,
                    color: Colors.white,
                  ),
                  title: Text(
                    mandatoryOtaRequired(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          ],
          if (widget.device.hasUpdate.value || HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FilledButton(
                  onPressed: () {
                    context.push("/ota", extra: widget.device.baseStoredDevice.btMACAddress);
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: getTextColor(color),
                    elevation: 1,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.system_update,
                        color: getTextColor(color),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                      ),
                      Text(
                        manageDevicesOtaButton(),
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(
                              color: getTextColor(color),
                            ),
                      ),
                    ],
                  )),
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
                      manageDevicesColor(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.device.baseStoredDevice.color = color.value;
                          ref.read(knownDevicesProvider.notifier).store();
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
          if (HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) ...[
            const ListTile(
              title: Divider(),
            ),
            ValueListenableBuilder(
              valueListenable: widget.device.batteryLevel,
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
                              rightTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                showTitles: false,
                              )),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: Text('Battery'),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: Text('Time'),
                                sideTitles: SideTitles(showTitles: true),
                              ),
                            ),
                            lineTouchData: const LineTouchData(enabled: false),
                            borderData: FlBorderData(show: false),
                            minY: 0,
                            maxY: 100,
                            minX: 0,
                            maxX: widget.device.stopWatch.elapsed.inSeconds.toDouble(),
                            lineBarsData: [LineChartBarData(spots: widget.device.batlevels, color: Theme.of(context).colorScheme.primary, dotData: const FlDotData(show: false), isCurved: true, show: widget.device.batlevels.isNotEmpty)],
                          ),
                        ),
                      ),
                    )
                  ],
                );
              },
            ),
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
                  Text("MTU: ${widget.device.mtu.value}"),
                  Text("RSSI: ${widget.device.rssi.value}"),
                  Text("BATT: ${widget.device.batteryLevel.value}"),
                  Text("UNSUPPORTED: ${widget.device.baseDeviceDefinition.unsupported}"),
                  Text("MIN FIRMWARE: ${widget.device.baseDeviceDefinition.minVersion}"),
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
              title: const Text("Mandatory OTA Required"),
              trailing: Switch(
                value: widget.device.mandatoryOtaRequired.value,
                onChanged: (bool value) {
                  setState(() {
                    widget.device.mandatoryOtaRequired.value = value;
                  });
                },
              ),
            ),
            ListTile(
              title: const Text("Has Glowtip"),
              trailing: DropdownMenu<GlowtipStatus>(
                initialSelection: widget.device.hasGlowtip.value,
                onSelected: (GlowtipStatus? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    widget.device.hasGlowtip.value = value;
                  });
                },
                dropdownMenuEntries: GlowtipStatus.values
                    .map(
                      (e) => DropdownMenuEntry(value: e, label: e.name),
                    )
                    .toList(),
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
                  if (value == widget.device.batteryLevel.value) {
                    return;
                  }
                  setState(() {
                    widget.device.batteryLevel.value = value;
                  });
                },
                value: widget.device.batteryLevel.value,
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
                value: widget.device.gearReturnedError.value,
                onChanged: (bool value) {
                  setState(() {
                    widget.device.gearReturnedError.value = value;
                  });
                },
              ),
            ),
            ListTile(
              title: const Text("Connection State"),
              trailing: DropdownMenu<ConnectivityState>(
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
                dropdownMenuEntries: ConnectivityState.values
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
                min: -150,
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
              if (widget.device.deviceConnectionState.value == ConnectivityState.connected) ...[
                TextButton(
                  onPressed: () {
                    setState(() {
                      widget.device.disableAutoConnect = true;
                      disconnect(widget.device.baseStoredDevice.btMACAddress);
                    });
                    Navigator.pop(context);
                  },
                  child: Text(manageDevicesDisconnect()),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      widget.device.commandQueue.addCommand(BluetoothMessage(message: "SHUTDOWN", device: widget.device, priority: Priority.high, type: CommandType.system));
                    });
                    Navigator.pop(context);
                  },
                  child: Text(manageDevicesShutdown()),
                )
              ],
              if (widget.device.deviceConnectionState.value == ConnectivityState.disconnected && widget.device.disableAutoConnect) ...[
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
                    if (widget.device.deviceConnectionState.value == ConnectivityState.connected) {
                      disconnect(widget.device.baseStoredDevice.btMACAddress);
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
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    return KnownGearScanController(
      child: FadingEdgeScrollView.fromSingleChildScrollView(
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          scrollDirection: Axis.horizontal,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: KnownGear(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController?.dispose();
  }
}
