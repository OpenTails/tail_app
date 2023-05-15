import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../Action/BaseAction.dart';

enum DeviceType { tail, ears, unknown }

enum DeviceState { disconnected, standby, runAction, casual, noPhone }

@immutable
class BaseDeviceDefinition {
  final Uuid uuid;
  final String model;
  final String btName;
  final Uuid bleDeviceService;
  final Uuid bleRxCharacteristic;
  final Uuid bleTxCharacteristic;
  final Icon icon;
  final DeviceType deviceType;
  final bool hasBatteryCharacteristic;

  const BaseDeviceDefinition(this.uuid, this.model, this.btName, this.bleDeviceService, this.bleRxCharacteristic, this.bleTxCharacteristic, this.icon, this.deviceType, this.hasBatteryCharacteristic);
}

// data that represents the current state of a device
class BaseStatefulDevice {
  final BaseDeviceDefinition baseDeviceDefinition;
  final BaseStoredDevice baseStoredDevice;

  //final BluetoothDevice device;
  double battery = -1;
  double fwVersion = -1;
  double hwVersion = -1;
  BaseAction? currentAction;
  DeviceState deviceState = DeviceState.disconnected;

  //BluetoothCharacteristic? readCharacteristic;
  //BluetoothCharacteristic? writeCharacteristic;
  //BluetoothCharacteristic? batteryCharacteristic;

  BaseStatefulDevice(this.baseDeviceDefinition, this.baseStoredDevice);
}

// All serialized/stored data
class BaseStoredDevice {
  String name = "New Device";
  String btMACAddress = "";
  Color? color;
  String deviceDefinitionUUID;

  BaseStoredDevice(this.deviceDefinitionUUID, this.btMACAddress);

  @override
  bool operator ==(Object other) => identical(this, other) || other is BaseStoredDevice && runtimeType == other.runtimeType && name == other.name && btMACAddress == other.btMACAddress && color == other.color && deviceDefinitionUUID == other.deviceDefinitionUUID;

  @override
  int get hashCode => name.hashCode ^ btMACAddress.hashCode ^ color.hashCode ^ deviceDefinitionUUID.hashCode;

  @override
  String toString() {
    return 'BaseStoredDevice{name: $name, btMACAddress: $btMACAddress, color: $color, deviceDefinitionUUID: $deviceDefinitionUUID}';
  }
}
