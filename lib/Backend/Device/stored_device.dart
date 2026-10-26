import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../utilities/version.dart';
import 'common_device_stuffs.dart';

part 'stored_device.g.dart';

// All serialized/stored data
@HiveType(typeId: 1)
class StoredDevice extends ChangeNotifier {
  @HiveField(0)
  String name = "New Gear";
  @HiveField(7)
  final String btMACAddress;
  @HiveField(8)
  final String deviceDefinitionUUID;
  @HiveField(9)
  int _color;

  @HiveField(10, defaultValue: 1)
  int leftHomePosition = 1;
  @HiveField(11, defaultValue: 1)
  int rightHomePosition = 1;
  @HiveField(12, defaultValue: "")
  String conModePin = "";
  bool _conModeEnabled = false;

  @HiveField(13, defaultValue: false)
  bool get conModeEnabled => _conModeEnabled;

  @HiveField(13, defaultValue: false)
  set conModeEnabled(bool value) {
    _conModeEnabled = value;
    notifyListeners();
  }

  @HiveField(14, defaultValue: GlowtipStatus.unknown)
  GlowtipStatus hasGlowtip = GlowtipStatus.unknown;
  @HiveField(15, defaultValue: RGBStatus.unknown)
  RGBStatus hasRGB = RGBStatus.unknown;

  @HiveField(16, defaultValue: Version())
  Version firmwareVersion = Version();
  @HiveField(17, defaultValue: "")
  String hardwareVersion = "";

  int get color => _color;

  set color(int value) {
    _color = value;
    notifyListeners();
  }

  StoredDevice(this.deviceDefinitionUUID, this.btMACAddress, this._color) {
    // Set convention mode pin to a random 6 digit number
    if (conModePin.isEmpty) {
      int code = Random().nextInt(899999) + 100000;
      conModePin = code.toString();
    }
  }

  @override
  String toString() {
    return 'storedDevice{name: $name, btMACAddress: $btMACAddress, deviceDefinitionUUID: $deviceDefinitionUUID}';
  }
}
