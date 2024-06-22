import 'dart:async';

import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:upgrader/upgrader.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../Backend/Bluetooth/bluetooth_message.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/logging_wrappers.dart';
import '../../Backend/plausible_dio.dart';
import '../../constants.dart';
import '../../main.dart';
import '../Widgets/back_button_to_close.dart';
import '../Widgets/base_card.dart';
import '../Widgets/known_gear.dart';
import '../Widgets/known_gear_scan_controller.dart';
import '../Widgets/logging_shake.dart';
import '../Widgets/snack_bar_overlay.dart';
import '../go_router_config.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';

part 'shell.freezed.dart';

@freezed
class NavDestination with _$NavDestination {
  const factory NavDestination({
    required String label,
    required Widget icon,
    required Widget selectedIcon,
    required String path,
  }) = _NavDestination;
}

List<NavDestination> destinations = <NavDestination>[
  NavDestination(label: homePage(), icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), path: '/'),
  NavDestination(label: triggersPage(), icon: const Icon(Icons.sensors_outlined), selectedIcon: const Icon(Icons.sensors), path: '/triggers'),
  //NavDestination(sequencesPage(), const Icon(Icons.list_outlined), const Icon(Icons.list), "/moveLists"),
  //NavDestination(joyStickPage(), const Icon(Icons.gamepad_outlined), const Icon(Icons.gamepad), "/joystick"),
  NavDestination(label: moreTitle(), icon: const Icon(Icons.menu), selectedIcon: const Icon(Icons.menu_open), path: "/more"),
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
    unawaited(setupSystemColor(context));
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
                        () async {
                          HiveProxy
                            ..put(settings, hasDisplayedReview, true)
                            ..put(settings, shouldDisplayReview, false);
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
  const ManageGear({required this.btMac, super.key});

  final String btMac;

  @override
  ConsumerState<ManageGear> createState() => _ManageGearState();
}

class _ManageGearState extends ConsumerState<ManageGear> {
  Color? color;
  BaseStatefulDevice? device;

