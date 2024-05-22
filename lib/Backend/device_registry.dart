import 'package:flutter/material.dart';
import 'package:logging/logging.dart' as log;
import 'package:pub_semver/pub_semver.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Definitions/Action/base_action.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';

part 'device_registry.g.dart';

final deviceRegistryLogger = log.Logger('DeviceRegistry');

@immutable
class DeviceRegistry {
  static Set<BaseDeviceDefinition> allDevices = {
    BaseDeviceDefinition(
        uuid: "798e1528-2832-4a87-93d7-4d1b25a2f418",
        btName: "MiTail",
        bleDeviceService: "3af2108b-d066-42da-a7d4-55648fa0a9b6",
        bleRxCharacteristic: "c6612b64-0087-4974-939e-68968ef294b0",
        bleTxCharacteristic: "5bfd6484-ddee-4723-bfe6-b653372bbfd6",
        deviceType: DeviceType.tail,
        fwURL: "https://thetailcompany.com/fw/mitail",
        minVersion: Version(5, 0, 0)),
    const BaseDeviceDefinition(
        uuid: "9c5f3692-1c6e-4d46-b607-4f6f4a6e28ee",
        btName: "(!)Tail1",
        bleDeviceService: "3af2108b-d066-42da-a7d4-55648fa0a9b6",
        bleRxCharacteristic: "c6612b64-0087-4974-939e-68968ef294b0",
        bleTxCharacteristic: "5bfd6484-ddee-4723-bfe6-b653372bbfd6",
        deviceType: DeviceType.tail,
        unsupported: true),
    BaseDeviceDefinition(
      uuid: "5fb21175-fef4-448a-a38b-c472d935abab",
      btName: "minitail",
      bleDeviceService: "3af2108b-d066-42da-a7d4-55648fa0a9b6",
      bleRxCharacteristic: "c6612b64-0087-4974-939e-68968ef294b0",
      bleTxCharacteristic: "5bfd6484-ddee-4723-bfe6-b653372bbfd6",
      deviceType: DeviceType.tail,
      fwURL: "https://thetailcompany.com/fw/mini",
      minVersion: Version(5, 0, 0),
    ),
    BaseDeviceDefinition(
      uuid: "e790f509-f95b-4eb4-b649-5b43ee1eee9c",
      btName: "flutter",
      bleDeviceService: "3af2108b-d066-42da-a7d4-55648fa0a9b6",
      bleRxCharacteristic: "c6612b64-0087-4974-939e-68968ef294b0",
      bleTxCharacteristic: "5bfd6484-ddee-4723-bfe6-b653372bbfd6",
      deviceType: DeviceType.wings,
      fwURL: "https://thetailcompany.com/fw/flutter",
      minVersion: Version(5, 0, 0),
    ),
    const BaseDeviceDefinition(
      uuid: "927dee04-ddd4-4582-8e42-69dc9fbfae66",
      btName: "EG2",
      bleDeviceService: "927dee04-ddd4-4582-8e42-69dc9fbfae66",
      bleRxCharacteristic: "0b646a19-371e-4327-b169-9632d56c0e84",
      bleTxCharacteristic: "05e026d8-b395-4416-9f8a-c00d6c3781b9",
      deviceType: DeviceType.ears,
      fwURL: "https://thetailcompany.com/fw/eg",
    ),
    const BaseDeviceDefinition(
      uuid: "ba2f2b00-8f65-4cc3-afad-58ba1fccd62d",
      btName: "EarGear",
      bleDeviceService: "927dee04-ddd4-4582-8e42-69dc9fbfae66",
      bleRxCharacteristic: "0b646a19-371e-4327-b169-9632d56c0e84",
      bleTxCharacteristic: "05e026d8-b395-4416-9f8a-c00d6c3781b9",
      deviceType: DeviceType.ears,
      unsupported: true,
    )
  };

  static BaseDeviceDefinition getByUUID(String uuid) {
    return allDevices.firstWhere((BaseDeviceDefinition element) => element.uuid == uuid);
  }

  static BaseDeviceDefinition? getByName(String id) {
    return allDevices.firstWhere((BaseDeviceDefinition element) => element.btName.toLowerCase() == id.toLowerCase());
  }

  static List<String> getAllIds() {
    return allDevices.map((BaseDeviceDefinition e) => e.bleDeviceService).toList();
  }
}

@Riverpod()
Set<BaseStatefulDevice> getByAction(GetByActionRef ref, BaseAction baseAction) {
  deviceRegistryLogger.info("Getting devices for action::$baseAction");
  Set<BaseStatefulDevice> foundDevices = {};
  for (BaseStatefulDevice device in ref.read(knownDevicesProvider).values.where((BaseStatefulDevice element) => element.deviceConnectionState.value == ConnectivityState.connected && element.deviceState.value == DeviceState.standby)) {
    deviceRegistryLogger.info("Known Device::$device");
    if (baseAction.deviceCategory.contains(device.baseDeviceDefinition.deviceType)) {
      foundDevices.add(device);
    }
  }
  return foundDevices;
}
