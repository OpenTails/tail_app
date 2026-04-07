import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../../Bluetooth/known_devices.dart';
import 'device_definition.dart';

part 'device_type_enum.g.dart';

@HiveType(typeId: 6)
enum DeviceType {
  @HiveField(1)
  tail,
  @HiveField(2)
  ears,
  @HiveField(3)
  wings,
  @HiveField(4)
  miniTail,
  @HiveField(5)
  claws,
} //TODO extend with icon

extension DeviceTypeExtension on DeviceType {
  String get translatedName {
    switch (this) {
      case DeviceType.tail:
        return deviceTypeTail();
      case DeviceType.ears:
        return deviceTypeEars();
      case DeviceType.wings:
        return deviceTypeWings();
      case DeviceType.miniTail:
        return deviceTypeMiniTail();
      case DeviceType.claws:
        return deviceTypeClawGear();
    }
  }

  Color color() {
    Iterable<StatefulDevice> knownDevices = [];
    knownDevices = KnownDevices.instance.state.values;

    int? color = knownDevices
        .where((element) => element.deviceDefinition.deviceType == this)
        .map((e) => e.storedDevice.color)
        .firstOrNull;
    if (color != null) {
      return Color(color);
    }
    switch (this) {
      case DeviceType.tail:
        return Colors.orangeAccent;
      case DeviceType.miniTail:
        return Colors.redAccent;
      case DeviceType.ears:
        return Colors.blueAccent;
      case DeviceType.wings:
        return Colors.greenAccent;
      case DeviceType.claws:
        return Colors.deepPurpleAccent;
    }
  }

  //mainly used to hide claws from the custom moves pages, since usermove/dssp isnt relevent there.
  bool isHidden() {
    switch (this) {
      case DeviceType.claws:
        return true;
      default:
        return false;
    }
  }
}
