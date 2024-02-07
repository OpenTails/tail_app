import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:simple_circular_progress_bar/simple_circular_progress_bar.dart';
import 'package:tail_app/Frontend/intnDefs.dart';

import '../../Backend/AutoMove.dart';
import '../../Backend/Bluetooth/BluetoothManager.dart';
import '../../Backend/Definitions/Device/BaseDeviceDefinition.dart';

class ManageKnownDevices extends ConsumerStatefulWidget {
  const ManageKnownDevices({super.key});

  @override
  ConsumerState<ManageKnownDevices> createState() => _ManageKnownDevicesState();
}

class _ManageKnownDevicesState extends ConsumerState<ManageKnownDevices> {
  final ScrollController _controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    List<BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider).values.toList();
    return ListView.builder(
        controller: _controller,
        shrinkWrap: true,
        itemCount: knownDevices.length,
        itemBuilder: (BuildContext context, int index) {
          return ExpansionTile(
            title: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(knownDevices[index].baseStoredDevice.name),
            ),
            subtitle: MultiValueListenableBuilder(
              valueListenables: [knownDevices[index].deviceConnectionState, knownDevices[index].rssi],
              builder: (BuildContext context, List<dynamic> values, Widget? child) {
                return Text("${knownDevices[index].baseStoredDevice.btMACAddress} | ${knownDevices[index].deviceConnectionState.value.name} | RSSI: ${knownDevices[index].rssi.value}");
              },
            ),
            leading: ValueListenableBuilder(
              valueListenable: knownDevices[index].deviceConnectionState,
              builder: (BuildContext context, DeviceConnectionState value, Widget? child) {
                if (knownDevices[index].deviceConnectionState.value == DeviceConnectionState.connected) {
                  return SimpleCircularProgressBar(
                    size: 50,
                    animationDuration: 1,
                    backStrokeWidth: 5,
                    progressStrokeWidth: 10,
                    onGetText: (number) => Text("${knownDevices[index].battery.value.round()}"),
                    progressColors: const [
                      Colors.red,
                      Colors.orange,
                      Colors.green,
                      Colors.green,
                      Colors.green,
                    ],
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
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: sequencesEditName(),
                      hintText: knownDevices[index].baseDeviceDefinition.btName,
                    ),
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
                title: Text(manageDevicesAutoMoveTitle()),
                subtitle: Text(manageDevicesAutoMoveSubTitle()),
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
                title: Text(manageDevicesAutoMoveGroupsTitle()),
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
                  title: Text(manageDevicesAutoMovePauseTitle()),
                  subtitle: RangeSlider(
                    labels: RangeLabels(manageDevicesAutoMovePauseSliderLabel(knownDevices[index].baseStoredDevice.autoMoveMinPause.round()), manageDevicesAutoMovePauseSliderLabel(knownDevices[index].baseStoredDevice.autoMoveMaxPause.round())),
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
                title: Text(manageDevicesAutoMoveNoPhoneTitle()),
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
                  label: manageDevicesAutoMoveNoPhoneSliderLabel(knownDevices[index].baseStoredDevice.noPhoneDelayTime.round()),
                ),
              ),
              ButtonBar(
                alignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        knownDevices[index].connectionStateStreamSubscription = null;
                      });
                    },
                    child: Text(manageDevicesDisconnect()),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        knownDevices[index].connectionStateStreamSubscription = null;
                      });
                      ref.watch(knownDevicesProvider.notifier).remove(knownDevices[index].baseStoredDevice.btMACAddress);
                    },
                    child: Text(manageDevicesForget()),
                  )
                ],
              )
            ],
          );
        });
  }
}
