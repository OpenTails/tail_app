import 'package:freezed_annotation/freezed_annotation.dart';

part 'bluetooth_uart_services_list.freezed.dart';

@freezed
abstract class BluetoothUartService with _$BluetoothUartService {
  const factory BluetoothUartService({
    required String bleDeviceService,
    required String bleRxCharacteristic,
    required String bleTxCharacteristic,
    required String label,
  }) = _BluetoothUartService;
}

final List<BluetoothUartService> uartServices = const [
  BluetoothUartService(
    bleDeviceService: "3af2108b-d066-42da-a7d4-55648fa0a9b6",
    bleRxCharacteristic: "c6612b64-0087-4974-939e-68968ef294b0",
    bleTxCharacteristic: "5bfd6484-ddee-4723-bfe6-b653372bbfd6",
    label: "Legacy Gear",
  ),
  BluetoothUartService(
    bleDeviceService: "0000ffe0-0000-1000-8000-00805f9b34fb",
    bleRxCharacteristic: "",
    bleTxCharacteristic: "0000ffe1-0000-1000-8000-00805f9b34fb",
    label: "DigiTail",
  ),
  BluetoothUartService(
    bleDeviceService: "927dee04-ddd4-4582-8e42-69dc9fbfae66",
    bleRxCharacteristic: "0b646a19-371e-4327-b169-9632d56c0e84",
    bleTxCharacteristic: "05e026d8-b395-4416-9f8a-c00d6c3781b9",
    label: "Legacy Ears",
  ),
  // TailCoNTROL uuids
  BluetoothUartService(
    bleDeviceService: "19f8ade2-d0c6-4c0a-912a-30601d9b3060",
    bleRxCharacteristic: "567a99d6-a442-4ac0-b676-4993bf95f805",
    bleTxCharacteristic: "5e4d86ac-ef2f-466f-a857-8776d45ffbc2",
    label: "TailCoNTROL",
  ),
];
