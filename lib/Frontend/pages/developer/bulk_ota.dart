import 'package:built_collection/built_collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Backend/firmware_update.dart';
import 'package:tail_app/Frontend/Widgets/device_type_widget.dart';

import '../../../Backend/Definitions/Device/device_definition.dart';

class BulkOTA extends StatefulWidget {
  const BulkOTA({super.key});

  @override
  State<BulkOTA> createState() => _BulkOTAState();
}

class _BulkOTAState extends State<BulkOTA> {
  List<DeviceType> selectedDeviceType = DeviceType.values;
  Map<BaseStatefulDevice, OtaUpdater> updaters = {};
  BuiltList<BaseStatefulDevice> devices = BuiltList();

  @override
  void initState() {
    super.initState();
    refreshDevices();
  }

  void refreshDevices() {
    devices = KnownDevices.instance.getConnectedGearForType(
      selectedDeviceType.toBuiltSet(),
    );
  }

  void beginOta() {
    for (var device in devices) {
      if (updaters.containsKey(device)) {
        continue;
      }
      updaters[device] = OtaUpdater(device);
      updaters[device]!.beginUpdate();
    }
  }

  void abort() {
    for (var device in devices) {
      updaters[device]!.abort();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool otaInProgress = devices
        .map((p0) => updaters[p0])
        .nonNulls
        .where(
          (element) =>
              [OtaState.download, OtaState.upload].contains(element.otaState),
        )
        .isNotEmpty;

    return PopScope(
      canPop: !otaInProgress,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          abort();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text("Update all the things")),
        body: ListView(
          children: [
            DeviceTypeWidget(
              alwaysVisible: true,
              selected: selectedDeviceType,
              onSelectionChanged: (value) {
                setState(() {
                  selectedDeviceType = value;
                  refreshDevices();
                });
              },
            ),
            OverflowBar(
              alignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: otaInProgress || devices.isEmpty
                      ? null
                      : () {
                          for (BaseStatefulDevice device in devices) {
                            updaters[device]!.beginUpdate();
                          }
                        },
                  child: Text("Begin"),
                ),
                FilledButton(
                  onPressed: !otaInProgress
                      ? null
                      : () {
                          for (BaseStatefulDevice device in devices) {
                            updaters[device]!.abort();
                          }
                        },
                  child: Text("Abort"),
                ),
                ElevatedButton(
                  onPressed: devices.isEmpty || selectedDeviceType.length != 1
                      ? null
                      : () async {
                          FilePickerResult? result = await FilePicker.platform
                              .pickFiles(
                                type: FileType.custom,
                                withData: true,
                                allowedExtensions: ['bin'],
                              );
                          if (result != null) {
                            setState(() {
                              for (BaseStatefulDevice device in devices) {
                                updaters[device]!.setManualOtaFile(
                                  result.files.single.bytes?.toList(
                                    growable: false,
                                  ),
                                );
                              }
                            });
                          } else {
                            // User canceled the picker
                          }
                        },
                  child: const Text("Select file"),
                ),
              ],
            ),
            if (devices.isNotEmpty) ...[
              ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  BaseStatefulDevice device = devices[index];
                  return OtaListItem(
                    device: device,
                    otaUpdater: updaters[device]!,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class OtaListItem extends StatefulWidget {
  const OtaListItem({
    super.key,
    required this.device,
    required this.otaUpdater,
  });

  final BaseStatefulDevice device;
  final OtaUpdater otaUpdater;

  @override
  State<OtaListItem> createState() => _OtaListItemState();
}

class _OtaListItemState extends State<OtaListItem> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.otaUpdater,
      builder: (context, child) => ListTile(
        title: Text(widget.device.baseStoredDevice.name),
        trailing: Text(widget.otaUpdater.otaState.toString()),
        subtitle: LinearProgressIndicator(value: widget.otaUpdater.progress),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
