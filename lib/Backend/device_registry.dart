import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart' as log;

import 'Bluetooth/known_devices.dart';
import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/bluetooth_uart_services_list.dart';
import 'Definitions/Device/device_definition.dart';
import 'Definitions/Device/device_type_enum.dart';
import 'version.dart';

final _deviceRegistryLogger = log.Logger('DeviceRegistry');

@immutable
class DeviceRegistry {
  static const List<DeviceDefinition> allDevices = [
    DeviceDefinition(
      uuid: "798e1528-2832-4a87-93d7-4d1b25a2f418",
      btName: "MiTail",
      deviceType: DeviceType.tail,
      minVersion: Version(major: 5, minor: 0, patch: 0),
    ),
    DeviceDefinition(
      uuid: "9c5f3692-1c6e-4d46-b607-4f6f4a6e28ee",
      btName: "(!)Tail1",
      deviceType: DeviceType.tail,
      unsupported: true,
    ),
    DeviceDefinition(
      uuid: "5fb21175-fef4-448a-a38b-c472d935abab",
      btName: "minitail",
      deviceType: DeviceType.miniTail,
      minVersion: Version(major: 5, minor: 0, patch: 0),
    ),
    DeviceDefinition(
      uuid: "e790f509-f95b-4eb4-b649-5b43ee1eee9c",
      btName: "flutter",
      deviceType: DeviceType.wings,
      minVersion: Version(major: 5, minor: 0, patch: 0),
    ),
    DeviceDefinition(
      uuid: "927dee04-ddd4-4582-8e42-69dc9fbfae66",
      btName: "EG2",
      deviceType: DeviceType.ears,
    ),
    DeviceDefinition(
      uuid: "2a5d91c2-16cc-482d-acf0-5b623904f7ae",
      btName: "clawgear",
      deviceType: DeviceType.claws,
    ),
    DeviceDefinition(
      uuid: "ba2f2b00-8f65-4cc3-afad-58ba1fccd62d",
      btName: "EarGear",
      deviceType: DeviceType.ears,
      unsupported: true,
    ),
  ];

  static DeviceDefinition getByUUID(String uuid) {
    return allDevices.firstWhere(
      (DeviceDefinition element) => element.uuid == uuid,
    );
  }

  static DeviceDefinition? getByName(String id) {
    return allDevices.firstWhere(
      (DeviceDefinition element) =>
          element.btName.toLowerCase() == id.toLowerCase(),
    );
  }

  static BuiltList<String> getAllIds() {
    return uartServices.map((e) => e.bleDeviceService).toBuiltList();
  }
}

BuiltSet<StatefulDevice> getByAction(BaseAction baseAction) {
  _deviceRegistryLogger.info("Getting devices for action::$baseAction");
  Set<StatefulDevice> foundDevices = {};
  for (StatefulDevice device in KnownDevices.instance.connectedIdleGear) {
    _deviceRegistryLogger.info("Known Device::$device");
    if (baseAction.deviceCategory.contains(
      device.deviceDefinition.deviceType,
    )) {
      foundDevices.add(device);
    }
  }
  return foundDevices.build();
}
