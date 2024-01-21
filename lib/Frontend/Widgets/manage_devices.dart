import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_ble_platform_interface/src/model/connection_state_update.dart';
import 'package:simple_circular_progress_bar/simple_circular_progress_bar.dart';
import 'package:tail_app/Backend/AutoMove.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';
import 'package:tail_app/Frontend/Widgets/scan_for_new_device.dart';

class ManageDevices extends ConsumerStatefulWidget {
  const ManageDevices({super.key});

  @override
  _ManageDevicesState createState() => _ManageDevicesState();
}

class _ManageDevicesState extends ConsumerState<ManageDevices> {
  final ScrollController _controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    final List<BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider).values.toList();
    return ListView(
      children: [
        ListView.builder(
            controller: _controller,
            shrinkWrap: true,
            itemCount: knownDevices.length,
            itemBuilder: (BuildContext context, int index) {
              return ExpansionTile(
                title: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(knownDevices[index].baseStoredDevice.name),
                ),
                subtitle: ValueListenableBuilder(
                  builder: (BuildContext context, DeviceConnectionState value, Widget? child) {
                    return Text("${knownDevices[index].baseStoredDevice.btMACAddress} | ${value.name}");
                  },
                  valueListenable: knownDevices[index].deviceConnectionState,
                ),
                leading: ValueListenableBuilder(
                  valueListenable: knownDevices[index].deviceConnectionState,
                  builder: (BuildContext context, DeviceConnectionState value, Widget? child) {
                    if (knownDevices[index].deviceConnectionState.value == DeviceConnectionState.connected) {
                      return SimpleCircularProgressBar(
                        //TODO: Replace with disconnected icon
                        size: 50,
                        animationDuration: 1,
                        backStrokeWidth: 5,
                        progressStrokeWidth: 10,
                        onGetText: (number) => Text("${knownDevices[index].battery.value.round()}"),
                        progressColors: const [Colors.red, Colors.orange, Colors.green, Colors.green, Colors.green],
                        fullProgressColor: Colors.green,
                        mergeMode: true,
                        valueNotifier: knownDevices[index].battery,
                      );
                    } else {
                      return const Icon(Icons.question_mark);
                    }
                  },
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                        controller: TextEditingController(text: knownDevices[index].baseStoredDevice.name),
                        decoration: InputDecoration(border: const OutlineInputBorder(), labelText: 'Name', hintText: knownDevices[index].baseDeviceDefinition.btName),
                        maxLines: 1,
                        maxLength: 30,
                        autocorrect: false,
                        onSubmitted: (nameValue) {
                          setState(() {
                            if (nameValue.isNotEmpty) {
                              knownDevices[index].baseStoredDevice.name = nameValue;
                            } else {
                              knownDevices[index].baseStoredDevice.name = knownDevices[index].baseDeviceDefinition.btName;
                            }
                          });
                          ref.read(knownDevicesProvider.notifier).store();
                        }),
                  ),
                  ListTile(
                    title: const Text("Auto Move"),
                    subtitle: const Text("The tail will select a random move, pausing for a random number of seconds between each move"),
                    trailing: Switch(
                      value: knownDevices[index].baseStoredDevice.autoMove,
                      onChanged: (bool value) {
                        setState(() {
                          knownDevices[index].baseStoredDevice.autoMove = value;
                        });
                        ref.read(knownDevicesProvider.notifier).store();
                        ChangeAutoMove(knownDevices[index]);
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text("Move Groups"),
                    subtitle: SegmentedButton<AutoActionCategory>(
                      multiSelectionEnabled: true,
                      selected: knownDevices[index].baseStoredDevice.selectedAutoCategories.toSet(),
                      onSelectionChanged: (Set<AutoActionCategory> value) {
                        setState(() {
                          knownDevices[index].baseStoredDevice.selectedAutoCategories = value.toList();
                        });
                        ref.read(knownDevicesProvider.notifier).store();
                        ChangeAutoMove(knownDevices[index]);
                      },
                      segments: AutoActionCategory.values.map<ButtonSegment<AutoActionCategory>>((AutoActionCategory value) {
                        return ButtonSegment<AutoActionCategory>(
                          value: value,
                          label: Text(value.friendly),
                        );
                      }).toList(),
                    ),
                  ),
                  ListTile(
                      title: const Text("Pause between moves"),
                      subtitle: RangeSlider(
                        labels: RangeLabels("${knownDevices[index].baseStoredDevice.autoMoveMinPause} seconds", "${knownDevices[index].baseStoredDevice.autoMoveMaxPause} seconds"),
                        min: 15,
                        max: 240,
                        values: RangeValues(knownDevices[index].baseStoredDevice.autoMoveMinPause, knownDevices[index].baseStoredDevice.autoMoveMaxPause),
                        onChanged: (RangeValues value) {
                          setState(() {
                            knownDevices[index].baseStoredDevice.autoMoveMinPause = value.start;
                            knownDevices[index].baseStoredDevice.autoMoveMaxPause = value.end;
                          });
                          ref.read(knownDevicesProvider.notifier).store();
                        },
                        onChangeEnd: (values) {
                          ChangeAutoMove(knownDevices[index]);
                        },
                      )),
                  ListTile(
                    title: const Text("No-Phone-Mode Start Delay"),
                    subtitle: Slider(
                      value: knownDevices[index].baseStoredDevice.noPhoneDelayTime,
                      min: 1,
                      max: 60,
                      onChanged: (double value) {
                        setState(() {
                          knownDevices[index].baseStoredDevice.noPhoneDelayTime = value;
                        });
                        ref.read(knownDevicesProvider.notifier).store();
                      },
                      label: "${knownDevices[index].baseStoredDevice.noPhoneDelayTime} Minutes",
                    ),
                  ),
                  ButtonBar(
                    alignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            knownDevices[index].connectionStateStream = null;
                          });
                        },
                        child: const Text("Disconnect"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            knownDevices[index].connectionStateStream = null;
                          });
                          ref.watch(knownDevicesProvider.notifier).remove(knownDevices[index].baseStoredDevice.btMACAddress);
                        },
                        child: const Text("Forget"),
                      )
                    ],
                  )
                ],
              );
            }),
        //const Divider(height: 25),

        const ScanForNewDevice(),
      ],
    );
  }
}
