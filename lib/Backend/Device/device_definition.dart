import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tail_app/Backend/Device/stored_device.dart';
import 'package:tail_app/Backend/command_queue.dart';
import 'package:tail_app/Backend/dynamic_config.dart';

import '../../../constants.dart';
import '../Bluetooth/bluetooth_message.dart';
import '../Bluetooth/known_devices.dart';
import '../analytics.dart';
import '../command_history.dart';
import 'ota/firmware_update.dart';
import '../logging_wrappers.dart';
import '../version.dart';
import 'bluetooth_uart_services_list.dart';
import 'common_device_stuffs.dart';
import 'device_type_enum.dart';
import 'ota/update_info.dart';

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
