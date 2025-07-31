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

// All Values MUST have a default value to avoid backwards compatability issues

@freezed
abstract class DynamicConfigInfo with _$DynamicConfigInfo {
  factory DynamicConfigInfo({
    @Default(AppVersion()) AppVersion appVersion,
    @Default(SentryConfig()) SentryConfig sentryConfig,
    @Default(FeatureFlags()) FeatureFlags featureFlags,
    @Default({
      "MiTail": "https://thetailcompany.com/fw/mitail.json",
      "minitail": "https://thetailcompany.com/fw/mini.json",
      "EG2": "https://thetailcompany.com/fw/eg",
      "flutter": "https://thetailcompany.com/fw/flutter"
    })
    Map<String, String> updateURLs,
    @Default(URLs()) URLs urls,
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

// Should not override user settings
@freezed
abstract class FeatureFlags with _$FeatureFlags {
  const factory FeatureFlags({
    @Default(true) bool enableAnalytics,
    // Tracking which actions are sent to gear
    @Default(true) bool enableActionAnalytics,
    @Default(true) bool enableErrorReporting,
    @Default(true) bool enableCoshubPosts,
    @Default(true) bool enableTailBlogPosts,
    @Default(30) int analyticsTickDurationSeconds,
  }) = _FeatureFlags;

  factory FeatureFlags.fromJson(Map<String, dynamic> json) => _$FeatureFlagsFromJson(json);
}

// Should not override user settings
@freezed
abstract class URLs with _$URLs {
  const factory URLs({
    @Default("https://onelink.to/coshub") String coshubUrl,
    @Default("https://raw.githubusercontent.com/OpenTails/tail_app/master/assets/dynamic_config.json") String dynamicConfigFileUrl,
  }) = _URLs;

  factory URLs.fromJson(Map<String, dynamic> json) => _$URLsFromJson(json);
}

DynamicConfigInfo? _dynamicConfigInfo;

Future<DynamicConfigInfo> getDynamicConfigInfo() async {
  if (_dynamicConfigInfo != null) {
    return _dynamicConfigInfo!;
  }
  _dynamicConfigLogger.info("Loading dynamic config");

  // Check if the stored dynamic config file is from an old app version and delete it.
  String buildNumber = (await PackageInfo.fromPlatform()).buildNumber;
  String storedBuildNumber = HiveProxy.getOrDefault(settings, dynamicConfigStoredBuildNumber, defaultValue: '');
  if (storedBuildNumber != buildNumber) {
    HiveProxy.deleteKey(settings, dynamicConfigJsonString);
  }

  // Load the stored or bundled dynamic config file
  String dynamicConfigJsonDefault = await rootBundle.loadString(Assets.dynamicConfig);
  String dynamicConfigJson = HiveProxy.getOrDefault(settings, dynamicConfigJsonString, defaultValue: dynamicConfigJsonDefault);
  String embeddedDynamicConfig = dynamicConfigJson;
  DynamicConfigInfo dynamicConfigInfo = DynamicConfigInfo.fromJson(const JsonDecoder().convert(embeddedDynamicConfig));
  _dynamicConfigInfo = dynamicConfigInfo;

  _getRemoteDynamicConfigInfo(); // trigger updating config file without waiting

  return dynamicConfigInfo;
}

Future<void> _getRemoteDynamicConfigInfo() async {
  Dio dio = await initDio();
  try {
    _dynamicConfigLogger.info("Downloading latest config file");
    // TODO: move to own domain
    Response<String> response = await dio.get(_dynamicConfigInfo!.urls.dynamicConfigFileUrl,
        options: Options(contentType: ContentType.json.mimeType, responseType: ResponseType.json));
    if (response.statusCode! < 400) {
      String jsonData = response.data!;
      // ignore: unused_local_variable
      DynamicConfigInfo dynamicConfigInfo = DynamicConfigInfo.fromJson(const JsonDecoder().convert(jsonData)); //Throws if config invalid
      HiveProxy.put(settings, dynamicConfigJsonString, jsonData); //store it for next app launch
      _dynamicConfigInfo = dynamicConfigInfo;

      // Used to invalidate old config files on app update
      String buildNumber = (await PackageInfo.fromPlatform()).buildNumber;
      HiveProxy.put(settings, dynamicConfigStoredBuildNumber, buildNumber);
    }
  } catch (e, s) {
    _dynamicConfigLogger.severe("Failed to update dynamic config file: $e", e, s);
  }
}
