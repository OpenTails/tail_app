import 'dart:convert';

import 'package:animate_do/animate_do.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../Backend/firmware_update.dart';
import '../../constants.dart';
import '../../gen/assets.gen.dart';
import '../../main.dart';
import '../Widgets/lottie_lazy_load.dart';
import '../intn_defs.dart';
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
  final _otaLogger = Logger('otaLogger');

  @override
  void initState() {
    super.initState();
    baseStatefulDevice = ref.read(knownDevicesProvider)[widget.device];
    firmwareInfo ??= baseStatefulDevice?.fwInfo.value;
    WakelockPlus.enabled.then((value) => wakelockEnabledBeforehand = value);
  }

  @override
  void dispose() {
    super.dispose();
    if (!wakelockEnabledBeforehand) {
      WakelockPlus.disable();
    }
    if ([OtaState.download, OtaState.upload].contains(otaState)) {
      otaState == OtaState.error;
    }
    baseStatefulDevice?.deviceState.value = DeviceState.standby;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(otaTitle())),
      body: Center(
        child: AnimatedCrossFade(
          layoutBuilder: (topChild, topChildKey, bottomChild, bottomChildKey) => Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                key: bottomChildKey,
                child: bottomChild,
              ),
              Positioned(
                key: topChildKey,
                child: topChild,
              ),
            ],
          ),
          firstChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (SentryHive.box(settings).get(showDebugging, defaultValue: showDebuggingDefault)) ...[
                ListTile(
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
              ],
              ListTile(
                title: Text(otaChangelogLabel()),
                subtitle: Text(firmwareInfo?.changelog ?? "Unavailable"),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ButtonBar(
                        alignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: (firmwareInfo != null || firmwareFile != null) ? () => beginUpdate() : null,
                            child: Text(
                              otaDownloadButtonLabel(),
                            ),
                          ),
                          if (SentryHive.box(settings).get(showDebugging, defaultValue: showDebuggingDefault)) ...[
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
                            )
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
          secondChild: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (otaState == OtaState.completed) ...[
                ListTile(
                  title: Text(
                    otaCompletedTitle(),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                LottieLazyLoad(
                  asset: Assets.tailcostickers.tgs.tailCoStickersFile144834339,
                  renderCache: true,
                  width: MediaQuery.of(context).size.width,
                ),
              ],
              if (otaState == OtaState.error) ...[
                ListTile(
                  title: Text(
                    otaFailedTitle(),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                LottieLazyLoad(
                  asset: Assets.tailcostickers.tgs.tailCoStickersFile144834348,
                  renderCache: true,
                  width: MediaQuery.of(context).size.width,
                ),
              ],
              if (otaState == OtaState.lowBattery) ...[
                ListTile(
                  title: Text(
                    otaLowBattery(),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                LottieLazyLoad(
                  asset: Assets.tailcostickers.tgs.tailCoStickersFile144834342,
                  renderCache: true,
                  width: MediaQuery.of(context).size.width,
                ),
              ],
              if ([OtaState.download, OtaState.upload].contains(otaState)) ...[
                ListTile(
                  title: Text(
                    otaInProgressTitle(),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                Spin(
                  infinite: true,
                  duration: const Duration(seconds: 1, milliseconds: 500),
                  child: Transform.flip(
                    flipX: true,
                    child: LottieLazyLoad(
                      asset: Assets.tailcostickers.tgs.tailCoStickersFile144834340,
                      renderCache: false,
                      width: MediaQuery.of(context).size.width,
                    ),
                  ),
                ),
                ListTile(
                  subtitle: LinearProgressIndicator(value: downloadProgress < 1 ? downloadProgress : uploadProgress),
                ),
                if (SentryHive.box(settings).get(showDebugging, defaultValue: showDebuggingDefault)) ...[
                  ListTile(
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upload Progress: $current / ${firmwareFile?.length} = ${uploadProgress.toStringAsPrecision(3)}'),
                        Text('MTU: ${baseStatefulDevice!.mtu.value}'),
                        Text('OtaState: ${otaState.name}'),
                        Text('DeviceState: ${baseStatefulDevice!.deviceState.value}'),
                        Text('ConnectivityState: ${baseStatefulDevice!.deviceConnectionState.value}'),
                      ],
                    ),
                  )
                ],
              ],
            ],
          ),
          duration: animationTransitionDuration,
          crossFadeState: [OtaState.standby, OtaState.manual].contains(otaState) ? CrossFadeState.showFirst : CrossFadeState.showSecond,
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
    final transaction = Sentry.startTransaction('OTA Download', 'http');
    try {
      final Response<List<int>> rs = await initDio().get<List<int>>(firmwareInfo!.url, options: Options(responseType: ResponseType.bytes), onReceiveProgress: (current, total) {
        setState(() {
          downloadProgress = current / total;
        });
      });
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
      transaction.throwable = e;
      transaction.status = const SpanStatus.internalError();
      otaState = OtaState.error;
    }
    transaction.finish();
  }

  Future<void> uploadFirmware() async {
    setState(() {
      otaState = OtaState.upload;
      uploadProgress = 0;
    });
    if (baseStatefulDevice == null) {
      otaState = OtaState.error;
      return;
    }
    if (firmwareFile != null && baseStatefulDevice != null) {
      baseStatefulDevice?.gearReturnedError.value = false;
      int mtu = baseStatefulDevice!.mtu.value - 10;
      int total = firmwareFile!.length;
      current = 0;
      baseStatefulDevice!.gearReturnedError.value = false;
      List<int> beginOTA = List.from(const Utf8Encoder().convert("OTA ${firmwareFile!.length} $downloadedMD5"));
      await sendMessage(baseStatefulDevice!, beginOTA);
      while (uploadProgress < 1 || otaState == OtaState.error) {
        if (baseStatefulDevice!.gearReturnedError.value) {
          setState(() {
            otaState = OtaState.error;
          });
          break;
        }
        baseStatefulDevice!.deviceState.value = DeviceState.busy; // hold the command queue

        List<int> chunk = firmwareFile!.skip(current).take(mtu).toList();
        if (chunk.isNotEmpty) {
          try {
            await sendMessage(baseStatefulDevice!, chunk, withoutResponse: true);
          } catch (e, s) {
            _otaLogger.severe("Exception during ota upload:$e", e, s);
            setState(() {
              otaState = OtaState.error;
            });
            return;
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
        //await Future.delayed(const Duration(seconds: 10));
        otaState = OtaState.completed;
        plausible.event(name: "Update Gear");
      }
      baseStatefulDevice!.deviceState.value = DeviceState.standby; // hold the command queue
    }
  }
}
