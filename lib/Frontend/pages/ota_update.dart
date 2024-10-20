import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/firmware_update.dart';
import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../../gen/assets.gen.dart';
import '../Widgets/lottie_lazy_load.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';

class OtaUpdate extends ConsumerStatefulWidget {
  const OtaUpdate({required this.device, super.key});

  final String device;

  @override
  ConsumerState<OtaUpdate> createState() => _OtaUpdateState();
}

class _OtaUpdateState extends ConsumerState<OtaUpdate> {
  late OtaUpdater otaUpdater;
  BaseStatefulDevice? baseStatefulDevice;

  @override
  void initState() {
    super.initState();
    baseStatefulDevice = ref.read(knownDevicesProvider)[widget.device];
    otaUpdater = OtaUpdater(
      baseStatefulDevice: baseStatefulDevice!,
      onProgress: (p0) => setState(() {}),
      onStateChanged: (p0) => setState(() {}),
    );
    unawaited(ref.read(hasOtaUpdateProvider(baseStatefulDevice!).future));
  }

  @override
  void dispose() {
    super.dispose();
    otaUpdater.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(otaTitle())),
      body: Center(
        child: AnimatedSwitcher(
          duration: animationTransitionDuration,
          child: Flex(
            key: ValueKey(otaUpdater.otaState),
            mainAxisAlignment: MainAxisAlignment.center,
            direction: Axis.vertical,
            children: [
              if ([OtaState.standby, OtaState.manual].contains(otaUpdater.otaState)) ...[
                if (HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) ...[
                  Expanded(
                    child: ListTile(
                      title: const Text("Debug"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("MD5: ${otaUpdater.firmwareInfo?.md5sum}"),
                          Text("DL MD5: ${otaUpdater.downloadedMD5}"),
                          Text("URL: ${baseStatefulDevice?.baseDeviceDefinition.fwURL}"),
                          Text("AVAILABLE VERSION: ${otaUpdater.firmwareInfo?.version}"),
                          Text("CURRENT VERSION: ${baseStatefulDevice?.fwVersion.value}"),
                          Text("STATE: ${otaUpdater.otaState}"),
                        ],
                      ),
                    ),
                  ),
                ],
                Expanded(
                  flex: 2,
                  child: Center(
                    child: LottieLazyLoad(
                      width: MediaQuery.of(context).size.width,
                      asset: Assets.tailcostickers.tailCoStickersFile144834357,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: ListTile(
                      title: Text(otaChangelogLabel()),
                      subtitle: Text(otaUpdater.firmwareInfo?.changelog ?? "Unavailable"),
                    ),
                  ),
                ),
                Expanded(
                  child: SafeArea(
                    child: OverflowBar(
                      alignment: MainAxisAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: (otaUpdater.firmwareInfo != null || otaUpdater.firmwareFile != null) ? otaUpdater.beginUpdate : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.system_update,
                                color: getTextColor(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                              ),
                              Text(
                                otaDownloadButtonLabel(),
                                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                                      color: getTextColor(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) ...[
                          ElevatedButton(
                            onPressed: () async {
                              FilePickerResult? result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                withData: true,
                                allowedExtensions: ['bin'],
                              );
                              if (result != null) {
                                setState(() {
                                  otaUpdater.setManualOtaFile(result.files.single.bytes?.toList(growable: false));
                                });
                              } else {
                                // User canceled the picker
                              }
                            },
                            child: const Text("Select file"),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (otaUpdater.otaState == OtaState.completed) ...[
                Expanded(
                  child: Center(
                    child: ListTile(
                      title: Text(
                        otaCompletedTitle(),
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: LottieLazyLoad(
                      asset: Assets.tailcostickers.tailCoStickersFile144834339,
                      width: MediaQuery.of(context).size.width,
                    ),
                  ),
                ),
              ],
              if (otaUpdater.otaState == OtaState.error) ...[
                Expanded(
                  child: Center(
                    child: ListTile(
                      title: Text(
                        otaFailedTitle(),
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: LottieLazyLoad(
                      asset: Assets.tailcostickers.tailCoStickersFile144834348,
                      width: MediaQuery.of(context).size.width,
                    ),
                  ),
                ),
              ],
              if (otaUpdater.otaState == OtaState.lowBattery) ...[
                Expanded(
                  child: Center(
                    child: ListTile(
                      title: Text(
                        otaLowBattery(),
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: LottieLazyLoad(
                      asset: Assets.tailcostickers.tailCoStickersFile144834342,
                      width: MediaQuery.of(context).size.width,
                    ),
                  ),
                ),
              ],
              if ([OtaState.download, OtaState.upload, OtaState.rebooting].contains(otaUpdater.otaState)) ...[
                Expanded(
                  child: Center(
                    child: ListTile(
                      title: Text(
                        otaInProgressTitle(),
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Spin(
                    infinite: true,
                    duration: const Duration(seconds: 1, milliseconds: 500),
                    child: Transform.flip(
                      flipX: true,
                      child: LottieLazyLoad(
                        asset: Assets.tailcostickers.tailCoStickersFile144834340,
                        width: MediaQuery.of(context).size.width,
                        renderCache: true,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ListTile(
                      subtitle: Builder(
                        builder: (context) {
                          return LinearProgressIndicator(value: otaUpdater.otaState == OtaState.rebooting ? null : otaUpdater.progress);
                        },
                      ),
                    ),
                  ),
                ),
                if (HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) ...[
                  Expanded(
                    child: ListTile(
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Upload Progress: ${otaUpdater.current} / ${otaUpdater.firmwareFile?.length} = ${otaUpdater.uploadProgress.toStringAsPrecision(3)}'),
                          Text('MTU: ${baseStatefulDevice!.mtu.value}'),
                          Text('OtaState: ${otaUpdater.otaState.name}'),
                          Text('DeviceState: ${baseStatefulDevice!.deviceState.value}'),
                          Text('ConnectivityState: ${baseStatefulDevice!.deviceConnectionState.value}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
