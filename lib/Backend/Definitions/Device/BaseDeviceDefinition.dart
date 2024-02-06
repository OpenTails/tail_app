import 'dart:async';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';

import '../../../Frontend/intnDefs.dart';

part 'BaseDeviceDefinition.g.dart';

enum DeviceType { tail, ears, wings } //TODO extend with icon

extension DeviceTypeExtension on DeviceType {
  String get name {
    switch (this) {
      case DeviceType.tail:
        return deviceTypeTail();
      case DeviceType.ears:
        return deviceTypeEars();
      case DeviceType.wings:
        return deviceTypeWings();
    }
  }

  Color get color {
    switch (this) {
      case DeviceType.tail:
        return Colors.orangeAccent;
      case DeviceType.ears:
        return Colors.blueAccent;
      case DeviceType.wings:
        return Colors.greenAccent;
    }
  }
}

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
  StreamSubscription<ConnectionStateUpdate>? connectionStateStreamSubscription;
  ValueNotifier<DeviceState> deviceState = ValueNotifier(DeviceState.standby);
  Stream<List<int>>? _rxCharacteristicStream;
  StreamSubscription<void>? keepAliveStreamSubscription;

  Stream<List<int>>? get rxCharacteristicStream => _rxCharacteristicStream;
  ValueNotifier<DeviceConnectionState> deviceConnectionState = ValueNotifier(DeviceConnectionState.disconnected);

  set rxCharacteristicStream(Stream<List<int>>? value) {
    _rxCharacteristicStream = value?.asBroadcastStream();
  }

  Ref? ref;
  late CommandQueue commandQueue;
  StreamSubscription<List<int>>? batteryCharacteristicStreamSubscription;

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
        return manageDevicesAutoMoveGroupsCalm();
      case AutoActionCategory.fast:
        return manageDevicesAutoMoveGroupsFast();
      case AutoActionCategory.tense:
        return manageDevicesAutoMoveGroupsFrustrated();
    }
  }
}

// All serialized/stored data
@JsonSerializable(explicitToJson: true)
@HiveType(typeId: 1)
class BaseStoredDevice {
  @HiveField(0)
  @JsonKey(defaultValue: "New Gear")
  String name = "New Gear";
  @HiveField(1)
  @JsonKey(defaultValue: true)
  bool autoMove = true;
  @JsonKey(defaultValue: 15)
  @HiveField(2)
  double autoMoveMinPause = 15;
  @HiveField(3)
  @JsonKey(defaultValue: 240)
  double autoMoveMaxPause = 240;
  @HiveField(4)
  @JsonKey(defaultValue: 60)
  double autoMoveTotal = 60;
  @JsonKey(defaultValue: 1)
  @HiveField(5)
  double noPhoneDelayTime = 1;
  @HiveField(6)
  List<AutoActionCategory> selectedAutoCategories = [AutoActionCategory.calm];
  @HiveField(7)
  final String btMACAddress;
  @HiveField(8)
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
