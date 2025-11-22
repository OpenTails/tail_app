import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart' as log;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'Bluetooth/known_devices.dart';
import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/device_definition.dart';
import 'version.dart';

part 'device_registry.g.dart';

final deviceRegistryLogger = log.Logger('DeviceRegistry');

@immutable
class DeviceRegistry {
  static const List<BaseDeviceDefinition> allDevices = [
    BaseDeviceDefinition(uuid: "798e1528-2832-4a87-93d7-4d1b25a2f418", btName: "MiTail", deviceType: DeviceType.tail, minVersion: Version(major: 5, minor: 0, patch: 0)),
    BaseDeviceDefinition(uuid: "9c5f3692-1c6e-4d46-b607-4f6f4a6e28ee", btName: "(!)Tail1", deviceType: DeviceType.tail, unsupported: true),
    BaseDeviceDefinition(uuid: "5fb21175-fef4-448a-a38b-c472d935abab", btName: "minitail", deviceType: DeviceType.miniTail, minVersion: Version(major: 5, minor: 0, patch: 0)),
    BaseDeviceDefinition(uuid: "e790f509-f95b-4eb4-b649-5b43ee1eee9c", btName: "flutter", deviceType: DeviceType.wings, minVersion: Version(major: 5, minor: 0, patch: 0)),
    BaseDeviceDefinition(uuid: "927dee04-ddd4-4582-8e42-69dc9fbfae66", btName: "EG2", deviceType: DeviceType.ears),
    BaseDeviceDefinition(uuid: "2a5d91c2-16cc-482d-acf0-5b623904f7ae", btName: "clawgear", deviceType: DeviceType.claws),
    BaseDeviceDefinition(uuid: "ba2f2b00-8f65-4cc3-afad-58ba1fccd62d", btName: "EarGear", deviceType: DeviceType.ears, unsupported: true),
  ];

  static BaseDeviceDefinition getByUUID(String uuid) {
    return allDevices.firstWhere((BaseDeviceDefinition element) => element.uuid == uuid);
  }

  static BaseDeviceDefinition? getByName(String id) {
    return allDevices.firstWhere((BaseDeviceDefinition element) => element.btName.toLowerCase() == id.toLowerCase());
  }

  static BuiltList<String> getAllIds() {
    return uartServices.map((e) => e.bleDeviceService).toBuiltList();
  }
}

BuiltSet<BaseStatefulDevice> getByAction(BaseAction baseAction) {
  deviceRegistryLogger.info("Getting devices for action::$baseAction");
  Set<BaseStatefulDevice> foundDevices = {};
  for (BaseStatefulDevice device in KnownDevices.instance.connectedIdleGear) {
    deviceRegistryLogger.info("Known Device::$device");
    if (baseAction.deviceCategory.contains(device.baseDeviceDefinition.deviceType)) {
      foundDevices.add(device);
    }
  }
  return foundDevices.build();
}

@Riverpod(keepAlive: true)
class IsGearMoveRunning extends _$IsGearMoveRunning {
  @override
  bool build(BuiltSet<DeviceType> deviceTypes) {
    KnownDevices.instance
      ..removeListener(_onDeviceConnected)
      ..addListener(_onDeviceConnected);
    for (BaseStatefulDevice baseStatefulDevice in KnownDevices.instance.state.values) {
      baseStatefulDevice.deviceState
        ..removeListener(_listener)
        ..addListener(_listener);
    }
    return getState();
  }

  bool getState() {
    return KnownDevices.instance.getConnectedGearForType(deviceTypes).where((element) => element.deviceState.value == DeviceState.runAction).isNotEmpty;
  }

  void _listener() {
    state = getState();
  }

  void _onDeviceConnected() {
    ref.invalidateSelf();
  }
}

@Riverpod(keepAlive: true)
class GetColorForDeviceType extends _$GetColorForDeviceType {
  @override
  Color build(BuiltSet<DeviceType> deviceTypes) {
    KnownDevices.instance
      ..removeListener(_listener)
      ..addListener(_listener);
    final BuiltList<BaseStatefulDevice> watch = KnownDevices.instance.getKnownGearForType(deviceTypes);
    for (BaseStatefulDevice baseStatefulDevice in watch) {
      baseStatefulDevice.baseStoredDevice
        ..removeListener(_listener)
        ..addListener(_listener);
    }
    return getState();
  }

  Color getState() {
    final BuiltList<BaseStatefulDevice> watch = KnownDevices.instance.getConnectedGearForType(deviceTypes);
    if (watch.isEmpty) {
      return deviceTypes.first.color();
    }
    return Color(watch.first.baseStoredDevice.color);
  }

  void _listener() {
    ref.invalidateSelf();
  }
}
