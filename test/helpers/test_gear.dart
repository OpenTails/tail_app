import 'package:tail_app/Backend/Device/bluetooth_uart_services_list.dart';
import 'package:tail_app/Backend/Device/device_registry.dart';
import 'package:tail_app/Backend/Device/device_type_enum.dart';
import 'package:tail_app/Backend/Device/stateful/connected_gear.dart';
import 'package:tail_app/Backend/Device/stored_device.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';

/// Test helper for creating [StatefulDevice] instances in tests.
class TestGear {
  /// Creates a real MiTail [StatefulDevice], registers it in
  /// [KnownDevices], connects it, and assigns the TailCoNTROL UART service so
  /// characteristic streams are subscribed.
  static Future<StatefulDevice> createConnectedStatefulDevice(
    String macAddress,
  ) async {
    final deviceDefinition = DeviceRegistry.getByName('MiTail')!;
    final storedDevice = StoredDevice(
      deviceDefinition.uuid,
      macAddress,
      deviceDefinition.deviceType.color().toARGB32(),
    )..name = deviceDefinition.friendlyName;
    final statefulDevice = StatefulDevice(deviceDefinition, storedDevice);
    await KnownDevices.instance.add(statefulDevice);

    statefulDevice.deviceConnectionState.value = ConnectivityState.connected;
    statefulDevice.bluetoothUartService = uartServices.firstWhere(
      (element) => element.label == 'TailCoNTROL',
    );

    return statefulDevice;
  }
}