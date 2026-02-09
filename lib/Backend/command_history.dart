import 'package:circular_buffer/circular_buffer.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tail_app/Backend/logging_wrappers.dart';
import 'package:tail_app/constants.dart';

part 'command_history.freezed.dart';

enum MessageHistoryType { send, receive }

@freezed
abstract class MessageHistoryEntry with _$MessageHistoryEntry {
  const factory MessageHistoryEntry({required MessageHistoryType type, required String message}) = _MessageHistoryEntry;
}

class CommandHistory with ChangeNotifier {
  final CircularBuffer<MessageHistoryEntry> _state = CircularBuffer(50);
  CircularBuffer<MessageHistoryEntry> get state => _state;

  void add({required MessageHistoryType type, required String message}) {
    if (HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault) == false) {
      return;
    }
    _state.add(MessageHistoryEntry(type: type, message: message));
    notifyListeners();
  }
}
