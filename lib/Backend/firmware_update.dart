import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../Frontend/utils.dart';
import 'Bluetooth/bluetooth_manager_plus.dart';
import 'Definitions/Device/device_definition.dart';
import 'version.dart';

part 'firmware_update.freezed.dart';
part 'firmware_update.g.dart';

@freezed
abstract class FWInfo with _$FWInfo {
  const factory FWInfo({
    required String version,
    required String md5sum,
    required String url,
    required List<String> supportedHardwareVersions,
    required String minimumAppVersion,
    @Default("") final String changelog,
    @Default("") final String glash,
  }) = _FWInfo;

  factory FWInfo.fromJson(Map<String, dynamic> json) => _$FWInfoFromJson(json);
}

@Riverpod(keepAlive: true)
Future<List<FWInfo>?> getBaseFirmwareInfo(Ref ref, String url) async {
  Dio dio = await initDio();
  Future<Response<String>> valueFuture = dio.get(url, options: Options(responseType: ResponseType.json))
    ..onError((error, stackTrace) {
      //bluetoothLog.warning("Unable to get Firmware info for ${url} :$error", error, stackTrace);
      return Response(requestOptions: RequestOptions(), statusCode: 500);
    });
  Response<String> value = await valueFuture;
  List<FWInfo> results = [];
  if (value.statusCode! < 400) {
    results = (const JsonDecoder().convert(value.data.toString()) as List).map((e) {
      return FWInfo.fromJson(e);
    }).toList();
  }
  return results;
}

@Riverpod(keepAlive: true)
Future<FWInfo?> getFirmwareInfo(Ref ref, String url, String hwVer) async {
  if (url.isEmpty || hwVer.isEmpty) {
    return null;
  }

  // https://github.com/rrousselGit/riverpod/issues/3745
  // using ref.read(provider.future) causes an infinite await on riverpod 3.0
  
  final fwInfosListener = ref.listen(getBaseFirmwareInfoProvider(url).future, (p, n) {});
  List<FWInfo>? fwInfos;
  try {
     fwInfos = await fwInfosListener.read();
  } finally {
    fwInfosListener.close();
  }

  if (fwInfos == null) {
    return null;
  }
  if (fwInfos.isNotEmpty) {
    // Find a FW file that matches the gear hardware version
    FWInfo? fwInfo = fwInfos.firstWhereOrNull((element) => element.supportedHardwareVersions.firstWhereOrNull((element) => element.trim().toUpperCase() == hwVer.trim().toUpperCase()) != null);
    // Fall back to a generic file if it exists
    fwInfo ??= fwInfos.firstWhereOrNull((element) => element.supportedHardwareVersions.isEmpty);
    if (fwInfo != null) {
      //check that the app supports this firmware version
      Version minimumAppVersion = getVersionSemVer(fwInfo.minimumAppVersion);
      Version appVersion = getVersionSemVer((await PackageInfo.fromPlatform()).version);
      if (appVersion.compareTo(minimumAppVersion) >= 0) {
        return fwInfo;
      }
    }
  }
  return null;
}

@Riverpod()
Future<FWInfo?> checkForFWUpdate(Ref ref, BaseStatefulDevice baseStatefulDevice) async {
  if (baseStatefulDevice.fwInfo.value != null) {
    return baseStatefulDevice.fwInfo.value;
  }
  String url = await baseStatefulDevice.baseDeviceDefinition.getFwURL();
  if (url.isEmpty) {
    return null;
  }
  String hwVer = baseStatefulDevice.hwVersion.value;
  if (hwVer.isEmpty) {
    throw Exception("Hardware Version from gear is unknown");
  }
  FWInfo? fwInfo = await ref.read(getFirmwareInfoProvider(url, hwVer).future);
  baseStatefulDevice.fwInfo.value = fwInfo;
  return fwInfo;
}

