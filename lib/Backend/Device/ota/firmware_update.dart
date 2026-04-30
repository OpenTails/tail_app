import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tail_app/Backend/Device/ota/update_info.dart';

import '../../../Frontend/utils.dart';
import '../../utilities/version.dart';
import '../stateful/connected_gear.dart';

Future<List<FWInfo>?> _getBaseFirmwareInfo(String url) async {
  Dio dio = await initDio();
  Future<Response<String>>
  valueFuture = dio.get(url, options: Options(responseType: ResponseType.json))
    ..onError((error, stackTrace) {
      //bluetoothLog.warning("Unable to get Firmware info for ${url} :$error", error, stackTrace);
      return Response(requestOptions: RequestOptions(), statusCode: 500);
    });
  Response<String> value = await valueFuture;
  List<FWInfo> results = [];
  if (value.statusCode! < 400) {
    results = (const JsonDecoder().convert(value.data.toString()) as List).map((
      e,
    ) {
      return FWInfo.fromJson(e);
    }).toList();
  }
  return results;
}

Future<FWInfo?> getFirmwareInfo(String url, String hwVer) async {
  if (url.isEmpty || hwVer.isEmpty) {
    return null;
  }
  final fwInfos = await _getBaseFirmwareInfo(url);
  if (fwInfos == null) {
    return null;
  }
  if (fwInfos.isNotEmpty) {
    // Find a FW file that matches the gear hardware version
    FWInfo? fwInfo = fwInfos.firstWhereOrNull(
      (element) =>
          element.supportedHardwareVersions.firstWhereOrNull(
            (element) =>
                element.trim().toUpperCase() == hwVer.trim().toUpperCase(),
          ) !=
          null,
    );
    // Fall back to a generic file if it exists
    fwInfo ??= fwInfos.firstWhereOrNull(
      (element) => element.supportedHardwareVersions.isEmpty,
    );
    if (fwInfo != null) {
      //check that the app supports this firmware version
      Version minimumAppVersion = Version.getFromSemVer(
        fwInfo.minimumAppVersion,
      );
      Version appVersion = Version.getFromSemVer(
        (await PackageInfo.fromPlatform()).version,
      );
      if (appVersion.compareTo(minimumAppVersion) >= 0) {
        return fwInfo;
      }
    }
  }
  return null;
}

Future<FWInfo?> checkForFWUpdate(StatefulDevice statefulDevice) async {
  // check if FW was already downloaded
  if (statefulDevice.firmwareStatus.remoteFirmwareInfo != null) {
    return statefulDevice.firmwareStatus.remoteFirmwareInfo;
  }
  String url = await statefulDevice.deviceDefinition.getFwURL();
  if (url.isEmpty) {
    return null;
  }
  String hwVer = statefulDevice.firmwareStatus.hardwareVersion;
  if (hwVer.isEmpty) {
    throw Exception("Hardware Version from gear is unknown");
  }
  FWInfo? fwInfo = await getFirmwareInfo(url, hwVer);
  statefulDevice.firmwareStatus.remoteFirmwareInfo = fwInfo;
  return fwInfo;
}

Future<bool> hasOtaUpdate(StatefulDevice statefulDevice) async {
  FWInfo? fwInfo = await checkForFWUpdate(statefulDevice);
  Version fwVersion = statefulDevice.firmwareStatus.firmwareVersion;

  // Check if fw version is not set (0.0.0)
  if (statefulDevice.firmwareStatus.firmwareVersion == const Version()) {
    throw Exception("Version from gear is unknown");
  }
  // check if firmware info from firmware is set and is greater than (0.0.0)
  if (fwInfo == null || fwVersion.compareTo(const Version()) <= 0) {
    throw Exception("Version from gear or server is unavailable");
  }

  // Check that the firmware from the server is greater than the firmware on device
  // changed to only compare if they are the same at MT's request. allows rolling back
  if (fwVersion != Version.getFromSemVer(fwInfo.version)) {
    statefulDevice.firmwareStatus.hasUpdate = true;
    // handle if the update is mandatory for app functionality
    if (statefulDevice.deviceDefinition.minVersion != null) {
      if (fwVersion.compareTo(statefulDevice.deviceDefinition.minVersion!) <
          0) {
        statefulDevice.firmwareStatus.mandatoryOtaRequired = true;
      }
    }
    return true;
  }
  return false;
}
