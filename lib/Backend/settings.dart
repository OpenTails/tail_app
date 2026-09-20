import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tail_app/Backend/Device/ear_speed_enum.dart';
import 'package:tail_app/Backend/dynamic_config.dart';

part 'settings.freezed.dart';

@unfreezed
abstract class Settings with _$Settings {
  Settings._();

  static const bool defaultKeepScreenOn = false;
  final int appColorDefault = const Color.fromARGB(
    255,
    228,
    110,
    38,
  ).toARGB32();

  factory Settings({
    @Default(defaultKeepScreenOn) bool keepScreenOn,
    @Default(000000) int appColor,
    @Default(0) bool completedOnboardingVersion,
    @Default(false) bool showDeveloperOptions,
    @Default(true) bool allowErrorReporting,
    @Default(false) bool allowAnalytics,
    @Default(false) bool hideTutorialCards,
    @Default(false) bool translateToUwU,
    @Default(GlobalGearSettings()) GlobalGearSettings globalGearSettings,
    @Default(StoredDynamicConfig()) StoredDynamicConfig storedDynamicConfig,
  }) = _Settings;
}

@unfreezed
abstract class GlobalGearSettings with _$GlobalGearSettings {
  const GlobalGearSettings._();

  static const EarSpeed defaultEarMoveSpeed = EarSpeed.fast;
  static const int defaultRgbBrightness = 100;

  const factory GlobalGearSettings({
    @Default(defaultRgbBrightness) int rgbBrightness,
    // For pre-TailControl ears
    @Default(defaultEarMoveSpeed) EarSpeed earMoveSpeed,
  }) = _GlobalGearSettings;
}

@freezed
abstract class StoredDynamicConfig with _$StoredDynamicConfig {
  const StoredDynamicConfig._();

  const factory StoredDynamicConfig({
    @Default(DynamicConfigInfo()) DynamicConfigInfo storedDynamicConfig,
    @Default(1) int storedAppBuild,
  }) = _StoredDynamicConfig;
}
