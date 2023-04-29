import 'package:flutter/material.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

@immutable
class btMessage {
  final String message;
  final BaseStatefulDevice device;
  final DateTime timestamp = DateTime.now();

  btMessage(this.message, this.device);

  @override
  bool operator ==(Object other) => identical(this, other) || other is btMessage && runtimeType == other.runtimeType && message == other.message && device == other.device;

  @override
  int get hashCode => message.hashCode ^ device.hashCode;

  @override
  String toString() {
    return 'btMessage{message: $message, device: , timestamp: $timestamp}';
  }
}
