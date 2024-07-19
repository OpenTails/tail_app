import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../Frontend/utils.dart';
import 'Definitions/Device/device_definition.dart';
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

  if (baseStatefulDevice.fwVersion.value == const Version()) {
    return false;
  }
  if (fwInfo != null && fwVersion.compareTo(const Version()) > 0 && fwVersion.compareTo(getVersionSemVer(fwInfo.version)) < 0) {
    baseStatefulDevice.hasUpdate.value = false;
    return true;
  }
  return false;
}
