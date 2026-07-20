import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tail_app/Backend/Device/command/command_history.dart';

import '../../../Backend/Bluetooth/bluetooth_message.dart';
import '../../../Backend/Device/stateful/connected_gear.dart';
import '../../Widgets/uwu_text.dart';

class BluetoothConsole extends StatefulWidget {
  final StatefulDevice device;

  const BluetoothConsole({required this.device, super.key});

  @override
  State<BluetoothConsole> createState() => _BluetoothConsoleState();
}

bool _filterMessages = false;

class _BluetoothConsoleState extends State<BluetoothConsole> {
  String cmd = "";
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendCommand() {
    if (cmd.isEmpty) return;
    widget.device.commandQueue.addCommand(
      BluetoothMessage(message: cmd, priority: Priority.high),
    );
    setState(() {
      cmd = "";
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(convertToUwU("Bluetooth Console")),
        actions: [
          IconButton(
            onPressed: widget.device.commandQueue.commandHistory.clear,
            icon: const Icon(Symbols.delete_sweep),
            tooltip: convertToUwU("Clear Log"),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _filterMessages = !_filterMessages;
              });
            },
            icon: Icon(
              _filterMessages ? Symbols.filter_alt_off : Symbols.filter_alt,
            ),
            tooltip: convertToUwU(
              _filterMessages
                  ? "Show VER/HWVER messages"
                  : "Hide VER/HWVER messages",
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.device.commandQueue.commandHistory,
        builder: (context, child) {
          List<MessageHistoryEntry> buffer = widget
              .device
              .commandQueue
              .commandHistory
              .state
              .reversed
              .toList();

          if (_filterMessages) {
            buffer = buffer
                .where((entry) => !_shouldFilterMessage(entry.message))
                .toList();

            if (buffer.isEmpty) {
              return Center(child: Text(convertToUwU("No messages in log")));
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: buffer.length,
            reverse: true,
            itemBuilder: (BuildContext context, int index) {
              MessageHistoryEntry entry = buffer[index];
              bool isSend = entry.type == MessageHistoryType.send;

              return _MessageBubble(entry: entry, isSend: isSend);
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: (value) {
                    cmd = value.toUpperCase();
                  },
                  onSubmitted: (_) => _sendCommand(),
                  decoration: InputDecoration(
                    hintText: 'TAILHA',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendCommand,
                icon: const Icon(Symbols.send),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldFilterMessage(String message) {
    return message.startsWith("VER") ||
        message.startsWith("HWVER") ||
        message.startsWith("PING") ||
        message.startsWith("PONG") ||
        message.startsWith("BATT");
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageHistoryEntry entry;
  final bool isSend;

  const _MessageBubble({required this.entry, required this.isSend});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSend ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isSend
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isSend ? 16 : 0),
            bottomRight: Radius.circular(isSend ? 0 : 16),
          ),
        ),
        child: Text(
          convertToUwU(entry.message),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: isSend
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
