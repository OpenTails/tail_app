import 'package:fl_chart/fl_chart.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/move_lists.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../Backend/Bluetooth/bluetooth_message.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/device_registry.dart';
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
              if (device!.hasUpdate.value) ...[
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
                  ColorPickerRoute(defaultColor: color!.value).push(context).then(
                        (color) => setState(() {
                          if (color != null) {
                            device!.baseStoredDevice.color = color;
                            this.color = Color(color);
                            ref.invalidate(getAvailableGearProvider);
                            ref.read(knownDevicesProvider.notifier).store();
                          }
                        }),
                      );
                },
              ),
              if (HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) ...[
                if (device!.baseDeviceDefinition.deviceType == DeviceType.ears) ...[
                  ManageGearHomePosition(device: device!),
                ],
                ManageGearBatteryGraph(device: device!),
                ManageGearDebug(device: device!),
              ],
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

class ManageGearBatteryGraph extends StatelessWidget {
  final BaseStatefulDevice device;

  const ManageGearBatteryGraph({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(manageDevicesBatteryGraphTitle()),
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
                    maxX: device.stopWatch.elapsed.inSeconds.toDouble(),
                    lineBarsData: [LineChartBarData(spots: device.batlevels, color: Theme.of(context).colorScheme.primary, dotData: const FlDotData(show: false), isCurved: true, show: device.batlevels.isNotEmpty)],
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

class ManageGearDebug extends StatefulWidget {
  final BaseStatefulDevice device;

  const ManageGearDebug({super.key, required this.device});

  @override
  State<ManageGearDebug> createState() => _ManageGearDebugState();
}

class _ManageGearDebugState extends State<ManageGearDebug> {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
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
                child: Text(
                  manageDevicesOtaButton(),
                ),
              ),
            )
          ],
        ),
        ListTile(
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text("NVS Config: ${widget.device.gearConfigInfo.value}"),
              Text("UART Service: ${widget.device.bluetoothUartService.value}"),
            ],
          ),
        ),
        ListTile(
          title: const Text("Hardware Version"),
          subtitle: TextField(
            controller: TextEditingController(text: widget.device.hwVersion.value),
            decoration: InputDecoration(border: const OutlineInputBorder(), labelText: sequencesEditName()),
            maxLines: 1,
            maxLength: 30,
            autocorrect: false,
            onSubmitted: (nameValue) async {
              setState(
                () {
                  widget.device.hwVersion.value = nameValue;
                },
              );
            },
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
      title: Text(manageGearHomePositionTitle()),
      subtitle: Text(manageGearHomePositionDescription()),
      children: [
        ListTile(
          title: Text(sequencesEditLeftServo()),
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
          title: Text(sequencesEditRightServo()),
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
    Move move = Move.move(leftServo: (widget.device.baseStoredDevice.leftHomePosition.clamp(0, 8).toDouble() * 16).clamp(0, 127), rightServo: (widget.device.baseStoredDevice.rightHomePosition.clamp(0, 8).toDouble() * 16).clamp(0, 127));
    generateMoveCommand(move, widget.device, CommandType.direct, priority: Priority.high);
    BluetoothMessage bluetoothMessage = BluetoothMessage(message: "SETHOME", device: widget.device, timestamp: DateTime.now(), responseMSG: "OK", priority: Priority.high);
    widget.device.commandQueue.addCommand(bluetoothMessage);
  }
}
