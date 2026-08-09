import 'package:circular_buffer/circular_buffer.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_message.dart';
import 'package:tail_app/Backend/utilities/developer_options_helpers.dart';

part 'command_history.freezed.dart';

enum MessageHistoryType { send, receive }

@freezed
abstract class MessageHistoryEntry with _$MessageHistoryEntry {
  const factory MessageHistoryEntry({
    required MessageHistoryType type,
    required String message,
    final BluetoothMessage? currentCommandQueueMessage,
  }) = _MessageHistoryEntry;
}

class CommandHistory with ChangeNotifier {
  final CircularBuffer<MessageHistoryEntry> _state = CircularBuffer(100);

  CircularBuffer<MessageHistoryEntry> get state => _state;

  void add({
    required MessageHistoryType type,
    required String message,
    BluetoothMessage? bluetoothMessage,
  }) {
    if (isDeveloperEnabled == false) {
      return;
    }
    _state.add(
      MessageHistoryEntry(
        type: type,
        message: message,
        currentCommandQueueMessage: bluetoothMessage,
      ),
    );
    notifyListeners();
  }

  void clear() {
    _state.clear();
    notifyListeners();
  }
}
