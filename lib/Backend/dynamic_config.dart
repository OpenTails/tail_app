import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tail_app/Backend/logging_wrappers.dart';
import 'package:tail_app/Frontend/utils.dart';
import 'package:tail_app/constants.dart';

import '../gen/assets.gen.dart';

part 'dynamic_config.g.dart';

final _dynamicConfigLogger = Logger('DynamicConfig');

@JsonSerializable()
class DynamicConfigInfo {
  double sentryTraces = 0.5;
  double sentryProfiles = 0.5;

  DynamicConfigInfo();

  factory DynamicConfigInfo.fromJson(Map<String, dynamic> json) => _$DynamicConfigInfoFromJson(json);

  Map<String, dynamic> toJson() => _$DynamicConfigInfoToJson(this);
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
    HiveProxy.put(settings, dynamicConfigJsonString, null);
  }

  String dynamicConfigJson = HiveProxy.getOrDefault(settings, dynamicConfigJsonString, defaultValue: await rootBundle.loadString(Assets.dynamicConfig));
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
