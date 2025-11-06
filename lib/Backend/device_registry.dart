import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart' as log;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'Bluetooth/bluetooth_manager.dart';
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

@Riverpod(keepAlive: true)
BuiltSet<BaseStatefulDevice> getByAction(Ref ref, BaseAction baseAction) {
  deviceRegistryLogger.info("Getting devices for action::$baseAction");
  Set<BaseStatefulDevice> foundDevices = {};
  final BuiltList<BaseStatefulDevice> watch = ref.watch(getAvailableIdleGearProvider);
  for (BaseStatefulDevice device in watch) {
    deviceRegistryLogger.info("Known Device::$device");
    if (baseAction.deviceCategory.contains(device.baseDeviceDefinition.deviceType)) {
      foundDevices.add(device);
    }
  }
  return foundDevices.build();
}

@Riverpod(keepAlive: true)
class GetAvailableIdleGear extends _$GetAvailableIdleGear {
  @override
  BuiltList<BaseStatefulDevice> build() {
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

  BuiltList<BaseStatefulDevice> getState() {
    return ref.read(getAvailableGearProvider).where((element) => element.deviceState.value == DeviceState.standby).toBuiltList();
  }

  void _listener() {
    state = getState();
  }

  void _onDeviceConnected() {
    ref.invalidateSelf();
  }
}

@Riverpod()
BuiltSet<DeviceType> getAvailableGearTypes(Ref ref) {
  final BuiltList<BaseStatefulDevice> watch = ref.watch(getAvailableGearProvider);
  return watch.map((e) => e.baseDeviceDefinition.deviceType).toBuiltSet();
}

@Riverpod()
BuiltList<BaseStatefulDevice> getAvailableIdleGearForAction(Ref ref, BaseAction baseAction) {
  final BuiltList<BaseStatefulDevice> watch = ref.watch(getAvailableIdleGearProvider);
  return watch.where((element) => baseAction.deviceCategory.contains(element.baseDeviceDefinition.deviceType)).toBuiltList();
}

@Riverpod()
BuiltList<BaseStatefulDevice> getAvailableIdleGearForType(Ref ref, BuiltSet<DeviceType> deviceTypes) {
  final Iterable<BaseStatefulDevice> watch = ref.watch(getAvailableIdleGearProvider);
  return watch.where((element) => deviceTypes.contains(element.baseDeviceDefinition.deviceType)).toBuiltList();
}

@Riverpod()
BuiltList<BaseStatefulDevice> getAvailableGearForType(Ref ref, BuiltSet<DeviceType> deviceTypes) {
  final BuiltList<BaseStatefulDevice> watch = ref.watch(getAvailableGearProvider);
  return watch.where((element) => deviceTypes.contains(element.baseDeviceDefinition.deviceType)).toBuiltList();
}

@Riverpod()
BuiltList<BaseStatefulDevice> getKnownGearForType(Ref ref, BuiltSet<DeviceType> deviceTypes) {
  final BuiltMap<String, BaseStatefulDevice> watch = KnownDevices.instance.state;
  return watch.values.where((element) => deviceTypes.contains(element.baseDeviceDefinition.deviceType)).toBuiltList();
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
    return ref.read(getAvailableGearForTypeProvider(deviceTypes)).where((element) => element.deviceState.value == DeviceState.runAction).isNotEmpty;
  }

  void _listener() {
    state = getState();
  }

  void _onDeviceConnected() {
    ref.invalidateSelf();
  }
}

@Riverpod(keepAlive: true)
class GetAvailableGear extends _$GetAvailableGear {
  @override
  BuiltList<BaseStatefulDevice> build() {
    KnownDevices.instance
      ..removeListener(_onDeviceConnected)
      ..addListener(_onDeviceConnected);
    for (BaseStatefulDevice baseStatefulDevice in KnownDevices.instance.state.values) {
      baseStatefulDevice.deviceConnectionState
        ..removeListener(_listener)
        ..addListener(_listener);
      baseStatefulDevice.bluetoothUartService
        ..removeListener(_listener)
        ..addListener(_listener);
    }
    return getState();
  }

  BuiltList<BaseStatefulDevice> getState() {
    return KnownDevices.instance.state.values
        .where((element) => element.deviceConnectionState.value == ConnectivityState.connected)
        .where(
          // don't consider gear connected until services have been discovered
          (element) => element.bluetoothUartService.value != null,
        )
        .toBuiltList();
  }

  void _listener() {
    state = getState();
  }

  void _onDeviceConnected() {
    ref.invalidateSelf();
  }
}

@Riverpod(keepAlive: true)
bool isAllKnownGearConnected(Ref ref) {
  var knownGear = KnownDevices.instance.state;
  BuiltList<BaseStatefulDevice> connectedGear = ref.watch(getAvailableGearProvider);
  return knownGear.length == connectedGear.length;
}

@Riverpod(keepAlive: true)
class GetColorForDeviceType extends _$GetColorForDeviceType {
  @override
  Color build(BuiltSet<DeviceType> deviceTypes) {
    final BuiltList<BaseStatefulDevice> watch = ref.watch(getAvailableGearForTypeProvider(deviceTypes));
    for (BaseStatefulDevice baseStatefulDevice in watch) {
      baseStatefulDevice.baseStoredDevice
        ..removeListener(_listener)
        ..addListener(_listener);
    }
    return getState();
  }

  Color getState() {
    final BuiltList<BaseStatefulDevice> watch = ref.read(getAvailableGearForTypeProvider(deviceTypes));
    if (watch.isEmpty) {
      return deviceTypes.first.color();
    }
    return Color(watch.first.baseStoredDevice.color);
  }

  void _listener() {
    state = getState();
  }
}
