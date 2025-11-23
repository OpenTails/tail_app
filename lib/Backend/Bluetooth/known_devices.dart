import 'dart:async';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart' as log;

import '../../constants.dart';
import '../Definitions/Device/device_definition.dart';
import '../device_registry.dart';
import '../logging_wrappers.dart';

final log.Logger bluetoothLog = log.Logger('Bluetooth');

class KnownDevices with ChangeNotifier {
  late BuiltMap<String, BaseStatefulDevice> _state;
  BuiltMap<String, BaseStatefulDevice> get state => _state;

  //https://stackoverflow.com/questions/12649573/how-do-you-build-a-singleton-in-dart
  static final KnownDevices instance = KnownDevices._internal();

  KnownDevices._internal() {
    BuiltList<BaseStoredDevice> storedDevices = HiveProxy.getAll<BaseStoredDevice>(devicesBox).toBuiltList();
    Map<String, BaseStatefulDevice> results = {};
    try {
      if (storedDevices.isNotEmpty) {
        for (BaseStoredDevice e in storedDevices) {
          if (e.btMACAddress.contains("DEV")) {
            continue;
          }
          BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.getByUUID(e.deviceDefinitionUUID);
          BaseStatefulDevice baseStatefulDevice = BaseStatefulDevice(baseDeviceDefinition, e);
          results[e.btMACAddress] = baseStatefulDevice;
        }
      }
    } catch (e, s) {
      bluetoothLog.severe("Unable to load stored devices due to $e", e, s);
    }
    _state = BuiltMap(results);
  }

  Future<void> add(BaseStatefulDevice baseStatefulDevice) async {
    _state = _state.rebuild((p0) => p0[baseStatefulDevice.baseStoredDevice.btMACAddress] = baseStatefulDevice);
    await store();
  }

  Future<void> remove(String id) async {
    _state = _state.rebuild((p0) => p0.remove(id));
    await store();
  }

  Future<void> store() async {
    await HiveProxy.clear<BaseStoredDevice>(devicesBox);
    await HiveProxy.addAll<BaseStoredDevice>(devicesBox, state.values.map((e) => e.baseStoredDevice));
    _notify();

    _onDevicePaired();
  }

  Future<void> removeDevGear() async {
    _state = _state.rebuild((p0) => p0.removeWhere((p0, p1) => p0.contains("DEV")));
    await store();
  }

  // Helpers for gear connected

  void _notify() {
    notifyListeners();
  }

  BuiltList<BaseStatefulDevice> get connectedGear {
    return KnownDevices.instance.state.values
        .where((element) => element.deviceConnectionState.value == ConnectivityState.connected)
        .where(
          // don't consider gear connected until services have been discovered
          (element) => element.bluetoothUartService.value != null,
        )
        .toBuiltList();
  }

  bool get isAllGearConnected {
    return connectedGear.length == state.length;
  }
BuiltSet<DeviceType> get connectedGearTypes {
  return connectedGear.map((e) => e.baseDeviceDefinition.deviceType).toBuiltSet();
}

  BuiltList<BaseStatefulDevice> getKnownGearForType(BuiltSet<DeviceType> deviceTypes) {
    return state.values.where((element) => deviceTypes.contains(element.baseDeviceDefinition.deviceType)).toBuiltList();
  }

  BuiltList<BaseStatefulDevice> getConnectedGearForType(BuiltSet<DeviceType> deviceTypes) {
    return connectedGear.where((element) => deviceTypes.contains(element.baseDeviceDefinition.deviceType)).toBuiltList();
  }

  BuiltList<BaseStatefulDevice> get connectedIdleGear {
    return connectedGear.where((element) => element.deviceState.value == DeviceState.standby).toBuiltList();
  }

  BuiltList<BaseStatefulDevice> getConnectedIdleGearForType(BuiltSet<DeviceType> deviceTypes) {
    return connectedIdleGear.where((element) => deviceTypes.contains(element.baseDeviceDefinition.deviceType)).toBuiltList();
  }

  void _onDevicePaired() {
    for (BaseStatefulDevice baseStatefulDevice in KnownDevices.instance.state.values) {
      baseStatefulDevice.deviceConnectionState
        ..removeListener(_notify)
        ..addListener(_notify);
      baseStatefulDevice.bluetoothUartService
        ..removeListener(_notify)
        ..addListener(_notify);
    }
  }
}
