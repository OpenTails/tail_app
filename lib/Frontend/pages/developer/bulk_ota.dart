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

  @override
  void initState() {
    super.initState();
  }

  void beginOta() {
    for (var device in ref.read(getAvailableGearForTypeProvider(selectedDeviceType.toBuiltSet()))) {
      ref.read(otaUpdaterProvider(device).notifier).beginUpdate();
    }
  }

  void abort() {
    for (var device in ref.read(getAvailableGearForTypeProvider(selectedDeviceType.toBuiltSet()))) {
      ref.read(otaUpdaterProvider(device).notifier).abort();
    }
  }

  @override
  Widget build(BuildContext context) {
    var devices = ref.read(getAvailableGearForTypeProvider(selectedDeviceType.toBuiltSet()));
    bool otaInProgress = devices
        .map((p0) => ref.read(otaUpdaterProvider(p0)))
        .where(
          (element) => [OtaState.download, OtaState.upload].contains(element),
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
                                ref.read(otaUpdaterProvider(device).notifier).beginUpdate();
                              }
                            },
                      child: Text("Begin"),
                    ),
                    FilledButton(
                      onPressed: !otaInProgress
                          ? null
                          : () {
                              for (BaseStatefulDevice device in devices) {
                                ref.read(otaUpdaterProvider(device).notifier).abort();
                              }
                            },
                      child: Text("Abort"),
                    ),
                    ElevatedButton(
                      onPressed: devices.isEmpty || selectedDeviceType.length != 1
                          ? null
                          : () async {
                              FilePickerResult? result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                withData: true,
                                allowedExtensions: ['bin'],
                              );
                              if (result != null) {
                                setState(() {
                                  for (BaseStatefulDevice device in devices) {
                                    ref.read(otaUpdaterProvider(device).notifier).setManualOtaFile(result.files.single.bytes?.toList(growable: false));
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
                      return OtaListItem(device: devices[index]);
                    },
                  ),
                ],
              ],
            )));
  }
}

class OtaListItem extends ConsumerStatefulWidget {
  const OtaListItem({
    super.key,
    required this.device,
  });

  final BaseStatefulDevice device;

  @override
  ConsumerState<OtaListItem> createState() => _OtaListItemState();
}

class _OtaListItemState extends ConsumerState<OtaListItem> {
  @override
  Widget build(BuildContext context) {
    var otaState = ref.read(otaUpdaterProvider(widget.device));

    var watch = ref.read(otaUpdaterProvider(widget.device).notifier);
    return ListTile(
      title: Text(widget.device.baseStoredDevice.name),
      trailing: Text(otaState.toString()),
      subtitle: LinearProgressIndicator(
        value: watch.progress,
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
