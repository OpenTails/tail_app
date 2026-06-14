import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart' as log;

import '../Action/base_action.dart';
import '../Bluetooth/known_devices.dart';
import '../utilities/version.dart';
import 'bluetooth_uart_services_list.dart';
import 'device_definition.dart';
import 'device_type_enum.dart';
import 'stateful/connected_gear.dart';

final _deviceRegistryLogger = log.Logger('DeviceRegistry');

@immutable
class DeviceRegistry {
  static const Iterable<DeviceDefinition> allDevices = [
    DeviceDefinition(
      uuid: "798e1528-2832-4a87-93d7-4d1b25a2f418",
      btName: "MiTail",
      friendlyName: "MiTail",
      deviceType: DeviceType.tail,
      minVersion: Version(major: 5, minor: 0, patch: 0),
      enableDemo: true,
    ),
    DeviceDefinition(
      uuid: "9c5f3692-1c6e-4d46-b607-4f6f4a6e28ee",
      btName: "(!)Tail1",
      friendlyName: "DigiTail",
      deviceType: DeviceType.tail,
      unsupported: true,
    ),
    DeviceDefinition(
      uuid: "5fb21175-fef4-448a-a38b-c472d935abab",
      btName: "minitail",
      friendlyName: "Mini Tail",
      deviceType: DeviceType.miniTail,
      minVersion: Version(major: 5, minor: 0, patch: 0),
    ),
    DeviceDefinition(
      uuid: "e790f509-f95b-4eb4-b649-5b43ee1eee9c",
      btName: "flutter",
      friendlyName: "FlutterWings",
      deviceType: DeviceType.wings,
      minVersion: Version(major: 5, minor: 0, patch: 0),
      enableDemo: true,
    ),
    DeviceDefinition(
      uuid: "927dee04-ddd4-4582-8e42-69dc9fbfae66",
      btName: "EG2",
      friendlyName: "EarGear 2",
      deviceType: DeviceType.ears,
      enableDemo: true,
    ),
    DeviceDefinition(
      uuid: "2a5d91c2-16cc-482d-acf0-5b623904f7ae",
      btName: "clawgear",
      friendlyName: "Claws",
      deviceType: DeviceType.claws,
      enableDemo: true,
    ),
    DeviceDefinition(
      uuid: "ba2f2b00-8f65-4cc3-afad-58ba1fccd62d",
      btName: "EarGear",
      friendlyName: "EarGear 1",
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
    return allDevices.firstWhereOrNull(
      (DeviceDefinition element) =>
          element.btName.toLowerCase() == id.toLowerCase(),
    );
  }

  static final Iterable<String> getAllIds = uartServices.map(
    (e) => e.bleDeviceService,
  );
}

Set<StatefulDevice> getByAction(BaseAction baseAction) {
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
  return foundDevices;
}
