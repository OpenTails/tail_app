import 'package:flutter/material.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

@immutable
class DeviceRegistry {
  static const Set<BaseDeviceDefinition> allDevices = {
    BaseDeviceDefinition("798e1528-2832-4a87-93d7-4d1b25a2f418", "MiTail", "MiTail", "3af2108b-d066-42da-a7d4-55648fa0a9b6", "5bfd6484-ddee-4723-bfe6-b653372bbfd6", "c6612b64-0087-4974-939e-68968ef294b0", Icon(Icons.bluetooth), DeviceType.tail, true),
    BaseDeviceDefinition(
        "ace9fe88-92d2-4b0e-8c1d-628e9a4f44a1",
        "EG2",
        "EG2",
        "3af2108b-d066-42da-a7d4-55648fa0a9b6",
        //TODO: Set
        "5bfd6484-ddee-4723-bfe6-b653372bbfd6",
        //TODO: Set
        "c6612b64-0087-4974-939e-68968ef294b0",
        //TODO: Set
        Icon(Icons.bluetooth),
        DeviceType.ears,
        true)
  };

  static BaseDeviceDefinition getByName(String id) {
    return allDevices.firstWhere((element) => element.btName == id);
  }

  static bool hasByName(String id) {
    return allDevices.any((element) => element.btName == id);
  }
}
