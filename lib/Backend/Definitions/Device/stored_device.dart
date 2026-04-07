import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

import '../../version.dart';
import 'common_device_stuffs.dart';

part 'stored_device.freezed.dart';

part 'stored_device.g.dart';

@freezed
// TailControl only
abstract class GearConfigInfo with _$GearConfigInfo {
  const GearConfigInfo._();

  const factory GearConfigInfo({
    @Default("") String ver,
    @Default("") String minsToSleep,
    @Default("") String minsToNPM,
    @Default("") String minNPMPauseSec,
    @Default("") String maxNPMPauseSec,
    @Default("") String groupsNPM,
    @Default("") String servo1home,
    @Default("") String servo2home,
    @Default("") String listenModeNPMEnabled,
    @Default("") String listenModeResponseOnly,
    @Default("") String groupsLM,
    @Default("") String tiltModeNPMEnabled,
    @Default("") String tiltModeResponseOnly,
    @Default("") String disconnectedCountdownEnabled,
    @Default("") String homeOnAppPoweroff,
    @Default("") String conferenceModeEnabled,
    @Default("") String securityPasskey,
  }) = _GearConfigInfo;

  factory GearConfigInfo.fromGearString(String fwInput) {
    List<String> values = fwInput.split(" ");
    String ver = values[0];
    String minsToSleep = values[1];
    String minsToNPM = values[2];
    String minNPMPauseSec = values[3];
    String maxNPMPauseSec = values[4];
    String groupsNPM = values[5];
    String servo1home = values[6];
    String servo2home = values[7];
    String listenModeNPMEnabled = values[8];
    String listenModeResponseOnly = values[9];
    String groupsLM = values[10];
    String tiltModeNPMEnabled = values[11];
    String tiltModeResponseOnly = values[12];
    String disconnectedCountdownEnabled = values[13];
    String homeOnAppPoweroff = values[14];
    String conferenceModeEnabled = values[15];
    String securityPasskey = values[16];

    return GearConfigInfo(
      ver: ver,
      minsToSleep: minsToSleep,
      minsToNPM: minsToNPM,
      minNPMPauseSec: minNPMPauseSec,
      maxNPMPauseSec: maxNPMPauseSec,
      groupsNPM: groupsNPM,
      servo1home: servo1home,
      servo2home: servo2home,
      listenModeNPMEnabled: listenModeNPMEnabled,
      listenModeResponseOnly: listenModeResponseOnly,
      groupsLM: groupsLM,
      tiltModeNPMEnabled: tiltModeNPMEnabled,
      tiltModeResponseOnly: tiltModeResponseOnly,
      disconnectedCountdownEnabled: disconnectedCountdownEnabled,
      homeOnAppPoweroff: homeOnAppPoweroff,
      conferenceModeEnabled: conferenceModeEnabled,
      securityPasskey: securityPasskey,
    );
  }

  String toGearString() {
    return "$ver $minsToSleep $minsToNPM $minNPMPauseSec $maxNPMPauseSec $groupsNPM $servo1home $servo2home $listenModeNPMEnabled $listenModeResponseOnly $groupsLM $tiltModeNPMEnabled $tiltModeResponseOnly $disconnectedCountdownEnabled $homeOnAppPoweroff $conferenceModeEnabled $securityPasskey";
  }
}

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
  @HiveField(13, defaultValue: false)
  bool conModeEnabled = false;

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
