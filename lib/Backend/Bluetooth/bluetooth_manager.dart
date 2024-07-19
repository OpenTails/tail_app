import 'dart:async';

import 'package:built_collection/built_collection.dart';
import 'package:logging/logging.dart' as log;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/firmware_update.dart';

import '../../constants.dart';
import '../Definitions/Device/device_definition.dart';
import '../device_registry.dart';
import '../logging_wrappers.dart';

part 'bluetooth_manager.g.dart';

final log.Logger bluetoothLog = log.Logger('Bluetooth');

@Riverpod(keepAlive: true)
class KnownDevices extends _$KnownDevices {
  @override
  BuiltMap<String, BaseStatefulDevice> build() {
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
          getFwInfoListener(baseStatefulDevice);
        }
      }
    } catch (e, s) {
      bluetoothLog.severe("Unable to load stored devices due to $e", e, s);
    }
    return BuiltMap(results);
  }

  Future<void> getFwInfoListener(BaseStatefulDevice baseStatefulDevice) async {
    ref.read(CheckForFWUpdateProvider(baseStatefulDevice));
  }

  Future<void> add(BaseStatefulDevice baseStatefulDevice) async {
    state = state.rebuild((p0) => p0[baseStatefulDevice.baseStoredDevice.btMACAddress] = baseStatefulDevice);
    getFwInfoListener(baseStatefulDevice);
    await store();
  }

  Future<void> remove(String id) async {
    state = state.rebuild(
      (p0) => p0.remove(id),
    );
    await store();
  }

  Future<void> store() async {
    await HiveProxy.clear<BaseStoredDevice>(devicesBox);
    await HiveProxy.addAll<BaseStoredDevice>(devicesBox, state.values.map((e) => e.baseStoredDevice));
  }

  Future<void> removeDevGear() async {
    state = state.rebuild(
      (p0) => p0.removeWhere(
        (p0, p1) => p0.contains("DEV"),
      ),
    );
    await store();
  }
}
