import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

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
  BaseStatefulDevice? baseStatefulDevice;
  OtaError? otaError;

  @override
  void initState() {
    super.initState();
    baseStatefulDevice = ref.read(knownDevicesProvider)[widget.device];
    ref.read(hasOtaUpdateProvider(baseStatefulDevice!).future);
    ref.read(OtaUpdaterProvider(baseStatefulDevice!).notifier).onError = ((OtaError p0) => setState(() => otaError = p0));
  }

  @override
  void dispose() {
    super.dispose();
  }

  String getErrorMessage(OtaError otaError) {
    switch (otaError) {
      case OtaError.md5Mismatch:
        return otaFailedReasonMD5Mismatch();
      case OtaError.downloadFailed:
        return otaFailedReasonDownloadFailed();
      case OtaError.gearVersionMismatch:
        return otaFailedReasonGearVersionMismatch();
      case OtaError.gearReturnedError:
        return otaFailedReasonGearReturnedError();
      case OtaError.uploadFailed:
        return otaFailedReasonUploadFailed();
      case OtaError.gearReconnectTimeout:
        return otaFailedReasonGearReconnectTimeout();
      case OtaError.gearDisconnectTimeout:
        return otaFailedReasonGearDisconnectTimeout();
      case OtaError.gearOtaFinalTimeout:
        return otaFailedReasonGearOtaFinalTimeout();
    }
  }

  @override
  Widget build(BuildContext context) {
    OtaState otaState = ref.watch(OtaUpdaterProvider(baseStatefulDevice!));
    OtaUpdater otaUpdater = ref.read(OtaUpdaterProvider(baseStatefulDevice!).notifier);
    return Scaffold(
      appBar: AppBar(title: Text(convertToUwU(otaTitle()))),
      body: Center(
        child: AnimatedSwitcher(
          duration: animationTransitionDuration,
          child: Flex(
            key: ValueKey(otaState),
            mainAxisAlignment: MainAxisAlignment.center,
            direction: Axis.vertical,
            children: [
              if ([OtaState.standby, OtaState.manual].contains(otaState)) ...[
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
                          Text("STATE: ${otaState}"),
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
                      title: Text(convertToUwU(otaChangelogLabel())),
                      subtitle: Text(convertToUwU(otaUpdater.firmwareInfo?.changelog ?? "Unavailable")),
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
                                convertToUwU(otaDownloadButtonLabel()),
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
                            child: Text("Select file"),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (otaState == OtaState.completed) ...[
                Expanded(
                  child: Center(
                    child: ListTile(
                      title: Text(
                        convertToUwU(otaCompletedTitle()),
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
              if (otaState == OtaState.error) ...[
                Expanded(
                  child: Center(
                    child: ListTile(
                      title: Text(
                        convertToUwU(otaFailedTitle()),
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      subtitle: Text(
                        convertToUwU(otaError != null ? getErrorMessage(otaError!) : ""),
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
              if (otaState == OtaState.lowBattery) ...[
                Expanded(
                  child: Center(
                    child: ListTile(
                      title: Text(
                        convertToUwU(otaLowBattery()),
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
              if ([OtaState.download, OtaState.upload, OtaState.rebooting].contains(otaState)) ...[
                Expanded(
                  child: Center(
                    child: ListTile(
                      title: Text(
                        convertToUwU(otaInProgressTitle()),
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: LottieLazyLoad(
                    asset: Assets.tailcostickers.tailCoStickersFile144834340,
                    width: MediaQuery.of(context).size.width,
                    renderCache: true,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ListTile(
                      subtitle: Builder(
                        builder: (context) {
                          return LinearProgressIndicator(value: otaState == OtaState.rebooting ? null : otaUpdater.progress);
                        },
                      ),
                    ),
                  ),
                ),
                if (HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) ...[
                  Expanded(
                    child: ListTile(
                      trailing: const Icon(Icons.bug_report),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Upload Progress: ${otaUpdater.currentFirmwareUploadPosition} / ${otaUpdater.firmwareFile?.length} = ${otaUpdater.uploadProgress.toStringAsPrecision(3)}'),
                          Text('MTU: ${baseStatefulDevice!.mtu.value}'),
                          Text('OtaState: ${otaState.name}'),
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
