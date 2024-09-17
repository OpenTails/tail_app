import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/plausible_dio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../Frontend/utils.dart';
import '../constants.dart';
import 'Bluetooth/bluetooth_manager_plus.dart';
import 'Definitions/Device/device_definition.dart';
import 'logging_wrappers.dart';
import 'version.dart';

part 'firmware_update.freezed.dart';
part 'firmware_update.g.dart';

@freezed
class FWInfo with _$FWInfo {
  const factory FWInfo({
    required String version,
    required String md5sum,
    required String url,
    @Default("") final String changelog,
    @Default("") final String glash,
  }) = _FWInfo;

  factory FWInfo.fromJson(Map<String, dynamic> json) => _$FWInfoFromJson(json);
}

@Riverpod(keepAlive: true)
Future<FWInfo?> getFirmwareInfo(GetFirmwareInfoRef ref, String url) async {
  Dio dio = await initDio();
  Future<Response<String>> valueFuture = dio.get(url, options: Options(responseType: ResponseType.json))
    ..onError((error, stackTrace) {
      //bluetoothLog.warning("Unable to get Firmware info for ${url} :$error", error, stackTrace);
      return Response(requestOptions: RequestOptions(), statusCode: 500);
    });
  Response<String> value = await valueFuture;
  if (value.statusCode! < 400) {
    FWInfo fwInfo = FWInfo.fromJson(const JsonDecoder().convert(value.data.toString()));
    return fwInfo;
  }
  return null;
}

@Riverpod()
Future<FWInfo?> checkForFWUpdate(CheckForFWUpdateRef ref, BaseStatefulDevice baseStatefulDevice) async {
  if (baseStatefulDevice.fwInfo.value != null) {
    return baseStatefulDevice.fwInfo.value;
  }
  String url = baseStatefulDevice.baseDeviceDefinition.fwURL;
  if (url.isEmpty) {
    return null;
  }
  FWInfo? fwInfo = await ref.read(getFirmwareInfoProvider(url).future);
  baseStatefulDevice.fwInfo.value = fwInfo;
  return fwInfo;
}

