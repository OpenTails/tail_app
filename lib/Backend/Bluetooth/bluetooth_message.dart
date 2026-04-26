import 'dart:core';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'bluetooth_message.freezed.dart';

enum Priority { low, normal, high }

enum CommandType { system, move, direct }

@freezed
class BluetoothMessage
    with _$BluetoothMessage
    implements Comparable<BluetoothMessage> {
  @override
  final DateTime timestamp;
  @override
  final String message;
  @override
  final String? responseMSG;
  @override
  final Priority priority;
  @override
  final double? delay;
  @override
  final CommandType type;

  BluetoothMessage({
    required this.message,
    this.responseMSG,
    this.priority = Priority.normal,
    this.type = CommandType.system,
    DateTime? timestamp,
    this.delay,
  }) : timestamp = timestamp ?? DateTime.now();

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
