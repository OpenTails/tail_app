import 'dart:core';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../Definitions/Device/device_definition.dart';

part 'bluetooth_message.freezed.dart';

enum Priority { low, normal, high }

enum CommandType { system, move, direct }

@freezed
class BluetoothMessage with _$BluetoothMessage implements Comparable<BluetoothMessage> {
  const BluetoothMessage._();

  @Implements<Comparable<BluetoothMessage>>()
  const factory BluetoothMessage({
    required String message,
    required BaseStatefulDevice device,
    required DateTime timestamp,
    final String? responseMSG,
    @Default(Priority.normal) final Priority priority,
    final Function? onCommandSent,
    final Function(String)? onResponseReceived,
    final double? delay,
    @Default(CommandType.system) CommandType type,
  }) = _BluetoothMessage;

  @override
  int compareTo(other) {
    int val = priority.index.compareTo(other.priority.index);
    if (val == 0) {
      return timestamp.compareTo(other.timestamp);
    } else {
      return val;
    }
  }
}
