import 'package:fl_chart/fl_chart.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/command_runner.dart';
import 'package:tail_app/Backend/firmware_update.dart';
import 'package:tail_app/Backend/move_lists.dart';
import 'package:tail_app/Backend/version.dart';
import 'package:tail_app/Frontend/Widgets/tutorial_card.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../Backend/Bluetooth/known_devices.dart';
import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../Backend/Bluetooth/bluetooth_message.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../../main.dart';
import '../go_router_config.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';
import 'base_card.dart';

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
    device = KnownDevices.instance.state[widget.btMac];
    color = Color(device!.baseStoredDevice.color);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(Theme.of(context).brightness, color!),
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
                    leading: const Icon(Icons.warning, color: Colors.white),
                    trailing: const Icon(Icons.warning, color: Colors.white),
                    title: Text(
                      convertToUwU(noLongerSupported()),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              ValueListenableBuilder(
                valueListenable: device!.hasUpdate,
                builder: (context, value, child) {
                  return Column(
                    children: [
                      if (device!.mandatoryOtaRequired.value) ...[
                        BaseCard(
                          elevation: 3,
                          color: Colors.red,
                          child: InkWell(
                            onTap: () async {
                              OtaUpdateRoute(device: device!.baseStoredDevice.btMACAddress).push(context);
                            },
                            child: ListTile(
                              leading: const Icon(Icons.warning, color: Colors.white),
                              trailing: const Icon(Icons.warning, color: Colors.white),
                              title: Text(
                                convertToUwU(mandatoryOtaRequired()),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (device!.hasUpdate.value) ...[
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: FilledButton(
                            onPressed: () async {
                              OtaUpdateRoute(device: device!.baseStoredDevice.btMACAddress).push(context);
                            },
                            style: ElevatedButton.styleFrom(foregroundColor: getTextColor(color!), elevation: 1),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.system_update, color: getTextColor(color!)),
                                const Padding(padding: EdgeInsets.symmetric(horizontal: 4)),
                                Text(convertToUwU(manageDevicesOtaButton()), style: Theme.of(context).textTheme.labelLarge!.copyWith(color: getTextColor(color!))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: TextEditingController(text: device!.baseStoredDevice.name),
                  decoration: InputDecoration(border: const OutlineInputBorder(), labelText: sequencesEditName(), hintText: device!.baseDeviceDefinition.btName),
                  maxLines: 1,
                  maxLength: 30,
                  autocorrect: false,
                  onSubmitted: (nameValue) async {
                    setState(() {
                      if (nameValue.isNotEmpty) {
                        device!.baseStoredDevice.name = nameValue;
                      } else {
                        device!.baseStoredDevice.name = device!.baseDeviceDefinition.btName;
                      }
                    });
                    KnownDevices.instance.store();
                  },
                ),
              ),
              ListTile(
                title: Text(convertToUwU(manageDevicesColor())),
                trailing: ColorIndicator(width: 44, height: 44, borderRadius: 22, color: Color(device!.baseStoredDevice.color)),
                onTap: () async {
                  ColorPickerRoute(defaultColor: color!.toARGB32())
                      .push(context)
                      .then(
                        (color) => setState(() {
                          if (color != null) {
                            device!.baseStoredDevice.color = color;
                            this.color = Color(color);
                            KnownDevices.instance.store();
                          }
                        }),
                      );
                },
              ),
              if (HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) ...[
                if (device!.baseDeviceDefinition.deviceType == DeviceType.ears) ...[ManageGearHomePosition(device: device!)],
                ManageGearBatteryGraph(device: device!),
                ManageGearConventionMode(device: device!),
                ManageGearDebug(device: device!),
              ],
              // We only know this info if the gear is connected
              if (device!.deviceConnectionState.value == ConnectivityState.connected) ...[ManageGearAbout(device: device!, color: color!)],
              OverflowBar(
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
                      child: Text(convertToUwU(manageDevicesDisconnect())),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          device!.commandQueue.addCommand(BluetoothMessage(message: "SHUTDOWN", priority: Priority.high, type: CommandType.system, timestamp: DateTime.now()));
                        });
                        Navigator.pop(context);
                      },
                      child: Text(convertToUwU(manageDevicesShutdown())),
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
                      child: Text(convertToUwU(manageDevicesConnect())),
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
                          KnownDevices.instance.remove(device!.baseStoredDevice.btMACAddress);
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: Text(convertToUwU(manageDevicesForget())),
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

class ManageGearUpdateCheckButton extends ConsumerStatefulWidget {
  final BaseStatefulDevice device;
  final Color color;

  const ManageGearUpdateCheckButton({super.key, required this.device, required this.color});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ManageGearUpdateCheckButtonState();
}

class _ManageGearUpdateCheckButtonState extends ConsumerState<ManageGearUpdateCheckButton> {
  Future<bool>? _otaAvailable;

  @override
  Widget build(BuildContext context) {
    return OverflowBar(
      alignment: MainAxisAlignment.center,
      children: [
        FutureBuilder(
          future: _otaAvailable,
          builder: (context, snapshot) {
            String buttonText = "";
            IconData iconData = Icons.device_unknown;
            if (snapshot.connectionState == ConnectionState.none) {
              buttonText = manageDevicesOtaCheckButtonLabel();
              iconData = Icons.question_mark;
            } else if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              if (snapshot.data == true) {
                buttonText = manageDevicesOtaButton();
                iconData = Icons.system_update;
              } else {
                buttonText = manageDevicesOtaUpToDateButtonLabel();
                iconData = Icons.check;
              }
            } else if (snapshot.hasError) {
              buttonText = manageDevicesOtaCheckErrorButtonLabel();
              iconData = Icons.error;
            } else if (snapshot.connectionState == ConnectionState.active || snapshot.connectionState == ConnectionState.waiting) {
              buttonText = manageDevicesOtaCheckInProgressButtonLabel();
            }
            return FilledButton(
              onPressed: (snapshot.connectionState == ConnectionState.active || snapshot.connectionState == ConnectionState.waiting)
                  ? null
                  : () {
                      if (snapshot.data == true) {
                        OtaUpdateRoute(device: widget.device.baseStoredDevice.btMACAddress).push(context);
                      } else {
                        setState(() {
                          //force redownloading the json
                          widget.device.fwInfo.value = null;
                          _otaAvailable = hasOtaUpdate(widget.device);
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(foregroundColor: getTextColor(widget.color), elevation: 1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (snapshot.connectionState == ConnectionState.active || snapshot.connectionState == ConnectionState.waiting) ...[
                    CircularProgressIndicator(color: getTextColor(widget.color)),
                  ] else ...[
                    Icon(iconData, color: getTextColor(widget.color)),
                  ],
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 4)),
                  Text(convertToUwU(buttonText), style: Theme.of(context).textTheme.labelLarge!.copyWith(color: getTextColor(widget.color))),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class ManageGearConventionMode extends ConsumerWidget {
  final BaseStatefulDevice device;

  const ManageGearConventionMode({super.key, required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      title: Text(convertToUwU(manageGearConModeTitle())),
      subtitle: Text(convertToUwU(manageGearConModeDescription())),
      children: [
        PageInfoCard(text: "Super secret anti hacker power (Insert guide and reset instructions here)"),
        ListTile(
          title: Text(convertToUwU(manageGearConModeToggleTitle())),
          subtitle: Text(convertToUwU(manageGearConModePincodeEnableDescription())),
          trailing: ValueListenableBuilder(
            valueListenable: device.deviceConnectionState,
            builder: (context, connectivityState, child) => Switch(
              value: device.baseStoredDevice.conModeEnabled,
              onChanged: connectivityState == ConnectivityState.connected
                  ? (value) async {
                      //TODO: Validate the setting took correctly. Reboot check?
                      if (value) {
                        BluetoothMessage bluetoothMessage = BluetoothMessage(message: "SETPUSSKEY ${device.baseStoredDevice.conModePin}", timestamp: DateTime.timestamp());
                        device.commandQueue.addCommand(bluetoothMessage);
                        device.baseStoredDevice.conModeEnabled = true;
                        KnownDevices.instance.store();
                        await Clipboard.setData(ClipboardData(text: device.baseStoredDevice.conModePin));
                      } else {
                        //TODO? if gear is disconnected and this is attempted, offer instructions to reset gear
                        BluetoothMessage bluetoothMessage = BluetoothMessage(message: "STOPPUSSKEY", timestamp: DateTime.timestamp());
                        device.commandQueue.addCommand(bluetoothMessage);
                        device.baseStoredDevice.conModeEnabled = false;
                        KnownDevices.instance.store();
                        forgetBond(device.baseStoredDevice.btMACAddress);
                        //TODO: add IOS instructions for clearing bonds
                      }
                    }
                  : null,
            ),
          ),
        ),
        OverflowBar(
          children: [
            FilledButton(
              onPressed: () => PinCodeRoute(pin: device.baseStoredDevice.conModePin).push(context),
              child: Text(manageGearConModePincodeTitle()),
            ),
          ],
        ),
      ],
    );
  }
}

class ManageGearAbout extends StatelessWidget {
  final BaseStatefulDevice device;
  final Color color;

  const ManageGearAbout({super.key, required this.device, required this.color});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(convertToUwU(manageDevicesAboutLabel())),
      children: [
        ListTile(
          dense: true,
          title: Text(convertToUwU(manageDevicesAboutSoftwareVersionLabel()), style: Theme.of(context).textTheme.bodyMedium),
          trailing: ValueListenableBuilder(
            valueListenable: device.fwVersion,
            builder: (context, value, child) {
              return Text("${value.major}.${value.minor}.${value.patch}");
            },
          ),
        ),
        ListTile(
          dense: true,
          title: Text(convertToUwU(manageDevicesAboutHardwareVersionLabel()), style: Theme.of(context).textTheme.bodyMedium),
          trailing: ValueListenableBuilder(
            valueListenable: device.hwVersion,
            builder: (context, value, child) {
              return Text(value);
            },
          ),
        ),
        OverflowBar(
          children: [ManageGearUpdateCheckButton(device: device, color: color)],
        ),
      ],
    );
  }
}

class ManageGearBatteryGraph extends StatelessWidget {
  final BaseStatefulDevice device;

  const ManageGearBatteryGraph({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(convertToUwU(manageDevicesBatteryGraphTitle())),
      children: [
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8, left: 8),
            child: ValueListenableBuilder(
              valueListenable: device.batteryLevel,
              builder: (context, value, child) {
                return LineChart(
                  LineChartData(
                    titlesData: FlTitlesData(
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(axisNameWidget: Text(convertToUwU('Battery'))),
                      bottomTitles: AxisTitles(axisNameWidget: Text(convertToUwU('Time')), sideTitles: SideTitles(showTitles: true)),
                    ),
                    lineTouchData: const LineTouchData(enabled: false),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: 100,
                    minX: 0,
                    maxX: device.batlevels.isNotEmpty ? device.batlevels.last.x : 1,
                    lineBarsData: [
                      LineChartBarData(
                        spots: device.batlevels,
                        color: Theme.of(context).colorScheme.primary,
                        dotData: const FlDotData(show: false),
                        isCurved: true,
                        curveSmoothness: 0.1,
                        preventCurveOverShooting: true,
                        show: device.batlevels.isNotEmpty,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class ManageGearDebug extends ConsumerStatefulWidget {
  final BaseStatefulDevice device;

  const ManageGearDebug({super.key, required this.device});

  @override
  ConsumerState<ManageGearDebug> createState() => _ManageGearDebugState();
}

class _ManageGearDebugState extends ConsumerState<ManageGearDebug> {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      trailing: const Icon(Icons.bug_report),
      title: const Text("Debug (Dangerous)"),
      children: [
        OverflowBar(
          children: [
            FilledButton(
              onPressed: () async {
                BluetoothConsoleRoute($extra: widget.device).push(context);
              },
              child: const Text("Open console"),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FilledButton(
                onPressed: () async {
                  OtaUpdateRoute(device: widget.device.baseStoredDevice.btMACAddress).push(context);
                },
                child: Text(manageDevicesOtaButton()),
              ),
            ),
          ],
        ),
        ListTile(
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("BT MAC: ${widget.device.baseStoredDevice.btMACAddress}"),
              ValueListenableBuilder(valueListenable: widget.device.fwInfo, builder: (context, value, child) => Text("FW AVAIL: ${widget.device.fwInfo.value}")),
              Text("CON ELAPSED: ${widget.device.stopWatch.elapsed}"),
              Text("DEV UUID: ${widget.device.baseDeviceDefinition.uuid}"),
              Text("DEV TYPE: ${widget.device.baseDeviceDefinition.deviceType}"),
              FutureBuilder(
                future: widget.device.baseDeviceDefinition.getFwURL(),
                builder: (context, snapshot) {
                  return Text("DEV FW URL: ${snapshot.data ?? ""}");
                },
              ),
              ValueListenableBuilder(valueListenable: widget.device.mtu, builder: (context, value, child) => Text("MTU: ${widget.device.mtu.value}")),
              Text("MIN FIRMWARE: ${widget.device.baseDeviceDefinition.minVersion}"),
              ValueListenableBuilder(valueListenable: widget.device.gearConfigInfo, builder: (context, value, child) => Text("NVS Config: ${widget.device.gearConfigInfo.value}")),
              ListenableBuilder(listenable: widget.device.commandQueue, builder: (context, child) => Text("QUEUE STATE: ${widget.device.commandQueue.state}")),
            ],
          ),
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.fwVersion,
          builder: (context, value, child) => ListTile(
            title: Text("Firmware Version"),
            subtitle: Flex(
              mainAxisSize: MainAxisSize.min,
              direction: Axis.horizontal,
              spacing: 8,
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: "${widget.device.fwVersion.value.major}"),
                    decoration: InputDecoration(border: const OutlineInputBorder(), label: Text("Major")),
                    maxLines: 1,
                    minLines: 1,
                    maxLength: 2,
                    autocorrect: false,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (nameValue) async {
                      if (nameValue.isEmpty) {
                        return;
                      }
                      setState(() {
                        widget.device.fwVersion.value = Version(major: int.parse(nameValue), minor: widget.device.fwVersion.value.minor, patch: widget.device.fwVersion.value.patch);
                      });
                    },
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: "${widget.device.fwVersion.value.minor}"),
                    decoration: InputDecoration(border: const OutlineInputBorder(), label: Text("Minor")),
                    maxLines: 1,
                    minLines: 1,
                    maxLength: 2,
                    autocorrect: false,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (nameValue) async {
                      if (nameValue.isEmpty) {
                        return;
                      }
                      setState(() {
                        widget.device.fwVersion.value = Version(major: widget.device.fwVersion.value.major, minor: int.parse(nameValue), patch: widget.device.fwVersion.value.patch);
                      });
                    },
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: "${widget.device.fwVersion.value.patch}"),
                    decoration: InputDecoration(border: const OutlineInputBorder(), label: Text("Patch")),
                    maxLines: 1,
                    minLines: 1,
                    maxLength: 2,
                    autocorrect: false,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (nameValue) async {
                      if (nameValue.isEmpty) {
                        return;
                      }
                      setState(() {
                        widget.device.fwVersion.value = Version(major: widget.device.fwVersion.value.major, minor: widget.device.fwVersion.value.minor, patch: int.parse(nameValue));
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.hwVersion,
          builder: (context, value, child) => ListTile(
            title: const Text("Hardware Version"),
            subtitle: TextField(
              controller: TextEditingController(text: widget.device.hwVersion.value),
              decoration: InputDecoration(border: const OutlineInputBorder(), labelText: sequencesEditName()),
              maxLines: 1,
              maxLength: 30,
              autocorrect: false,
              onSubmitted: (nameValue) async {
                setState(() {
                  widget.device.hwVersion.value = nameValue;
                });
              },
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.hasUpdate,
          builder: (context, value, child) => ListTile(
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
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.mandatoryOtaRequired,
          builder: (context, value, child) => ListTile(
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
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.hasGlowtip,
          builder: (context, value, child) => ListTile(
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
              dropdownMenuEntries: GlowtipStatus.values.map((e) => DropdownMenuEntry(value: e, label: e.name)).toList(),
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.hasRGB,
          builder: (context, value, child) => ListTile(
            title: const Text("Has RGB"),
            trailing: DropdownMenu<RGBStatus>(
              initialSelection: widget.device.hasRGB.value,
              onSelected: (RGBStatus? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  widget.device.hasRGB.value = value;
                });
              },
              dropdownMenuEntries: RGBStatus.values.map((e) => DropdownMenuEntry(value: e, label: e.name)).toList(),
            ),
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
        ValueListenableBuilder(
          valueListenable: widget.device.batteryLevel,
          builder: (context, value, child) => ListTile(
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
            trailing: Text("${widget.device.batteryLevel.value}"),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.batteryCharging,
          builder: (context, value, child) => ListTile(
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
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.batteryLow,
          builder: (context, value, child) => ListTile(
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
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.gearReturnedError,
          builder: (context, value, child) => ListTile(
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
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.deviceConnectionState,
          builder: (context, value, child) => ListTile(
            title: const Text("Connection State"),
            trailing: DropdownMenu<ConnectivityState>(
              initialSelection: widget.device.deviceConnectionState.value,
              onSelected: (value) {
                if (value != null) {
                  setState(() {
                    widget.device.deviceConnectionState.value = value;
                  });
                }
              },
              dropdownMenuEntries: ConnectivityState.values.map((e) => DropdownMenuEntry(value: e, label: e.name)).toList(),
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.deviceState,
          builder: (context, value, child) => ListTile(
            title: const Text("Device State"),
            trailing: DropdownMenu<DeviceState>(
              initialSelection: widget.device.deviceState.value,
              onSelected: (value) {
                if (value != null) {
                  setState(() {
                    widget.device.deviceState.value = value;
                  });
                }
              },
              dropdownMenuEntries: DeviceState.values.map((e) => DropdownMenuEntry(value: e, label: e.name)).toList(),
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.isTailCoNTROL,
          builder: (context, value, child) => ListTile(
            title: const Text("isTailCoNTROL"),
            trailing: DropdownMenu<TailControlStatus>(
              initialSelection: widget.device.isTailCoNTROL.value,
              onSelected: (value) {
                if (value != null) {
                  setState(() {
                    widget.device.isTailCoNTROL.value = value;
                  });
                }
              },
              dropdownMenuEntries: TailControlStatus.values.map((e) => DropdownMenuEntry(value: e, label: e.name)).toList(),
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.bluetoothUartService,
          builder: (context, value, child) => ListTile(
            title: const Text("bluetoothUartService"),
            trailing: DropdownMenu<BluetoothUartService>(
              initialSelection: widget.device.bluetoothUartService.value,
              onSelected: (value) {
                setState(() {
                  widget.device.bluetoothUartService.value = value;
                });
              },
              dropdownMenuEntries: uartServices.map((e) => DropdownMenuEntry(value: e, label: e.label)).toList(),
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: widget.device.rssi,
          builder: (context, value, child) => ListTile(
            title: const Text("RSSI Level"),
            trailing: Text("${widget.device.rssi.value}"),
            subtitle: Slider(
              min: -150,
              max: -1,
              value: widget.device.rssi.value.toDouble(),
              onChanged: (double value) {
                setState(() {
                  widget.device.rssi.value = value.toInt();
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

class ManageGearHomePosition extends ConsumerStatefulWidget {
  final BaseStatefulDevice device;

  const ManageGearHomePosition({super.key, required this.device});

  @override
  ConsumerState<ManageGearHomePosition> createState() => _ManageGearHomePositionState();
}

class _ManageGearHomePositionState extends ConsumerState<ManageGearHomePosition> {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(convertToUwU(manageGearHomePositionTitle())),
      subtitle: Text(convertToUwU(manageGearHomePositionDescription())),
      children: [
        ListTile(
          title: Text(convertToUwU(sequencesEditLeftServo())),
          subtitle: Slider(
            value: widget.device.baseStoredDevice.leftHomePosition.toDouble(),
            label: widget.device.baseStoredDevice.leftHomePosition.toString(),
            divisions: 7,
            min: 0,
            max: 8,
            onChangeEnd: (value) => updateHomePosition(),
            onChanged: (value) {
              setState(() {
                widget.device.baseStoredDevice.leftHomePosition = value.toInt();
              });
            },
          ),
        ),
        ListTile(
          title: Text(convertToUwU(sequencesEditRightServo())),
          subtitle: Slider(
            value: widget.device.baseStoredDevice.rightHomePosition.toDouble(),
            label: widget.device.baseStoredDevice.rightHomePosition.toString(),
            divisions: 7,
            min: 0,
            max: 8,
            onChangeEnd: (value) => updateHomePosition(),
            onChanged: (value) {
              setState(() {
                widget.device.baseStoredDevice.rightHomePosition = value.toInt();
              });
            },
          ),
        ),
      ],
    );
  }

  void updateHomePosition() {
    Move move = Move.move(
      leftServo: (widget.device.baseStoredDevice.leftHomePosition.clamp(0, 8).toDouble() * 16).clamp(0, 127),
      rightServo: (widget.device.baseStoredDevice.rightHomePosition.clamp(0, 8).toDouble() * 16).clamp(0, 127),
    );
    generateMoveCommand(move, widget.device, CommandType.direct, priority: Priority.high);
    BluetoothMessage bluetoothMessage = BluetoothMessage(message: "SETHOME", timestamp: DateTime.now(), responseMSG: "OK", priority: Priority.high);
    widget.device.commandQueue.addCommand(bluetoothMessage);
  }
}
