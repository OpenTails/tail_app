import 'dart:async';

import 'package:logging/logging.dart' as log;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_hive/sentry_hive.dart';

import '../Definitions/Device/device_definition.dart';
import '../device_registry.dart';

part 'bluetooth_manager.g.dart';

final log.Logger bluetoothLog = log.Logger('Bluetooth');

@Riverpod(keepAlive: true)
class KnownDevices extends _$KnownDevices {
  @override
  Map<String, BaseStatefulDevice> build() {
    List<BaseStoredDevice> storedDevices = SentryHive.box<BaseStoredDevice>('devices').values.toList();
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

  void add(BaseStatefulDevice baseStatefulDevice) {
    Map<String, BaseStatefulDevice> state2 = Map.from(state);
    state2[baseStatefulDevice.baseStoredDevice.btMACAddress] = baseStatefulDevice;
    state = state2;
    store();
  }

  void remove(String id) {
    Map<String, BaseStatefulDevice> state2 = Map.from(state);
    state2.remove(id);
    state = state2;
    store();
  }

  Future<void> store() async {
    SentryHive.box<BaseStoredDevice>('devices')
      ..clear()
      ..addAll(state.values.map((e) => e.baseStoredDevice));
  }
}
