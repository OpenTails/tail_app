import 'package:circular_buffer/circular_buffer.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/logging_wrappers.dart';
import 'package:tail_app/constants.dart';

part 'command_history.freezed.dart';
part 'command_history.g.dart';

enum MessageHistoryType { send, receive }

@freezed
abstract class MessageHistoryEntry with _$MessageHistoryEntry {
  const factory MessageHistoryEntry({required MessageHistoryType type, required String message}) = _MessageHistoryEntry;
}

@Riverpod(keepAlive: true)
class CommandHistory extends _$CommandHistory {
  @override
  CircularBuffer<MessageHistoryEntry> build(BaseStatefulDevice device) {
    return CircularBuffer(50);
  }

  void add({required MessageHistoryType type, required String message}) {
    if (HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault) == false) {
      return;
    }
    state.add(MessageHistoryEntry(type: type, message: message));
    ref.notifyListeners();
  }
}
