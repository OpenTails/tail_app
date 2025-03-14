import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tail_app/Backend/version.dart';

import '../Frontend/utils.dart';
import '../constants.dart';
import '../gen/assets.gen.dart';
import 'logging_wrappers.dart';

part 'dynamic_config.freezed.dart';
part 'dynamic_config.g.dart';

final _dynamicConfigLogger = Logger('DynamicConfig');

@freezed
abstract class DynamicConfigInfo with _$DynamicConfigInfo {
  factory DynamicConfigInfo({
    @Default(AppVersion()) AppVersion appVersion,
    @Default(SentryConfig()) SentryConfig sentryConfig,
  }) = _DynamicConfigInfo;

  factory DynamicConfigInfo.fromJson(Map<String, dynamic> json) => _$DynamicConfigInfoFromJson(json);
}

@freezed
abstract class AppVersion with _$AppVersion {
  const factory AppVersion({
    @Default(Version(major: 1, minor: 0, patch: 0)) Version version,
    @Default("") String changelog,
    @Default("") String url,
  }) = _AppVersion;

  factory AppVersion.fromJson(Map<String, dynamic> json) => _$AppVersionFromJson(json);
}

@freezed
abstract class SentryConfig with _$SentryConfig {
  const factory SentryConfig({
    @Default(0.5) double tracesSampleRate,
    @Default(0.5) double profilesSampleRate,
    @Default(0) double replaySessionSampleRate,
    @Default(0) double replayOnErrorSampleRate,
  }) = _SentryConfig;

  factory SentryConfig.fromJson(Map<String, dynamic> json) => _$SentryConfigFromJson(json);
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
  //getRemoteDynamicConfigInfo(); // trigger updating config file without waiting
  return dynamicConfigInfo;
}

Future<void> getRemoteDynamicConfigInfo() async {
  Dio dio = await initDio();
  try {
    _dynamicConfigLogger.info("Downloading latest config file");
    Response<String> response = await dio.get('https://raw.githubusercontent.com/OpenTails/tail_app/master/assets/dynamic_config.json', options: Options(contentType: ContentType.json.mimeType, responseType: ResponseType.json));
    if (response.statusCode! < 400) {
      String jsonData = response.data!;
      // ignore: unused_local_variable
      DynamicConfigInfo dynamicConfigInfo = DynamicConfigInfo.fromJson(const JsonDecoder().convert(jsonData)); //Throws if config invalid
      HiveProxy.put(settings, dynamicConfigJsonString, jsonData); //store it for next app launch

      String buildNumber = (await PackageInfo.fromPlatform()).buildNumber;
      HiveProxy.put(settings, dynamicConfigStoredBuildNumber, buildNumber);
    }
  } catch (e, s) {
    _dynamicConfigLogger.severe("Failed to update dynamic config file: $e", e, s);
  }
}
