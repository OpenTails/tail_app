import 'dart:convert';

import 'package:animate_do/animate_do.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../Backend/firmware_update.dart';
import '../../constants.dart';
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
}

class _OtaUpdateState extends ConsumerState<OtaUpdate> {
  double downloadProgress = 0;
  double uploadProgress = 0;
  FWInfo? updateURL;
  Dio dio = Dio();
  List<int>? firmwareFile;
  OtaState otaState = OtaState.standby;
  String? downloadedMD5;
  bool wakelockEnabledBeforehand = false;

  @override
  void initState() {
    super.initState();
    updateURL ??= ref.read(knownDevicesProvider)[widget.device]?.fwInfo.value;
    downloadFirmware();
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
                      Text("MD5: ${updateURL?.md5sum}"),
                      Text("DL MD5: $downloadedMD5"),
                      Text("URL: ${updateURL?.url}"),
                      Text("AVAILABLE VERSION: ${updateURL?.version}"),
                      Text("CURRENT VERSION: ${ref.read(knownDevicesProvider)[widget.device]?.fwVersion.value}"),
                      Text("STATE: $otaState"),
                    ],
                  ),
                ),
              ],
              ListTile(
                title: Text(otaChangelogLabel()),
                subtitle: Text(updateURL?.changelog ?? "Unavailable"),
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
                            onPressed: (updateURL != null || firmwareFile != null) && ref.read(knownDevicesProvider)[widget.device]!.batteryLevel.value > 50 ? () => beginUpdate() : null,
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
                  asset: 'assets/tailcostickers/tgs/TailCoStickers_file_144834339.tgs',
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
                  asset: 'assets/tailcostickers/tgs/TailCoStickers_file_144834348.tgs',
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
                      asset: 'assets/tailcostickers/tgs/TailCoStickers_file_144834340.tgs',
                      renderCache: false,
                      width: MediaQuery.of(context).size.width,
                    ),
                  ),
                ),
                ListTile(
                  subtitle: LinearProgressIndicator(value: (downloadProgress + uploadProgress) / 2),
                ),
              ]
            ],
          ),
          duration: animationTransitionDuration,
          crossFadeState: [OtaState.error, OtaState.completed, OtaState.upload, OtaState.download].contains(otaState) ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        ),
      ),
    );
  }

  Future<void> beginUpdate() async {
    WakelockPlus.enable();
    if (firmwareFile == null) {
      await downloadFirmware();
    }
    if (otaState != OtaState.error) {
      await uploadFirmware();
    }
  }

  Future<void> downloadFirmware() async {
    if (updateURL == null) {
      return;
    }
    setState(() {
      otaState = OtaState.download;
      downloadProgress = 0;
    });
    final transaction = Sentry.startTransaction('OTA Download', 'http');
    try {
      final Response<List<int>> rs = await initDio().get<List<int>>(updateURL!.url, options: Options(responseType: ResponseType.bytes), onReceiveProgress: (current, total) {
        setState(() {
          downloadProgress = current / total;
        });
      });
      if (rs.statusCode == 200) {
        downloadProgress = 1;
        Digest digest = md5.convert(rs.data!);
        downloadedMD5 = digest.toString();
        if (digest.toString() == updateURL!.md5sum) {
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
    BaseStatefulDevice? baseStatefulDevice = ref.read(knownDevicesProvider)[widget.device];
    if (firmwareFile != null && baseStatefulDevice != null) {
      baseStatefulDevice.gearReturnedError.value = false;
      int mtu = baseStatefulDevice.mtu.value - 15;
      int total = firmwareFile!.length;
      int current = 0;
      baseStatefulDevice.gearReturnedError.value = false;
      List<int> beginOTA = List.from(const Utf8Encoder().convert("OTA ${firmwareFile!.length} $downloadedMD5"));
      await sendMessage(baseStatefulDevice, beginOTA);
      while (uploadProgress < 1 || otaState == OtaState.error) {
        if (baseStatefulDevice.gearReturnedError.value) {
          setState(() {
            otaState = OtaState.error;
          });
          break;
        }
        baseStatefulDevice.deviceState.value = DeviceState.busy; // hold the command queue

        List<int> chunk = firmwareFile!.skip(current).take(mtu).toList();
        if (chunk.isNotEmpty) {
          await sendMessage(baseStatefulDevice, chunk, withoutResponse: false, allowLongWrite: true);
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
      baseStatefulDevice.deviceState.value = DeviceState.standby; // hold the command queue
    }
  }
}