@Riverpod()
Future<bool> hasOtaUpdate(Ref ref, BaseStatefulDevice baseStatefulDevice) async {
  FWInfo? fwInfo = await ref.read(checkForFWUpdateProvider(baseStatefulDevice).future);
  Version fwVersion = baseStatefulDevice.fwVersion.value;

  // Check if fw version is not set (0.0.0)
  if (baseStatefulDevice.fwVersion.value == const Version()) {
    throw Exception("Version from gear is unknown");
  }
  // check if firmware info from firmware is set and is greater than (0.0.0)
  if (fwInfo == null || fwVersion.compareTo(const Version()) <= 0) {
    throw Exception("Version from gear or server is unavailable");
  }

  // Check that the firmware from the server is greater than the firmware on device
  // changed to only compare if they are the same at MT's request. allows rolling back
  if (fwVersion != getVersionSemVer(fwInfo.version)) {
    baseStatefulDevice.hasUpdate.value = true;
    // handle if the update is mandatory for app functionality
    if (baseStatefulDevice.baseDeviceDefinition.minVersion != null) {
      if (fwVersion.compareTo(baseStatefulDevice.baseDeviceDefinition.minVersion!) < 0) {
        baseStatefulDevice.mandatoryOtaRequired.value = true;
      }
    }
    return true;
  }
  return false;
}

enum OtaState { standby, download, upload, error, manual, completed, lowBattery, rebooting }

enum OtaError { md5Mismatch, downloadFailed, gearVersionMismatch, gearReturnedError, uploadFailed, gearReconnectTimeout, gearDisconnectTimeout, gearOtaFinalTimeout }

@Riverpod()
class OtaUpdater extends _$OtaUpdater {
  Function(OtaError)? onError;

  @override
  OtaState build(BaseStatefulDevice baseStatefulDevice) {
    firmwareInfo ??= baseStatefulDevice.fwInfo.value;
    WakelockPlus.enabled.then((value) => _wakelockEnabledBeforehand = value);
    baseStatefulDevice.fwVersion.addListener(_verListener);
    baseStatefulDevice.fwInfo.addListener(_fwInfoListener);
    baseStatefulDevice.deviceConnectionState.addListener(_connectivityStateListener);
    return OtaState.standby;
  }

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
  int currentFirmwareUploadPosition = 0;
  Timer? _disconnectTimer;
  Timer? _reconnectTimer;
  Timer? _finalTimer;
  final Logger _otaLogger = Logger('otaLogger');
  ISentrySpan? transaction;

  void setManualOtaFile(List<int>? bytes) {
    if (bytes == null) {
      return;
    }
    firmwareFile = bytes;
    Digest digest = md5.convert(firmwareFile!);
    downloadedMD5 = digest.toString();
    state = OtaState.manual;
    downloadProgress = 1;
  }

  void _onError(OtaError error, ISentrySpan? span) {
    state = OtaState.error;
    span?.status = SpanStatus.fromString(error.name);
    if (onError != null) {
      onError!(error);
    }
    _cancelTimers();
  }

  double _previousProgress = 0;

  void _updateProgress() {
    //control how fast to update progress
    if ((_previousProgress - _progress).abs() < 0.01) {
      return;
    }
    ref.notifyListeners();
    _previousProgress = _progress;
  }

  void abort() {
    state = OtaState.error;
  }

  Future<void> beginUpdate() async {
    transaction = Sentry.startTransaction('beginUpdate()', 'task');
    transaction?.setData("Gear Model", baseStatefulDevice.baseDeviceDefinition.btName);
    transaction?.setData("Current FW Version", baseStatefulDevice.fwVersion.value.toString());
    transaction?.setData("Hardware Version", baseStatefulDevice.hwVersion.value);
    transaction?.setData("Target Firmware Version", baseStatefulDevice.fwInfo.value?.version);

    if (baseStatefulDevice.batteryLevel.value < 50) {
      state = OtaState.lowBattery;
      transaction?.status = SpanStatus.fromString("lowBattery");
      transaction?.finish();
      return;
    }
    WakelockPlus.enable();
    if (firmwareFile == null) {
      await _downloadFirmware();
    }
    if (state != OtaState.error) {
      await _uploadFirmware();
    }
  }

