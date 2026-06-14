import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';

part 'bluetooth_stream_helpers.freezed.dart';

final _logger = Logger('Bluetooth');
// This class exists to map the value changed callback to a stream
StreamController<RxInfo> _streamController = StreamController();

void valueChanged(
  String deviceId,
  String characteristicId,
  Uint8List value,
  int? timestamp,
) {
  if (!_streamController.hasListener) {
    return;
  }
  _streamController.add(
    RxInfo(
      deviceId: deviceId,
      characteristicId: characteristicId,
      value: value,
      timestamp: timestamp,
    ),
  );
}

@freezed
abstract class RxInfo with _$RxInfo {
  const RxInfo._();

  const factory RxInfo({
    required String deviceId,
    required String characteristicId,
    required Uint8List value,
    int? timestamp,
  }) = _RxInfo;
}

Stream<Uint8List> getBaseRxStream(String macAddress, String charcteristicId) {
  return (_streamController.stream
      .where((event) => event.characteristicId == charcteristicId)
      .map((event) => event.value));
}

Stream<String> getRxStream(String macAddress, String charcteristicId) {
  return (getBaseRxStream(macAddress, charcteristicId))
      .map((event) {
        try {
          return const Utf8Decoder().convert(event);
        } catch (e) {
          _logger.warning("Unable to read values: $event $e");
        }
        return "";
      })
      .where((event) => event.isNotEmpty);
}

Stream<bool> getIsChargingStream(String macAddress) {
  return (getRxStream(
    macAddress,
    "5073792e-4fc0-45a0-b0a5-78b6c1756c91",
  )).map((event) => event == "CHARGE ON");
}

Stream<double> getBatteryLevelStream(String macAddress) {
  return (getBaseRxStream(
    macAddress,
    "2a19",
  )).map((event) => event.first.toDouble());
}
