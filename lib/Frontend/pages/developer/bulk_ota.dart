import 'package:built_collection/built_collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/device_registry.dart';
import 'package:tail_app/Backend/firmware_update.dart';
import 'package:tail_app/Frontend/Widgets/device_type_widget.dart';

import '../../../Backend/Definitions/Device/device_definition.dart';

class BulkOTA extends ConsumerStatefulWidget {
  const BulkOTA({super.key});

  @override
  ConsumerState<BulkOTA> createState() => _BulkOTAState();
}

class _BulkOTAState extends ConsumerState<BulkOTA> {
  List<DeviceType> selectedDeviceType = DeviceType.values;
  BuiltMap<BaseStatefulDevice, OtaUpdater>? updatableDevices;

  @override
  void initState() {
    super.initState();
    initDevices();
  }

  void initDevices() {
    BuiltList<BaseStatefulDevice> devices = ref.read(getAvailableGearForTypeProvider(selectedDeviceType.toBuiltSet()));
    setState(() {
      updatableDevices = BuiltMap.build(
        (MapBuilder<BaseStatefulDevice, OtaUpdater> p0) {
          p0.addEntries(
            devices.map(
              (baseStatefulDevice) {
                return MapEntry(
                  baseStatefulDevice,
                  OtaUpdater(
                    baseStatefulDevice: baseStatefulDevice,
                    onStateChanged: (p0) => setState(() {}),
                  ),
                );
              },
            ),
          );
        },
      );
    });
  }

  void beginOta() {
    for (var device in updatableDevices!.values) {
      device.beginUpdate();
    }
  }

  void abort() {
    for (var device in updatableDevices!.values) {
      device.otaState = OtaState.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool otaInProgress = updatableDevices!.values
        .where(
          (element) => [OtaState.download, OtaState.upload].contains(element.otaState),
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
            appBar: AppBar(
              title: Text("Update all the things"),
            ),
            body: ListView(
              children: [
                DeviceTypeWidget(
                  alwaysVisible: true,
                  selected: selectedDeviceType,
                  onSelectionChanged: (value) {
                    setState(() {
                      selectedDeviceType = value;
                    });
                    initDevices();
                  },
                ),
                OverflowBar(
                  alignment: MainAxisAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: otaInProgress || updatableDevices!.isEmpty
                          ? null
                          : () {
                              for (OtaUpdater otaUpdater in updatableDevices!.values) {
                                otaUpdater.beginUpdate();
                              }
                            },
                      child: Text("Begin"),
                    ),
                    FilledButton(
                      onPressed: !otaInProgress
                          ? null
                          : () {
                              for (OtaUpdater otaUpdater in updatableDevices!.values) {
                                otaUpdater.otaState = OtaState.error;
                              }
                            },
                      child: Text("Abort"),
                    ),
                    ElevatedButton(
                      onPressed: updatableDevices!.isEmpty || selectedDeviceType.length != 1
                          ? null
                          : () async {
                              FilePickerResult? result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                withData: true,
                                allowedExtensions: ['bin'],
                              );
                              if (result != null) {
                                setState(() {
                                  for (OtaUpdater otaUpdater in updatableDevices!.values) {
                                    otaUpdater.setManualOtaFile(result.files.single.bytes?.toList(growable: false));
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
                if (updatableDevices!.isNotEmpty) ...[
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: updatableDevices!.length,
                    itemBuilder: (context, index) {
                      MapEntry<BaseStatefulDevice, OtaUpdater> device = updatableDevices!.entries.toList()[index];
                      return OtaListItem(device: device);
                    },
                  ),
                ],
              ],
            )));
  }
}

class OtaListItem extends StatefulWidget {
  const OtaListItem({
    super.key,
    required this.device,
  });

  final MapEntry<BaseStatefulDevice, OtaUpdater> device;

  @override
  State<OtaListItem> createState() => _OtaListItemState();
}

class _OtaListItemState extends State<OtaListItem> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.device.key.baseStoredDevice.name),
      trailing: Text(widget.device.value.otaState.name),
      subtitle: LinearProgressIndicator(
        value: widget.device.value.progress,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.device.value.onProgress = progressListener;
  }

  @override
  void dispose() {
    super.dispose();
    widget.device.value.onProgress = null;
  }

  void progressListener(double progress) {
    setState(() {});
  }
}
