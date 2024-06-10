import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/LoggingWrappers.dart';
import 'package:tail_app/Backend/device_registry.dart';
import 'package:tail_app/constants.dart';

Future<BaseStatefulDevice> createAndStoreGear(String gearBtName, ProviderContainer ref, {String gearMacPrefix = 'Dev'}) async {
  BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.getByName(gearBtName)!;
  BaseStoredDevice baseStoredDevice;
  BaseStatefulDevice statefulDevice;
  baseStoredDevice = BaseStoredDevice(baseDeviceDefinition.uuid, "$gearMacPrefix${baseDeviceDefinition.deviceType.name}", baseDeviceDefinition.deviceType.color(ref: ref).value);
  baseStoredDevice.name = getNameFromBTName(baseDeviceDefinition.btName);
  statefulDevice = BaseStatefulDevice(baseDeviceDefinition, baseStoredDevice);
  statefulDevice.deviceConnectionState.value = ConnectivityState.connected;
  isAnyGearConnected.value = true;
  if (!ref.read(knownDevicesProvider).containsKey(baseStoredDevice.btMACAddress)) {
    await ref.read(knownDevicesProvider.notifier).add(statefulDevice);
  }
  return statefulDevice;
}

Future<ProviderContainer> testGearAdd(String name, {String gearMacPrefix = 'DEV'}) async {
  final container = ProviderContainer(
    overrides: [],
  );
  expect(container.read(knownDevicesProvider).length, 0);
  expect(HiveProxy.getAll<BaseStoredDevice>(devicesBox).length, 0);
  BaseStatefulDevice baseStatefulDevice = await createAndStoreGear(name, container, gearMacPrefix: gearMacPrefix);
  expect(baseStatefulDevice.baseDeviceDefinition.btName, name);
  expect(container.read(knownDevicesProvider).length, 1);
  expect(container.read(knownDevicesProvider).values.first, baseStatefulDevice);
  expect(HiveProxy.getAll<BaseStoredDevice>(devicesBox).length, 1);
  expect(HiveProxy.getAll<BaseStoredDevice>(devicesBox).first, baseStatefulDevice.baseStoredDevice);
  return container;
}
