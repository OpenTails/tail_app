import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
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
    BaseDeviceDefinition(
      uuid: "798e1528-2832-4a87-93d7-4d1b25a2f418",
      btName: "MiTail",
      bleDeviceService: "3af2108b-d066-42da-a7d4-55648fa0a9b6",
      bleRxCharacteristic: "c6612b64-0087-4974-939e-68968ef294b0",
      bleTxCharacteristic: "5bfd6484-ddee-4723-bfe6-b653372bbfd6",
      deviceType: DeviceType.tail,
      fwURL: "https://thetailcompany.com/fw/mitailfw",
      minVersion: Version(major: 5, minor: 0, patch: 0),
    ),
    BaseDeviceDefinition(
      uuid: "9c5f3692-1c6e-4d46-b607-4f6f4a6e28ee",
      btName: "(!)Tail1",
      bleDeviceService: "3af2108b-d066-42da-a7d4-55648fa0a9b6",
      bleRxCharacteristic: "c6612b64-0087-4974-939e-68968ef294b0",
      bleTxCharacteristic: "5bfd6484-ddee-4723-bfe6-b653372bbfd6",
      deviceType: DeviceType.tail,
      unsupported: true,
    ),
    BaseDeviceDefinition(
      uuid: "5fb21175-fef4-448a-a38b-c472d935abab",
      btName: "minitail",
      bleDeviceService: "3af2108b-d066-42da-a7d4-55648fa0a9b6",
      bleRxCharacteristic: "c6612b64-0087-4974-939e-68968ef294b0",
      bleTxCharacteristic: "5bfd6484-ddee-4723-bfe6-b653372bbfd6",
      deviceType: DeviceType.miniTail,
      fwURL: "https://thetailcompany.com/fw/mini",
      minVersion: Version(major: 5, minor: 0, patch: 0),
    ),
    BaseDeviceDefinition(
      uuid: "e790f509-f95b-4eb4-b649-5b43ee1eee9c",
      btName: "flutter",
      bleDeviceService: "3af2108b-d066-42da-a7d4-55648fa0a9b6",
      bleRxCharacteristic: "c6612b64-0087-4974-939e-68968ef294b0",
      bleTxCharacteristic: "5bfd6484-ddee-4723-bfe6-b653372bbfd6",
      deviceType: DeviceType.wings,
      fwURL: "https://thetailcompany.com/fw/flutter",
      minVersion: Version(major: 5, minor: 0, patch: 0),
    ),
    BaseDeviceDefinition(
      uuid: "927dee04-ddd4-4582-8e42-69dc9fbfae66",
      btName: "EG2",
      bleDeviceService: "927dee04-ddd4-4582-8e42-69dc9fbfae66",
      bleRxCharacteristic: "0b646a19-371e-4327-b169-9632d56c0e84",
      bleTxCharacteristic: "05e026d8-b395-4416-9f8a-c00d6c3781b9",
      deviceType: DeviceType.ears,
      fwURL: "https://thetailcompany.com/fw/eg",
    ),
    BaseDeviceDefinition(
      uuid: "ba2f2b00-8f65-4cc3-afad-58ba1fccd62d",
      btName: "EarGear",
      bleDeviceService: "927dee04-ddd4-4582-8e42-69dc9fbfae66",
      bleRxCharacteristic: "0b646a19-371e-4327-b169-9632d56c0e84",
      bleTxCharacteristic: "05e026d8-b395-4416-9f8a-c00d6c3781b9",
      deviceType: DeviceType.ears,
      unsupported: true,
    ),
  ];

  static BaseDeviceDefinition getByUUID(String uuid) {
    return allDevices.firstWhere((BaseDeviceDefinition element) => element.uuid == uuid);
  }

  static BaseDeviceDefinition? getByName(String id) {
    return allDevices.firstWhere((BaseDeviceDefinition element) => element.btName.toLowerCase() == id.toLowerCase());
  }

  static List<String> getAllIds() {
    return allDevices.map((BaseDeviceDefinition e) => e.bleDeviceService).toSet().toList();
  }
}

