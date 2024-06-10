import 'dart:async';

import 'package:logging/logging.dart' as log;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/LoggingWrappers.dart';

import '../Definitions/Device/device_definition.dart';
import '../device_registry.dart';

part 'bluetooth_manager.g.dart';

final log.Logger bluetoothLog = log.Logger('Bluetooth');

@Riverpod(keepAlive: true)
class KnownDevices extends _$KnownDevices {
  @override
  Map<String, BaseStatefulDevice> build() {
    List<BaseStoredDevice> storedDevices = HiveProxy.getAll<BaseStoredDevice>(devicesBox).toList();
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

    return results;
  }

  Future<void> add(BaseStatefulDevice baseStatefulDevice) async {
    Map<String, BaseStatefulDevice> state2 = Map.from(state);
    state2[baseStatefulDevice.baseStoredDevice.btMACAddress] = baseStatefulDevice;
    state = state2;
    await store();
  }

  Future<void> remove(String id) async {
    Map<String, BaseStatefulDevice> state2 = Map.from(state);
    state2.remove(id);
    state = state2;
    await store();
  }

  Future<void> store() async {
    await HiveProxy.clear<BaseStoredDevice>(devicesBox);
    await HiveProxy.addAll<BaseStoredDevice>(devicesBox, state.values.map((e) => e.baseStoredDevice));
  }
}
