import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Backend/Device/bluetooth_uart_services_list.dart';
import 'package:tail_app/Backend/Device/device_registry.dart';
import 'package:tail_app/Backend/Device/device_type_enum.dart';
import 'package:tail_app/Backend/Device/stateful/connected_gear.dart';
import 'package:tail_app/Backend/Device/stored_device.dart';

/// Test helper for creating [StatefulDevice] instances in tests.
class TestGear {
  /// Creates a connected [StatefulDevice], registers it in [KnownDevices],
  /// connects it, and assigns the matching UART service so characteristic
  /// streams are subscribed.
  ///
  /// [deviceName] must match a BT name in [DeviceRegistry] (e.g. 'MiTail'
  /// or 'EG2'). Ears use the "Legacy Ears" UART service, everything else
  /// uses "TailCoNTROL".
  static Future<StatefulDevice> createConnectedStatefulDevice(
    String macAddress, {
    String deviceName = 'MiTail',
  }) async {
    final deviceDefinition = DeviceRegistry.getByName(deviceName)!;
    final storedDevice = StoredDevice(
      deviceDefinition.uuid,
      macAddress,
      deviceDefinition.deviceType.color().toARGB32(),
    )..name = deviceDefinition.friendlyName;
    final statefulDevice = StatefulDevice(deviceDefinition, storedDevice);
    await KnownDevices.instance.add(statefulDevice);

    statefulDevice.deviceConnectionState.value = ConnectivityState.connected;
    statefulDevice.bluetoothUartService = uartServices.firstWhere(
      (element) =>
          element.label ==
          (deviceDefinition.deviceType == DeviceType.ears
              ? 'Legacy Ears'
              : 'TailCoNTROL'),
    );

    return statefulDevice;
  }
}
