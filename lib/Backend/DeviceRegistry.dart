import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';
import 'package:tail_app/Backend/Definitions/Action/BaseAction.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

part 'DeviceRegistry.g.dart';

@immutable
class DeviceRegistry {
  static Set<BaseDeviceDefinition> allDevices = {
    BaseDeviceDefinition("798e1528-2832-4a87-93d7-4d1b25a2f418", "MiTail", "MiTail", Uuid.parse("3af2108b-d066-42da-a7d4-55648fa0a9b6"), Uuid.parse("5bfd6484-ddee-4723-bfe6-b653372bbfd6"), Uuid.parse("c6612b64-0087-4974-939e-68968ef294b0"), const Icon(Icons.bluetooth), DeviceType.tail),
    BaseDeviceDefinition("927dee04-ddd4-4582-8e42-69dc9fbfae66", "EG2", "EG2", Uuid.parse("927dee04-ddd4-4582-8e42-69dc9fbfae66"), Uuid.parse("0b646a19-371e-4327-b169-9632d56c0e84"), Uuid.parse("05e026d8-b395-4416-9f8a-c00d6c3781b9"), const Icon(Icons.bluetooth), DeviceType.ears)
  };

  static BaseDeviceDefinition getByUUID(String uuid) {
    return allDevices.firstWhere((BaseDeviceDefinition element) => element.uuid == uuid);
  }

  static BaseDeviceDefinition getByName(String id) {
    return allDevices.firstWhere((BaseDeviceDefinition element) => element.btName == id);
  }

  static bool hasByName(String id) {
    return allDevices.any((BaseDeviceDefinition element) => element.btName == id);
  }

  static List<Uuid> getAllIds() {
    return allDevices.map((BaseDeviceDefinition e) => e.bleDeviceService).toList();
  }

  static BaseDeviceDefinition? getByService(List<Uuid> services) {
    // check list against all devices
    for (BaseDeviceDefinition device in allDevices) {
      if (services.contains(device.bleDeviceService)) {
        return device;
      }
    }
    return null;
  }
}

@Riverpod(dependencies: [KnownDevices])
Set<BaseStatefulDevice> getByAction(GetByActionRef ref, BaseAction baseAction) {
  Flogger.i("Getting devices for action::$baseAction");
  Set<BaseStatefulDevice> foundDevices = {};
  for (BaseStatefulDevice device in ref.read(knownDevicesProvider).values.where((BaseStatefulDevice element) => element.deviceConnectionState.value == DeviceConnectionState.connected)) {
    Flogger.i("Known Device::$device");
    if (baseAction.deviceCategory.contains(device.baseDeviceDefinition.deviceType)) {
      foundDevices.add(device);
    }
  }
  return foundDevices;
}
