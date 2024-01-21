import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';

part 'BaseDeviceDefinition.g.dart';

enum DeviceType { tail, ears, wings } //TODO make class with icon

enum DeviceState { standby, runAction, busy }

class BaseDeviceDefinition {
  final String uuid;
  final String model;
  final String btName;
  final Uuid bleDeviceService;
  final Uuid bleRxCharacteristic;
  final Uuid bleTxCharacteristic;
  final Icon icon;
  final DeviceType deviceType;
  final bool hasBatteryCharacteristic;

  const BaseDeviceDefinition(this.uuid, this.model, this.btName, this.bleDeviceService, this.bleRxCharacteristic, this.bleTxCharacteristic, this.icon, this.deviceType, this.hasBatteryCharacteristic);

  @override
  String toString() {
    return 'BaseDeviceDefinition{btName: $btName, deviceType: $deviceType}';
  }
}

// data that represents the current state of a device
class BaseStatefulDevice {
  final BaseDeviceDefinition baseDeviceDefinition;
  final BaseStoredDevice baseStoredDevice;
  late QualifiedCharacteristic rxCharacteristic;
  late QualifiedCharacteristic txCharacteristic;
  late QualifiedCharacteristic batteryCharacteristic;

  ValueNotifier<double> battery = ValueNotifier(-1);
  ValueNotifier<String> fwVersion = ValueNotifier("");
  ValueNotifier<bool> glowTip = ValueNotifier(false);
  Stream<ConnectionStateUpdate>? connectionStateStream;
  ValueNotifier<DeviceState> deviceState = ValueNotifier(DeviceState.standby);
  Stream<List<int>>? _rxCharacteristicStream;
  Stream<void>? keepAliveStream;

  Stream<List<int>>? get rxCharacteristicStream => _rxCharacteristicStream;
  ValueNotifier<DeviceConnectionState> deviceConnectionState = ValueNotifier(DeviceConnectionState.disconnected);

  set rxCharacteristicStream(Stream<List<int>>? value) {
    _rxCharacteristicStream = value?.asBroadcastStream();
  }

  Ref ref;
  late CommandQueue commandQueue;
  Stream<List<int>>? batteryCharacteristicStream;

  BaseStatefulDevice(this.baseDeviceDefinition, this.baseStoredDevice, this.ref) {
    rxCharacteristic = QualifiedCharacteristic(characteristicId: baseDeviceDefinition.bleRxCharacteristic, serviceId: baseDeviceDefinition.bleDeviceService, deviceId: baseStoredDevice.btMACAddress);
    txCharacteristic = QualifiedCharacteristic(characteristicId: baseDeviceDefinition.bleTxCharacteristic, serviceId: baseDeviceDefinition.bleDeviceService, deviceId: baseStoredDevice.btMACAddress);
    batteryCharacteristic = QualifiedCharacteristic(serviceId: Uuid.parse("0000180f-0000-1000-8000-00805f9b34fb"), characteristicId: Uuid.parse("00002a19-0000-1000-8000-00805f9b34fb"), deviceId: baseStoredDevice.btMACAddress);
    commandQueue = CommandQueue(ref, this);
  }

  @override
  String toString() {
    return 'BaseStatefulDevice{baseDeviceDefinition: $baseDeviceDefinition, baseStoredDevice: $baseStoredDevice, battery: $battery}';
  }
}

@JsonEnum()
enum AutoActionCategory {
  calm,
  fast,
  tense,
}

extension AutoActionCategoryExtension on AutoActionCategory {
  String get friendly {
    switch (this) {
      case AutoActionCategory.calm:
        return "Calm";
      case AutoActionCategory.fast:
        return "Fast";
      case AutoActionCategory.tense:
        return "Frustrated";
      default:
        "";
    }
    return "";
  }
}

// All serialized/stored data
@JsonSerializable(explicitToJson: true)
class BaseStoredDevice {
  @JsonKey(defaultValue: "New Device")
  String name = "New Device";
  @JsonKey(defaultValue: true)
  bool autoMove = true;
  @JsonKey(defaultValue: 15)
  double autoMoveMinPause = 15;
  @JsonKey(defaultValue: 240)
  double autoMoveMaxPause = 240;
  @JsonKey(defaultValue: 60)
  double autoMoveTotal = 60;
  @JsonKey(defaultValue: 1)
  double noPhoneDelayTime = 1;
  List<AutoActionCategory> selectedAutoCategories = [AutoActionCategory.calm];
  final String btMACAddress;
  final String deviceDefinitionUUID;

  BaseStoredDevice(this.deviceDefinitionUUID, this.btMACAddress);

  factory BaseStoredDevice.fromJson(Map<String, dynamic> json) => _$BaseStoredDeviceFromJson(json);

  Map<String, dynamic> toJson() => _$BaseStoredDeviceToJson(this);

  @override
  String toString() {
    return 'BaseStoredDevice{name: $name, btMACAddress: $btMACAddress, deviceDefinitionUUID: $deviceDefinitionUUID}';
  }
}

//Definitly didn't copy from https://github.com/OpenTails/CRUMPET-Android/commit/b465ad134dcdb7774fe4e59edf756bf3242d5e30
String getNameFromBTName(String BTName) {
  switch (BTName) {
    case 'EG2':
      return 'EarGear 2';
    case 'mitail':
      return 'MiTail';
    case 'minitail':
      return 'MiTail Mini';
    case 'flutter':
      return 'FlutterWings';
  }
  return BTName;
}
