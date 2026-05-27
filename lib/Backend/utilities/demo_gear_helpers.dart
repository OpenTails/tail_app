import '../../constants.dart';
import '../Bluetooth/known_devices.dart';
import '../Device/bluetooth_uart_services_list.dart';
import '../Device/device_definition.dart';
import '../Device/device_type_enum.dart';
import '../Device/stateful/connected_gear.dart';
import '../Device/stored_device.dart';

Future<void> createDemoGear(DeviceDefinition value) async {
  String btMac = "DEV${value.deviceType.translatedName}";
  if (KnownDevices.instance.state.containsKey(btMac)) {
    return;
  }
  StoredDevice storedDevice = StoredDevice(
    value.uuid,
    btMac,
    value.deviceType.color().toARGB32(),
  )..name = value.friendlyName;
  StatefulDevice statefulDevice = StatefulDevice(value, storedDevice);

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

bool isDemoGear(StatefulDevice statefulDevice) {
  return statefulDevice.storedDevice.btMACAddress.startsWith(demoGearPrefix);
}
