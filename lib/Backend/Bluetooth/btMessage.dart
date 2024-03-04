import 'dart:core';

import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

enum Priority { low, normal, high }

class BluetoothMessage implements Comparable<BluetoothMessage> {
  late final String message;
  String? responseMSG; // the message to listen for;
  final BaseStatefulDevice device;
  final DateTime timestamp = DateTime.now();
  Priority priority;
  Function? onCommandSent;
  Function(String)? onResponseReceived;
  double? delay;

  BluetoothMessage(this.message, this.device, this.priority);

  BluetoothMessage.response(this.message, this.device, this.priority, this.responseMSG);

  BluetoothMessage.delay(this.delay, this.device, this.priority) {
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