  @override
  void initState() {
    super.initState();
    device = ref.read(knownDevicesProvider)[widget.btMac];
    color = Color(device!.baseStoredDevice.color);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(
        Theme.of(context).brightness,
        color!,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            shrinkWrap: true,
            controller: scrollController,
            children: [
              if (device!.baseDeviceDefinition.unsupported) ...[
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
                ),
              ],
              if (device!.mandatoryOtaRequired.value) ...[
                BaseCard(
                  elevation: 3,
                  color: Colors.red,
                  child: InkWell(
                    onTap: () async {
                      OtaUpdateRoute(device: device!.baseStoredDevice.btMACAddress).push(context);
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
                ),
              ],
              if (device!.hasUpdate.value || HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FilledButton(
                    onPressed: () async {
                      OtaUpdateRoute(device: device!.baseStoredDevice.btMACAddress).push(context);
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: getTextColor(color!),
                      elevation: 1,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.system_update,
                          color: getTextColor(color!),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                        ),
                        Text(
                          manageDevicesOtaButton(),
                          style: Theme.of(context).textTheme.labelLarge!.copyWith(
                                color: getTextColor(color!),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: TextEditingController(text: device!.baseStoredDevice.name),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: sequencesEditName(),
                    hintText: device!.baseDeviceDefinition.btName,
                  ),
                  maxLines: 1,
                  maxLength: 30,
                  autocorrect: false,
                  onSubmitted: (nameValue) async {
                    setState(
                      () {
                        if (nameValue.isNotEmpty) {
                          device!.baseStoredDevice.name = nameValue;
                        } else {
                          device!.baseStoredDevice.name = device!.baseDeviceDefinition.btName;
                        }
                      },
                    );
                    ref.read(knownDevicesProvider.notifier).store();
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
                  color: Color(device!.baseStoredDevice.color),
                ),
                onTap: () async {
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
                              device!.baseStoredDevice.color = color!.value;
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
                          ),
                        ],
                        content: Wrap(
                          children: [
                            ColorPicker(
                              color: color!,
                              padding: EdgeInsets.zero,
                              onColorChanged: (Color color) => setState(() => this.color = color),
                              pickersEnabled: const <ColorPickerType, bool>{
                                ColorPickerType.both: false,
                                ColorPickerType.primary: true,
                                ColorPickerType.accent: true,
                                ColorPickerType.wheel: true,
                              },
                            ),
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
                  valueListenable: device!.batteryLevel,
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
                                    ),
                                  ),
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
                                maxX: device!.stopWatch.elapsed.inSeconds.toDouble(),
                                lineBarsData: [LineChartBarData(spots: device!.batlevels, color: Theme.of(context).colorScheme.primary, dotData: const FlDotData(show: false), isCurved: true, show: device!.batlevels.isNotEmpty)],
                              ),
                            ),
                          ),
                        ),
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
                        onPressed: () async {
                          BluetoothConsoleRoute($extra: device!).push(context);
                        },
                        child: const Text("Open console"),
                      ),
                      Text("BT MAC: ${device!.baseStoredDevice.btMACAddress}"),
                      Text("HW VER: ${device!.hwVersion.value}"),
                      Text("FW VER: ${device!.fwVersion.value}"),
                      Text("FW AVAIL: ${device!.fwInfo.value}"),
                      Text("CON ELAPSED: ${device!.stopWatch.elapsed}"),
                      Text("DEV UUID: ${device!.baseDeviceDefinition.uuid}"),
                      Text("DEV TYPE: ${device!.baseDeviceDefinition.deviceType}"),
                      Text("DEV FW URL: ${device!.baseDeviceDefinition.fwURL}"),
                      Text("MTU: ${device!.mtu.value}"),
                      Text("RSSI: ${device!.rssi.value}"),
                      Text("BATT: ${device!.batteryLevel.value}"),
                      Text("UNSUPPORTED: ${device!.baseDeviceDefinition.unsupported}"),
                      Text("MIN FIRMWARE: ${device!.baseDeviceDefinition.minVersion}"),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text("Has Update"),
                  trailing: Switch(
                    value: device!.hasUpdate.value,
                    onChanged: (bool value) {
                      setState(() {
                        device!.hasUpdate.value = value;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text("Mandatory OTA Required"),
                  trailing: Switch(
                    value: device!.mandatoryOtaRequired.value,
                    onChanged: (bool value) {
                      setState(() {
                        device!.mandatoryOtaRequired.value = value;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text("Has Glowtip"),
                  trailing: DropdownMenu<GlowtipStatus>(
                    initialSelection: device!.hasGlowtip.value,
                    onSelected: (GlowtipStatus? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        device!.hasGlowtip.value = value;
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
                    value: device!.disableAutoConnect,
                    onChanged: (bool value) {
                      setState(() {
                        device!.disableAutoConnect = value;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text("Forget on Disconnect"),
                  trailing: Switch(
                    value: device!.forgetOnDisconnect,
                    onChanged: (bool value) {
                      setState(() {
                        device!.forgetOnDisconnect = value;
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
                      if (value == device!.batteryLevel.value) {
                        return;
                      }
                      setState(() {
                        device!.batteryLevel.value = value;
                      });
                    },
                    value: device!.batteryLevel.value,
                  ),
                ),
                ListTile(
                  title: const Text("Battery Charging"),
                  trailing: Switch(
                    value: device!.batteryCharging.value,
                    onChanged: (bool value) {
                      setState(() {
                        device!.batteryCharging.value = value;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text("Battery Low"),
                  trailing: Switch(
                    value: device!.batteryLow.value,
                    onChanged: (bool value) {
                      setState(() {
                        device!.batteryLow.value = value;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text("Error"),
                  trailing: Switch(
                    value: device!.gearReturnedError.value,
                    onChanged: (bool value) {
                      setState(() {
                        device!.gearReturnedError.value = value;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text("Connection State"),
                  trailing: DropdownMenu<ConnectivityState>(
                    initialSelection: device!.deviceConnectionState.value,
                    onSelected: (value) {
                      if (value != null) {
                        setState(
                          () {
                            device!.deviceConnectionState.value = value;
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
                    initialSelection: device!.deviceState.value,
                    onSelected: (value) {
                      if (value != null) {
                        setState(
                          () {
                            device!.deviceState.value = value;
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
                    value: device!.rssi.value.toDouble(),
                    onChanged: (double value) {
                      setState(
                        () {
                          device!.rssi.value = value.toInt();
                        },
                      );
                    },
                  ),
                ),
              ],
              ButtonBar(
                alignment: MainAxisAlignment.end,
                children: [
                  if (device!.deviceConnectionState.value == ConnectivityState.connected) ...[
                    TextButton(
                      onPressed: () async {
                        setState(() {
                          device!.disableAutoConnect = true;
                          disconnect(device!.baseStoredDevice.btMACAddress);
                        });
                        Navigator.pop(context);
                      },
                      child: Text(manageDevicesDisconnect()),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          device!.commandQueue.addCommand(BluetoothMessage(message: "SHUTDOWN", device: device!, priority: Priority.high, type: CommandType.system, timestamp: DateTime.now()));
                        });
                        Navigator.pop(context);
                      },
                      child: Text(manageDevicesShutdown()),
                    ),
                  ],
                  if (device!.deviceConnectionState.value == ConnectivityState.disconnected && device!.disableAutoConnect) ...[
                    TextButton(
                      onPressed: () {
                        setState(() {
                          device!.disableAutoConnect = false;
                        });
                        Navigator.pop(context);
                      },
                      child: Text(manageDevicesConnect()),
                    ),
                  ],
                  TextButton(
                    onPressed: () async {
                      setState(() {
                        if (device!.deviceConnectionState.value == ConnectivityState.connected) {
                          disconnect(device!.baseStoredDevice.btMACAddress);
                          device!.forgetOnDisconnect = true;
                          device!.disableAutoConnect = true;
                        } else {
                          ref.read(knownDevicesProvider.notifier).remove(device!.baseStoredDevice.btMACAddress);
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: Text(manageDevicesForget()),
                  ),
                ],
              ),
            ],
          );
        },
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