@Riverpod()
Future<bool> hasOtaUpdate(HasOtaUpdateRef ref, BaseStatefulDevice baseStatefulDevice) async {
  FWInfo? fwInfo = await ref.read(checkForFWUpdateProvider(baseStatefulDevice).future);
  Version fwVersion = baseStatefulDevice.fwVersion.value;

  // Check if fw version is not set (0.0.0)
  if (baseStatefulDevice.fwVersion.value == const Version()) {
    return false;
  }
  // check if firmware info from firmware is set and is greater than (0.0.0)
  if (fwInfo == null || fwVersion.compareTo(const Version()) <= 0) {
    return false;
  }

  // Check that the firmware from the server is greater than the firmware on device
  if (fwVersion.compareTo(getVersionSemVer(fwInfo.version)) < 0) {
    baseStatefulDevice.hasUpdate.value = true;
    return true;
  }
  return false;
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

class OtaUpdater {
  Function(double)? onProgress;
  Function(OtaState)? onStateChanged;
  BaseStatefulDevice baseStatefulDevice;
  OtaState _otaState = OtaState.standby;

  OtaState get otaState => _otaState;
  double _downloadProgress = 0;

  double get downloadProgress => _downloadProgress;

  set downloadProgress(double value) {
    _downloadProgress = value;
    _progress = downloadProgress < 1 ? downloadProgress : uploadProgress;
  }

  double _uploadProgress = 0;

  double get uploadProgress => _uploadProgress;

  set uploadProgress(double value) {
    _uploadProgress = value;
    _progress = downloadProgress < 1 ? downloadProgress : uploadProgress;
  }

  double _progress = 0;

  double get progress => _progress;

  FWInfo? firmwareInfo;
  List<int>? firmwareFile;
  String? downloadedMD5;
  bool _wakelockEnabledBeforehand = false;
  int current = 0;
  Timer? _timer;
  final Logger _otaLogger = Logger('otaLogger');

  void setManualOtaFile(List<int>? bytes) {
    if (bytes == null) {
      return;
    }
    firmwareFile = bytes;
    Digest digest = md5.convert(firmwareFile!);
    downloadedMD5 = digest.toString();
    otaState = OtaState.manual;
    downloadProgress = 1;
  }

  double _previousProgress = 0;

  void _updateProgress() {
    if ((_previousProgress - _progress).abs() < 0.1) {
      return;
    }
    if (onProgress != null) {
      onProgress!(_progress);
      _previousProgress = _progress;
    }
  }

  set otaState(OtaState value) {
    _otaState = value;
    if (onStateChanged != null) {
      onStateChanged!(value);
    }
  }

  Future<void> beginUpdate() async {
    if (baseStatefulDevice.batteryLevel.value < 50) {
      otaState = OtaState.lowBattery;
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
    otaState = OtaState.download;
    downloadProgress = 0;
    _updateProgress();
    try {
      final Response<List<int>> rs = await (await initDio()).get<List<int>>(
        firmwareInfo!.url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (current, total) {
          downloadProgress = current / total;
          _updateProgress();
        },
      );
      if (rs.statusCode == 200) {
        downloadProgress = 1;
        Digest digest = md5.convert(rs.data!);
        downloadedMD5 = digest.toString();
        if (digest.toString() == firmwareInfo!.md5sum) {
          firmwareFile = rs.data;
        } else {
          otaState = OtaState.error;
        }
      }
    } catch (e) {
      otaState = OtaState.error;
    }
  }

  Future<void> verListener() async {
    Version version = baseStatefulDevice.fwVersion.value;
    FWInfo? fwInfo = firmwareInfo;
    if (fwInfo != null && version.compareTo(const Version()) > 0 && otaState == OtaState.rebooting) {
      bool updated = version.compareTo(getVersionSemVer(fwInfo.version)) >= 0;
      otaState = updated ? OtaState.completed : OtaState.error;
    }
  }

  void fwInfoListener() {
    firmwareInfo = baseStatefulDevice.fwInfo.value;
  }

  Future<void> uploadFirmware() async {
    otaState = OtaState.upload;
    uploadProgress = 0;
    if (firmwareFile != null) {
      int mtu = baseStatefulDevice.mtu.value - 10;
      current = 0;
      baseStatefulDevice.gearReturnedError.value = false;

      _otaLogger.info("Holding the command queue");
      _otaLogger.info("Send OTA begin message");
      List<int> beginOTA = List.from(const Utf8Encoder().convert("OTA ${firmwareFile!.length} $downloadedMD5"));
      await sendMessage(baseStatefulDevice, beginOTA);

      while (uploadProgress < 1 && otaState != OtaState.error) {
        baseStatefulDevice.deviceState.value = DeviceState.busy; // hold the command queue
        if (baseStatefulDevice.gearReturnedError.value) {
          otaState = OtaState.error;
          break;
        }

        List<int> chunk = firmwareFile!.skip(current).take(mtu).toList();
        if (chunk.isNotEmpty) {
          try {
            await sendMessage(baseStatefulDevice, chunk, withoutResponse: true);
          } catch (e, s) {
            _otaLogger.severe("Exception during ota upload:$e", e, s);
            if ((current + chunk.length) / firmwareFile!.length < 0.99) {
              otaState = OtaState.error;
              return;
            }
          }
          current = current + chunk.length;
        } else {
          current = firmwareFile!.length;
        }

        uploadProgress = current / firmwareFile!.length;
        _updateProgress();
      }
      if (uploadProgress == 1) {
        _otaLogger.info("File Uploaded");
        otaState = OtaState.rebooting;
        beginScan(
          scanReason: ScanReason.manual,
          timeout: const Duration(seconds: 60),
        ); // start scanning for the gear to reconnect
        _timer = Timer(
          const Duration(seconds: 60),
          () {
            if (otaState != OtaState.completed) {
              _otaLogger.warning("Gear did not return correct version after reboot");
              otaState = OtaState.error;
            }
          },
        );
        plausible.event(name: "Update Gear");
      }
      baseStatefulDevice.deviceState.value = DeviceState.standby; // release the command queue
    }
  }

  OtaUpdater({this.onProgress, this.onStateChanged, required this.baseStatefulDevice}) {
    firmwareInfo ??= baseStatefulDevice.fwInfo.value;
    WakelockPlus.enabled.then((value) => _wakelockEnabledBeforehand = value);
    baseStatefulDevice.fwVersion.addListener(verListener);
    baseStatefulDevice.fwInfo.addListener(fwInfoListener);
  }

  void dispose() {
    _timer?.cancel();
    if (!_wakelockEnabledBeforehand) {
      unawaited(WakelockPlus.disable());
    }
    if (!HiveProxy.getOrDefault(settings, alwaysScanning, defaultValue: alwaysScanningDefault)) {
      unawaited(stopScan());
    }
  }
}

@pragma('vm:entry-point')
Future<void> updaterIsolate({required String macAddress, required String service, required String txCharacteristic, required List<int> firmwareFile, required String md5Hash, required SendPort port}) async {
  BluetoothDevice? bluetoothDevice = FlutterBluePlus.connectedDevices.where((element) => element.remoteId.str == macAddress).firstOrNull;
  if (bluetoothDevice == null) {
    return;
  }
  BluetoothCharacteristic? bluetoothCharacteristic = bluetoothDevice.servicesList.firstWhereOrNull((element) => element.uuid == Guid(service))?.characteristics.firstWhereOrNull((element) => element.characteristicUuid == Guid(txCharacteristic));
  if (bluetoothCharacteristic == null) {
    return;
  }
  List<int> beginOTA = List.from(const Utf8Encoder().convert("OTA ${firmwareFile.length} $md5Hash"));
  await bluetoothCharacteristic.write(beginOTA);
  int current = 0;
  double uploadProgress = 0;

  List<int> chunk = firmwareFile.skip(current).take(bluetoothDevice.mtuNow).toList();
  if (chunk.isNotEmpty) {
    try {
      await bluetoothCharacteristic.write(chunk);
    } catch (e, s) {
      if ((current + chunk.length) / firmwareFile.length < 0.99) {
        port.send("Error");
        return;
      }
    }
    current = current + chunk.length;
  } else {
    current = firmwareFile.length;
  }
  uploadProgress = current / firmwareFile.length;
  port.send(uploadProgress);
}
