import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

@immutable
class DeviceRegistry {
  static Set<BaseDeviceDefinition> allDevices = {
    BaseDeviceDefinition(
        Uuid.parse("798e1528-2832-4a87-93d7-4d1b25a2f418"), "MiTail", "MiTail", Uuid.parse("3af2108b-d066-42da-a7d4-55648fa0a9b6"), Uuid.parse("5bfd6484-ddee-4723-bfe6-b653372bbfd6"), Uuid.parse("c6612b64-0087-4974-939e-68968ef294b0"), const Icon(Icons.bluetooth), DeviceType.tail, true),
    BaseDeviceDefinition(
        Uuid.parse("927dee04-ddd4-4582-8e42-69dc9fbfae66"),
        "EG2",
        "EG2",
        Uuid.parse("3af2108b-d066-42da-a7d4-55648fa0a9b6"),
        //TODO: Set
        Uuid.parse("5bfd6484-ddee-4723-bfe6-b653372bbfd6"),
        //TODO: Set
        Uuid.parse("c6612b64-0087-4974-939e-68968ef294b0"),
        //TODO: Set
        const Icon(Icons.bluetooth),
        DeviceType.ears,
        true)
  };

  static BaseDeviceDefinition getByName(String id) {
    return allDevices.firstWhere((element) => element.btName == id);
  }

  static bool hasByName(String id) {
    return allDevices.any((element) => element.btName == id);
  }

  static List<Uuid> getAllIds() {
    return allDevices.map((e) => e.uuid).toList();
  }

  static BaseDeviceDefinition? getByService(List<Uuid> services) {
    // check list against all devices
    for (var device in allDevices) {
      for (var service in services) {
        if (services.contains(service)) {
          return device;
        }
      }
    }
    return null;
  }
}
