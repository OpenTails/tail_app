import 'dart:async';
import 'dart:convert';

import 'package:animate_do/animate_do.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:duration/duration.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/firmware_update.dart';
import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../../gen/assets.gen.dart';
import '../../main.dart';
import '../Widgets/lottie_lazy_load.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';

class OtaUpdate extends ConsumerStatefulWidget {
  const OtaUpdate({super.key, required this.device});

  final String device;

  @override
  ConsumerState<OtaUpdate> createState() => _OtaUpdateState();
}

enum OtaState {
  standby,
  download,
  upload,
  error,
  manual,
  completed,
  lowBattery,
  rebooting,
}

class _OtaUpdateState extends ConsumerState<OtaUpdate> {
  double downloadProgress = 0;
  double uploadProgress = 0;
  FWInfo? firmwareInfo;
  Dio dio = Dio();
  List<int>? firmwareFile;
  OtaState otaState = OtaState.standby;
  String? downloadedMD5;
  bool wakelockEnabledBeforehand = false;
  BaseStatefulDevice? baseStatefulDevice;
  int current = 0;
  Duration timeRemainingMS = Duration.zero;
  Timer? timer;
  final Logger _otaLogger = Logger('otaLogger');

  @override
  void initState() {
    super.initState();
    baseStatefulDevice = ref.read(knownDevicesProvider)[widget.device];
    firmwareInfo ??= baseStatefulDevice?.fwInfo.value;
    WakelockPlus.enabled.then((value) => wakelockEnabledBeforehand = value);
    baseStatefulDevice!.fwVersion.addListener(verListener);
    baseStatefulDevice!.fwInfo.addListener(fwInfoListener);
    if (firmwareInfo == null) {
      unawaited(baseStatefulDevice!.getFirmwareInfo());
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (!wakelockEnabledBeforehand) {
      unawaited(WakelockPlus.disable());
    }
    if ([OtaState.download, OtaState.upload].contains(otaState)) {
      otaState == OtaState.error;
    }
    baseStatefulDevice?.deviceState.value = DeviceState.standby;
    baseStatefulDevice!.fwVersion.removeListener(verListener);
    baseStatefulDevice!.fwInfo.removeListener(fwInfoListener);
    if (!HiveProxy.getOrDefault(settings, alwaysScanning, defaultValue: alwaysScanningDefault)) {
      unawaited(stopScan());
    }
    timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(otaTitle())),
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
                          Text("MD5: ${firmwareInfo?.md5sum}"),
                          Text("DL MD5: $downloadedMD5"),
                          Text("URL: ${baseStatefulDevice?.baseDeviceDefinition.fwURL}"),
                          Text("AVAILABLE VERSION: ${firmwareInfo?.version}"),
                          Text("CURRENT VERSION: ${baseStatefulDevice?.fwVersion.value}"),
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
                      title: Text(otaChangelogLabel()),
                      subtitle: Text(firmwareInfo?.changelog ?? "Unavailable"),
                    ),
                  ),
                ),
                Expanded(
                  child: SafeArea(
                    child: ButtonBar(
                      alignment: MainAxisAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: (firmwareInfo != null || firmwareFile != null) ? beginUpdate : null,
                          child: Row(
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
                                  firmwareFile = result.files.single.bytes?.toList(growable: false);
                                  Digest digest = md5.convert(firmwareFile!);
                                  downloadProgress = 1;
                                  downloadedMD5 = digest.toString();
                                  otaState = OtaState.manual;
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
              if (otaState == OtaState.completed) ...[
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
              if (otaState == OtaState.error) ...[
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
              if (otaState == OtaState.lowBattery) ...[
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
              if ([OtaState.download, OtaState.upload, OtaState.rebooting].contains(otaState)) ...[
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
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ListTile(
                      subtitle: Builder(
                        builder: (context) {
                          double progress = downloadProgress < 1 ? downloadProgress : uploadProgress;
                          return LinearProgressIndicator(value: otaState == OtaState.rebooting ? null : progress);
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
                          Text('Upload Progress: $current / ${firmwareFile?.length} = ${uploadProgress.toStringAsPrecision(3)}'),
                          Text('MTU: ${baseStatefulDevice!.mtu.value}'),
                          Text('REMAINING: ${printDuration(timeRemainingMS)}'),
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

  Future<void> beginUpdate() async {
    if (baseStatefulDevice!.batteryLevel.value < 50) {
      setState(() {
        otaState = OtaState.lowBattery;
      });
      return;
    }
    WakelockPlus.enable();
    if (firmwareFile == null) {
      await downloadFirmware();
    }
    if (otaState != OtaState.error) {
      await uploadFirmware();
    }
  }

  Future<void> downloadFirmware() async {
    if (firmwareInfo == null) {
      return;
    }
    setState(() {
      otaState = OtaState.download;
      downloadProgress = 0;
    });
    final transaction = Sentry.startTransaction('OTA Download', 'http')..setTag("GearType", baseStatefulDevice!.baseDeviceDefinition.btName);
    try {
      final Response<List<int>> rs = await (await initDio()).get<List<int>>(
        firmwareInfo!.url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (current, total) {
          setState(() {
            downloadProgress = current / total;
          });
        },
      );
      if (rs.statusCode == 200) {
        downloadProgress = 1;
        Digest digest = md5.convert(rs.data!);
        downloadedMD5 = digest.toString();
        if (digest.toString() == firmwareInfo!.md5sum) {
          firmwareFile = rs.data;
        } else {
          transaction.status = const SpanStatus.dataLoss();
          otaState = OtaState.error;
        }
      }
    } catch (e) {
      transaction
        ..throwable = e
        ..status = const SpanStatus.internalError();
      otaState = OtaState.error;
    }
    transaction.finish();
  }

  Future<void> verListener() async {
    Version version = baseStatefulDevice!.fwVersion.value;
    FWInfo? fwInfo = firmwareInfo;
    if (fwInfo != null && version.compareTo(Version.none) > 0 && otaState == OtaState.rebooting) {
      bool updated = version.compareTo(getVersionSemVer(fwInfo.version)) >= 0;
      if (mounted) {
        setState(() {
          otaState = updated ? OtaState.completed : OtaState.error;
        });
      }
    }
  }

  void fwInfoListener() {
    setState(() {
      firmwareInfo = baseStatefulDevice!.fwInfo.value;
    });
  }

  Future<void> uploadFirmware() async {
    setState(() {
      otaState = OtaState.upload;
      uploadProgress = 0;
      if (baseStatefulDevice == null) {
        otaState = OtaState.error;
        return;
      }
    });

    Stopwatch timeToUpdate = Stopwatch();
    final transaction = Sentry.startTransaction('updateGear()', 'task');
    try {
      if (firmwareFile != null && baseStatefulDevice != null) {
        transaction.setTag("GearType", baseStatefulDevice!.baseDeviceDefinition.btName);
        baseStatefulDevice?.gearReturnedError.value = false;
        int mtu = baseStatefulDevice!.mtu.value - 10;
        int total = firmwareFile!.length;
        current = 0;
        baseStatefulDevice!.gearReturnedError.value = false;

        _otaLogger.info("Holding the command queue");
        timeToUpdate.start();
        _otaLogger.info("Send OTA begin message");
        List<int> beginOTA = List.from(const Utf8Encoder().convert("OTA ${firmwareFile!.length} $downloadedMD5"));
        await sendMessage(baseStatefulDevice!, beginOTA);

        while (uploadProgress < 1 && otaState != OtaState.error) {
          baseStatefulDevice!.deviceState.value = DeviceState.busy; // hold the command queue
          if (baseStatefulDevice!.gearReturnedError.value) {
            transaction.status = const SpanStatus.unavailable();
            if (mounted) {
              setState(() {
                otaState = OtaState.error;
              });
            }
            break;
          }

          List<int> chunk = firmwareFile!.skip(current).take(mtu).toList();
          if (chunk.isNotEmpty) {
            try {
              //_otaLogger.info("Updating $uploadProgress");
              if (current > 0) {
                timeRemainingMS = Duration(milliseconds: ((timeToUpdate.elapsedMilliseconds / current) * (total - current)).toInt());
              }

              await sendMessage(baseStatefulDevice!, chunk, withoutResponse: true);
            } catch (e, s) {
              _otaLogger.severe("Exception during ota upload:$e", e, s);
              if ((current + chunk.length) / total < 0.99) {
                transaction
                  ..status = const SpanStatus.unknownError()
                  ..throwable = e;
                setState(() {
                  otaState = OtaState.error;
                });
                return;
              }
            }
            current = current + chunk.length;
          } else {
            current = total;
          }

          setState(() {
            uploadProgress = current / total;
          });
        }
        if (uploadProgress == 1) {
          _otaLogger.info("File Uploaded");
          otaState = OtaState.rebooting;
          beginScan(); // start scanning for the gear to reconnect
          timer = Timer(
            const Duration(seconds: 60),
            () {
              if (otaState != OtaState.completed && mounted) {
                setState(() {
                  _otaLogger.warning("Gear did not return correct version after reboot");
                  otaState = OtaState.error;
                });
              }
            },
          );
          plausible.event(name: "Update Gear");
        }
        baseStatefulDevice!.deviceState.value = DeviceState.standby; // release the command queue
      }
    } finally {
      transaction.finish();
    }
  }
}
