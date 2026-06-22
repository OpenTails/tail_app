import '../../constants.dart';
import '../Bluetooth/known_devices.dart';
import '../Device/bluetooth_uart_services_list.dart';
import '../Device/device_definition.dart';
import '../Device/device_type_enum.dart';
import '../Device/stateful/connected_gear.dart';
import '../Device/stored_device.dart';

Future<void> createDemoGear(DeviceDefinition deviceDefinition) async {
  if (isDemoGearExists(deviceDefinition)) {
    return;
  }
  String btMac = getDemoGearBleMac(deviceDefinition);
  StoredDevice storedDevice = StoredDevice(
    deviceDefinition.uuid,
    btMac,
    deviceDefinition.deviceType.color().toARGB32(),
  )..name = deviceDefinition.friendlyName;
  StatefulDevice statefulDevice = StatefulDevice(
    deviceDefinition,
    storedDevice,
  );

  // Has to be added before updating connection state
  await KnownDevices.instance.add(statefulDevice);
  connectDemoGear(statefulDevice);
}

void connectDemoGear(StatefulDevice statefulDevice) {
  statefulDevice.deviceConnectionState.value = ConnectivityState.connected;
  if (statefulDevice.deviceDefinition.deviceType == DeviceType.ears) {
    statefulDevice.bluetoothUartService.value = uartServices.firstWhere(
      (element) => element.label == "Legacy Ears",
    );
  } else {
    statefulDevice.bluetoothUartService.value = uartServices.firstWhere(
      (element) => element.label == "TailCoNTROL",
    );
  }
}

String getDemoGearBleMac(DeviceDefinition deviceDefinition) {
  return "$demoGearPrefix${deviceDefinition.btName}";
}

bool isDemoGearExists(DeviceDefinition deviceDefinition) {
  return KnownDevices.instance.state.containsKey(
    getDemoGearBleMac(deviceDefinition),
  );
}

bool isDemoGear(StatefulDevice statefulDevice) {
  return statefulDevice.storedDevice.btMACAddress.startsWith(demoGearPrefix);
}

bool isDemoGearMac(String btMac) {
  return btMac.startsWith(demoGearPrefix);
}
