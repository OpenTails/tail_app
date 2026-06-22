import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_ce/hive.dart';
import 'package:tail_app/Backend/Device/stateful/connected_gear.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../../assets.dart';
import '../Bluetooth/known_devices.dart';

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

  String iconAssetPath() {
    switch (this) {
      case DeviceType.tail:
        return Assets.icons.tail2;
      case DeviceType.miniTail:
        return Assets.icons.tail9;
      case DeviceType.ears:
        return Assets.icons.ears;
      case DeviceType.wings:
        return Assets.icons.wings;
      case DeviceType.claws:
        return "";
    }
  }

  Widget icon(double size, Color iconColor) {
    return SvgPicture.asset(
      iconAssetPath(),
      colorMapper: _MyColorMapper(iconColor: iconColor),
      height: size,
    );
  }
}

class _MyColorMapper extends ColorMapper {
  const _MyColorMapper({required this.iconColor});

  final Color iconColor;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color.computeLuminance() < 0.5) {
      return iconColor;
    }
    if (color == Colors.white) {
      return Colors.transparent;
    }
    return color;
  }
}
