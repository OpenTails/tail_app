import 'dart:core';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tail_app/Backend/dynamic_config.dart';

import '../utilities/version.dart';
import 'device_type_enum.dart';

part 'device_definition.freezed.dart';

/// When adding new gear make sure to update `getNameFromBTName()`

@freezed
abstract class DeviceDefinition with _$DeviceDefinition {
  const DeviceDefinition._();

  const factory DeviceDefinition({
    required String uuid,
    required String btName,
    required DeviceType deviceType,
    Version? minVersion,
    @Default(false) bool unsupported,
  }) = _DeviceDefinition;

  Future<String> getFwURL() async {
    DynamicConfigInfo dynamicConfigInfo = await getDynamicConfigInfo();
    return dynamicConfigInfo.updateURLs[btName] ?? "";
  }
}

// data that represents the current state of a device
//TODO: Split firmware & battery into subclasses for organization
