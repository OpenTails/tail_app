import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/device_registry.dart';

Future<BaseStatefulDevice> createAndStoreGear(String gearBtName, ProviderContainer ref) async {
  BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.getByName(gearBtName)!;
  BaseStoredDevice baseStoredDevice;
  BaseStatefulDevice statefulDevice;
  baseStoredDevice = BaseStoredDevice(baseDeviceDefinition.uuid, "DEV${baseDeviceDefinition.deviceType.name}", baseDeviceDefinition.deviceType.color(ref: ref).value);
  baseStoredDevice.name = getNameFromBTName(baseDeviceDefinition.btName);
  statefulDevice = BaseStatefulDevice(baseDeviceDefinition, baseStoredDevice);
  statefulDevice.deviceConnectionState.value = ConnectivityState.connected;
  isAnyGearConnected.value = true;
  if (!ref.read(knownDevicesProvider).containsKey(baseStoredDevice.btMACAddress)) {
    await ref.read(knownDevicesProvider.notifier).add(statefulDevice);
  }
  return statefulDevice;
}
