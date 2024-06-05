import 'dart:core';

import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';

enum Priority { low, normal, high }

enum CommandType { system, move, direct }

class BluetoothMessage implements Comparable<BluetoothMessage> {
  late final String message;
  String? responseMSG; // the message to listen for;
  final BaseStatefulDevice device;
  final DateTime timestamp = DateTime.now();
  Priority priority;
  Function? onCommandSent;
  Function(String)? onResponseReceived;
  double? delay;
  CommandType type;

  BluetoothMessage({required this.message, required this.device, required this.priority, required this.type, this.responseMSG, this.onCommandSent, this.onResponseReceived});

  BluetoothMessage.delay({required this.delay, required this.device, required this.priority, required this.type}) {
    message = "";
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is BluetoothMessage && runtimeType == other.runtimeType && message == other.message && device == other.device;

  @override
  int get hashCode => message.hashCode ^ device.hashCode;

  @override
  String toString() {
    return 'btMessage{message: $message, device: , timestamp: $timestamp}';
  }

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
