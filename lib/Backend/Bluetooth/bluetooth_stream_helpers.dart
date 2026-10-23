import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:universal_ble/universal_ble.dart';


final _logger = Logger('Bluetooth');
// This class exists to map the value changed callback to a stream
StreamController<BleCharacteristicValue> _streamController = StreamController();
Stream<BleCharacteristicValue> _streamBroadcast = _streamController.stream.asBroadcastStream();

/// Both the listener for [UniversalBle.onValueChange] and an entrypoint to inject incoming messages into the state machine.
/// Adds messages to the relevant stream. usually [getRxStream]
void onBluetoothCharacteristicValueUpdate(
  BleCharacteristicValue bleCharacteristicValue,
) {
  if (!_streamController.hasListener) {
    return;
  }
  _streamController.add(
    bleCharacteristicValue
  );
}



/// THe characteristic change stream but filtered by device and characteristic id;
Stream<Uint8List> getBaseRxStream(String macAddress, String characteristicId) {
  return (_streamBroadcast
          .where(
            (event) => event.deviceId.toLowerCase() == macAddress.toLowerCase(),
          )
          .where(
            (event) => BleUuidParser.compareStrings(
              characteristicId,
              event.characteristicId,
            ),
          )
          .map((event) => event.value))
      .asBroadcastStream();
}

/// Similar to [getBaseRxStream] but converted to [String]
Stream<String> getRxStream(String macAddress, String characteristicId) {
  return (getBaseRxStream(macAddress, characteristicId))
      .map((event) {
        try {
          return const Utf8Decoder().convert(event);
        } catch (e) {
          _logger.warning("Unable to read values: $event $e");
        }
        return "";
      })
      .where((event) => event.isNotEmpty)
      .asBroadcastStream();
}

/// Similar to [getRxStream] but checks the charging characteristic
Stream<bool> getIsChargingStream(String macAddress) {
  return (getRxStream(
    macAddress,
    BleUuidParser.string("5073792e-4fc0-45a0-b0a5-78b6c1756c91"),
  )).map((event) => event == "CHARGE ON");
}
