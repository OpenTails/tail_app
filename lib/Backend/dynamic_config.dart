import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../Frontend/utils.dart';
import '../constants.dart';
import '../gen/assets.gen.dart';
import 'logging_wrappers.dart';

part 'dynamic_config.freezed.dart';
part 'dynamic_config.g.dart';

final _dynamicConfigLogger = Logger('DynamicConfig');

@freezed
class DynamicConfigInfo with _$DynamicConfigInfo {
  factory DynamicConfigInfo({
    @Default(0.5) double sentryTraces,
    @Default(0.5) double sentryProfiles,
  }) = _DynamicConfigInfo;

  factory DynamicConfigInfo.fromJson(Map<String, dynamic> json) => _$DynamicConfigInfoFromJson(json);
}

DynamicConfigInfo? _dynamicConfigInfo;

Future<DynamicConfigInfo> getDynamicConfigInfo() async {
  if (_dynamicConfigInfo != null) {
    return _dynamicConfigInfo!;
  }
  _dynamicConfigLogger.info("Loading dynamic config");

  String buildNumber = (await PackageInfo.fromPlatform()).buildNumber;
  String storedBuildNumber = HiveProxy.getOrDefault(settings, dynamicConfigStoredBuildNumber, defaultValue: '');
  if (storedBuildNumber != buildNumber) {
    HiveProxy.deleteKey(settings, dynamicConfigJsonString);
  }

  String dynamicConfigJsonDefault = await rootBundle.loadString(Assets.dynamicConfig);
  String dynamicConfigJson = HiveProxy.getOrDefault(settings, dynamicConfigJsonString, defaultValue: dynamicConfigJsonDefault);
  String embeddedDynamicConfig = dynamicConfigJson;
  DynamicConfigInfo dynamicConfigInfo = DynamicConfigInfo.fromJson(const JsonDecoder().convert(embeddedDynamicConfig));
  _dynamicConfigInfo = dynamicConfigInfo;
  getRemoteDynamicConfigInfo(); // trigger updating config file without waiting
  return dynamicConfigInfo;
}

Future<void> getRemoteDynamicConfigInfo() async {
  Dio dio = await initDio();
  try {
    _dynamicConfigLogger.info("Downloading latest config file");
    Response<String> response = await dio.get('https://raw.githubusercontent.com/OpenTails/tail_app/master/assets/dynamic_config.json', options: Options(contentType: ContentType.json.mimeType, responseType: ResponseType.json));
    if (response.statusCode! < 400) {
      String jsonData = response.data!;
      DynamicConfigInfo dynamicConfigInfo = DynamicConfigInfo.fromJson(const JsonDecoder().convert(jsonData)); //Throws if config invalid
      HiveProxy.put(settings, dynamicConfigJsonString, jsonData); //store it for next app launch

      String buildNumber = (await PackageInfo.fromPlatform()).buildNumber;
      HiveProxy.put(settings, dynamicConfigStoredBuildNumber, buildNumber);
    }
  } catch (e, s) {
    _dynamicConfigLogger.severe("Failed to update dynamic config file: $e", e, s);
  }
}
