import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/firmware_update.dart';
import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../../gen/assets.gen.dart';
import '../Widgets/lottie_lazy_load.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';

class OtaUpdate extends StatefulWidget {
  late final OtaUpdater otaUpdater;
  final String deviceMac;
  late final StatefulDevice device;

  OtaUpdate({required this.deviceMac, super.key}) {
    device = KnownDevices.instance.connectedGear.firstWhere(
      (p0) => p0.storedDevice.btMACAddress == deviceMac,
    );
    otaUpdater = OtaUpdater(device);
  }

  @override
  State<OtaUpdate> createState() => _OtaUpdateState();
}

class _OtaUpdateState extends State<OtaUpdate> {
  OtaError? otaError;

  @override
  void initState() {
    super.initState();
    hasOtaUpdate(widget.device);
    widget.otaUpdater.addListener(onStateChange);
    widget.otaUpdater.onError = ((OtaError p0) =>
        setState(() => otaError = p0));
  }

  @override
  void dispose() {
    super.dispose();
    widget.otaUpdater.removeListener(onStateChange);
  }

  void onStateChange() {
    setState(() {});
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
    OtaState otaState = widget.otaUpdater.otaState;

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
                if (HiveProxy.getOrDefault(
                  settings,
                  showDebugging,
                  defaultValue: showDebuggingDefault,
                )) ...[
                  Expanded(
                    child: ListTile(
                      title: const Text("Debug"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "MD5: ${widget.otaUpdater.firmwareInfo?.md5sum}",
                          ),
                          Text("DL MD5: ${widget.otaUpdater.downloadedMD5}"),
                          FutureBuilder(
                            future: widget.device.deviceDefinition.getFwURL(),
                            builder: (context, snapshot) {
                              return Text("URL: ${snapshot.data ?? ""}");
                            },
                          ),
                          Text(
                            "AVAILABLE VERSION: ${widget.otaUpdater.firmwareInfo?.version}",
                          ),
                          Text(
                            "CURRENT VERSION: ${widget.device.fwVersion.value}",
                          ),
                          Text("STATE: $otaState"),
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
                      subtitle: Text(
                        convertToUwU(
                          widget.otaUpdater.firmwareInfo?.changelog ??
                              "Unavailable",
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SafeArea(
                    child: OverflowBar(
                      alignment: MainAxisAlignment.center,
                      children: [
                        FilledButton(
                          onPressed:
                              (widget.otaUpdater.firmwareInfo != null ||
                                  widget.otaUpdater.firmwareFile != null)
                              ? widget.otaUpdater.beginUpdate
                              : null,
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
                                style: Theme.of(context).textTheme.labelLarge!
                                    .copyWith(
                                      color: getTextColor(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (HiveProxy.getOrDefault(
                          settings,
                          showDebugging,
                          defaultValue: showDebuggingDefault,
                        )) ...[
                          ElevatedButton(
                            onPressed: () async {
                              FilePickerResult? result = await FilePicker
                                  .platform
                                  .pickFiles(
                                    type: FileType.custom,
                                    withData: true,
                                    allowedExtensions: ['bin'],
                                  );
                              if (result != null) {
                                setState(() {
                                  widget.otaUpdater.setManualOtaFile(
                                    result.files.single.bytes?.toList(
                                      growable: false,
                                    ),
                                  );
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
                        convertToUwU(
                          otaError != null ? getErrorMessage(otaError!) : "",
                        ),
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
              if ([
                OtaState.download,
                OtaState.upload,
                OtaState.rebooting,
              ].contains(otaState)) ...[
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
                          return LinearProgressIndicator(
                            value: otaState == OtaState.rebooting
                                ? null
                                : widget.otaUpdater.progress,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (HiveProxy.getOrDefault(
                  settings,
                  showDebugging,
                  defaultValue: showDebuggingDefault,
                )) ...[
                  Expanded(
                    child: ListTile(
                      trailing: const Icon(Icons.bug_report),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload Progress: ${widget.otaUpdater.currentFirmwareUploadPosition} / ${widget.otaUpdater.firmwareFile?.length} = ${widget.otaUpdater.uploadProgress.toStringAsPrecision(3)}',
                          ),
                          Text('MTU: ${widget.device.mtu.value}'),
                          Text('OtaState: ${otaState.name}'),
                          Text(
                            'DeviceState: ${widget.device.deviceState.value}',
                          ),
                          Text(
                            'ConnectivityState: ${widget.device.deviceConnectionState.value}',
                          ),
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