  Future<void> _downloadFirmware() async {
    if (firmwareInfo == null) {
      return;
    }
    final ISentrySpan? downloadSpan = transaction?.startChild('downloadFirmware()', description: 'operation');
    state = OtaState.download;
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
          _onError(OtaError.md5Mismatch, downloadSpan);
        }
      }
    } catch (e) {
      downloadSpan?.throwable = e;
      _onError(OtaError.downloadFailed, downloadSpan);
    }
    downloadSpan?.finish();
  }

  Future<void> _verListener() async {
    Version version = baseStatefulDevice.fwVersion.value;
    FWInfo? fwInfo = firmwareInfo;
    if (fwInfo != null && version.compareTo(const Version()) > 0 && state == OtaState.rebooting) {
      bool updated = version.compareTo(getVersionSemVer(fwInfo.version)) >= 0;
      if (!updated) {
        _onError(OtaError.gearVersionMismatch, transaction);
      } else {
        state = OtaState.completed;
      }
      if (transaction != null && !transaction!.finished) {
        transaction?.finish();
      }
    }
  }

  void _fwInfoListener() {
    firmwareInfo = baseStatefulDevice.fwInfo.value;
  }

  void _connectivityStateListener() {
    ConnectivityState connectivityState = baseStatefulDevice.deviceConnectionState.value;
    if (OtaState.rebooting == state) {
      if (connectivityState == ConnectivityState.disconnected) {
        _disconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 30), () {
          _otaLogger.warning("Gear did not reconnect");
          _onError(OtaError.gearReconnectTimeout, transaction);
          transaction?.finish();
        });
      } else if (connectivityState == ConnectivityState.connected) {
        _reconnectTimer?.cancel();
      }
    }
  }

  Future<void> _uploadFirmware() async {
    final ISentrySpan? uploadSpan = transaction?.startChild('uploadFirmware()', description: 'operation');
    state = OtaState.upload;
    uploadProgress = 0;
    if (firmwareFile != null) {
      int mtu = baseStatefulDevice.mtu.value - 10;
      currentFirmwareUploadPosition = 0;
      baseStatefulDevice.gearReturnedError.value = false;

      _otaLogger.info("Holding the command queue");
      _otaLogger.info("Send OTA begin message");
      List<int> beginOTA = List.from(const Utf8Encoder().convert("OTA ${firmwareFile!.length} $downloadedMD5"));
      await sendMessage(baseStatefulDevice, beginOTA);
      uploadSpan?.setData("Gear MTU", mtu);
      while (uploadProgress < 1 && state != OtaState.error) {
        baseStatefulDevice.deviceState.value = DeviceState.busy; // hold the command queue
        if (baseStatefulDevice.gearReturnedError.value) {
          _onError(OtaError.gearReturnedError, uploadSpan);
          break;
        }

        List<int> chunk = firmwareFile!.skip(currentFirmwareUploadPosition).take(mtu).toList();
        if (chunk.isNotEmpty) {
          try {
            await sendMessage(baseStatefulDevice, chunk, withoutResponse: true);
          } catch (e, s) {
            _otaLogger.severe("Exception during ota upload:$e", e, s);
            if ((currentFirmwareUploadPosition + chunk.length) / firmwareFile!.length < 0.99) {
              _onError(OtaError.uploadFailed, uploadSpan);
              uploadSpan?.throwable = e;
              uploadSpan?.finish();
              return;
            }
          }
          currentFirmwareUploadPosition = currentFirmwareUploadPosition + chunk.length;
        } else {
          currentFirmwareUploadPosition = firmwareFile!.length;
        }

        uploadProgress = currentFirmwareUploadPosition / firmwareFile!.length;
        _updateProgress();
      }
      if (uploadProgress == 1) {
        _otaLogger.info("File Uploaded");
        state = OtaState.rebooting;
        _disconnectTimer = Timer(const Duration(seconds: 30), () {
          _otaLogger.warning("Gear did not disconnect");
          _onError(OtaError.gearDisconnectTimeout, transaction);
          transaction?.finish();
        });
        // start scanning for the gear to reconnect
        _finalTimer = Timer(const Duration(seconds: 60), () {
          if (state != OtaState.completed) {
            _otaLogger.warning("Gear did not return correct version after reboot");
            _onError(OtaError.gearOtaFinalTimeout, transaction);
            transaction?.finish();
          }
        });
        analyticsEvent(
          name: "Update Gear",
          props: {
            "Target Gear": baseStatefulDevice.baseDeviceDefinition.btName,
            "Hardware Version": baseStatefulDevice.hwVersion.value,
            "Firmware Version": baseStatefulDevice.fwVersion.value.toString(),
          },
        );
      }
      baseStatefulDevice.deviceState.value = DeviceState.standby; // release the command queue
    }
    uploadSpan?.finish();
  }

  void dispose() {
    _cancelTimers();
    if (!_wakelockEnabledBeforehand) {
      WakelockPlus.disable();
    }
    ref.read(scanProvider.notifier).stopActiveScan();

    if (transaction != null && !transaction!.finished) {
      transaction?.finish(status: SpanStatus.aborted());
    }
  }

  void _cancelTimers() {
    _disconnectTimer?.cancel();
    _reconnectTimer?.cancel();
    _finalTimer?.cancel();
  }
}