@Riverpod(keepAlive: true)
BuiltSet<BaseStatefulDevice> getByAction(GetByActionRef ref, BaseAction baseAction) {
  deviceRegistryLogger.info("Getting devices for action::$baseAction");
  Set<BaseStatefulDevice> foundDevices = {};
  final Map<String, BaseStatefulDevice> watch = ref.watch(knownDevicesProvider);
  for (BaseStatefulDevice device in watch.values.where((BaseStatefulDevice element) => element.deviceConnectionState.value == ConnectivityState.connected && element.deviceState.value == DeviceState.standby)) {
    deviceRegistryLogger.info("Known Device::$device");
    if (baseAction.deviceCategory.contains(device.baseDeviceDefinition.deviceType)) {
      foundDevices.add(device);
    }
  }
  return foundDevices.build();
}

@Riverpod(keepAlive: true)
Iterable<BaseStatefulDevice> getAvailableIdleGear(GetAvailableIdleGearRef ref) {
  final List<BaseStatefulDevice> watch = ref.watch(getAvailableGearProvider);
  return watch.where((element) => element.deviceState.value == DeviceState.standby);
}

@Riverpod(keepAlive: true)
Set<DeviceType> getAvailableGearTypes(GetAvailableGearTypesRef ref) {
  final List<BaseStatefulDevice> watch = ref.watch(getAvailableGearProvider);
  return watch
      .map(
        (e) => e.baseDeviceDefinition.deviceType,
      )
      .toSet();
}

@Riverpod(keepAlive: true)
Iterable<BaseStatefulDevice> getAvailableIdleGearForAction(GetAvailableIdleGearForActionRef ref, BaseAction baseAction) {
  final Iterable<BaseStatefulDevice> watch = ref.watch(getAvailableIdleGearProvider);
  return watch.where((element) => baseAction.deviceCategory.contains(element.baseDeviceDefinition.deviceType));
}

@Riverpod(keepAlive: true)
Iterable<BaseStatefulDevice> getAvailableIdleGearForType(GetAvailableIdleGearForTypeRef ref, BuiltSet<DeviceType> deviceTypes) {
  final Iterable<BaseStatefulDevice> watch = ref.watch(getAvailableIdleGearProvider);
  return watch.where(
    (element) => deviceTypes.contains(element.baseDeviceDefinition.deviceType),
  );
}

@Riverpod(keepAlive: true)
Iterable<BaseStatefulDevice> getAvailableGearForType(GetAvailableGearForTypeRef ref, BuiltSet<DeviceType> deviceTypes) {
  final Iterable<BaseStatefulDevice> watch = ref.watch(getAvailableGearProvider);
  return watch.where(
    (element) => deviceTypes.contains(element.baseDeviceDefinition.deviceType),
  );
}

@Riverpod(keepAlive: true)
Iterable<BaseStatefulDevice> getKnownGearForType(GetKnownGearForTypeRef ref, BuiltSet<DeviceType> deviceTypes) {
  final Map<String, BaseStatefulDevice> watch = ref.watch(knownDevicesProvider);
  return watch.values.where(
    (element) => deviceTypes.contains(element.baseDeviceDefinition.deviceType),
  );
}

@Riverpod(keepAlive: true)
class IsGearMoveRunning extends _$IsGearMoveRunning {
  @override
  bool build(BuiltSet<DeviceType> deviceTypes) {
    for (BaseStatefulDevice baseStatefulDevice in ref.watch(knownDevicesProvider).values) {
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
}

@Riverpod(keepAlive: true)
class GetAvailableGear extends _$GetAvailableGear {
  @override
  List<BaseStatefulDevice> build() {
    for (BaseStatefulDevice baseStatefulDevice in ref.watch(knownDevicesProvider).values) {
      baseStatefulDevice.deviceConnectionState
        ..removeListener(_listener)
        ..addListener(_listener);
    }
    return getState();
  }

  List<BaseStatefulDevice> getState() {
    return ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == ConnectivityState.connected).toList();
  }

  void _listener() {
    state = getState();
  }
}

@Riverpod(keepAlive: true)
Color getColorForDeviceType(GetColorForDeviceTypeRef ref, BuiltSet<DeviceType> deviceTypes) {
  final Iterable<BaseStatefulDevice> watch = ref.watch(getAvailableGearForTypeProvider(deviceTypes));
  if (watch.isEmpty) {
    return deviceTypes.first.color();
  }
  return Color(watch.first.baseStoredDevice.color);
}
