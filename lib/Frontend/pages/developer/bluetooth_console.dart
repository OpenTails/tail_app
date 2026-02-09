import 'package:circular_buffer/circular_buffer.dart';
import 'package:flutter/material.dart';
import 'package:tail_app/Backend/command_history.dart';

import '../../../Backend/Bluetooth/bluetooth_message.dart';
import '../../../Backend/Definitions/Device/device_definition.dart';
import '../../go_router_config.dart';

class BluetoothConsole extends StatefulWidget {
  final BaseStatefulDevice device;

  const BluetoothConsole({required this.device, super.key});

  @override
  State<BluetoothConsole> createState() => _BluetoothConsoleState();
}

class _BluetoothConsoleState extends State<BluetoothConsole> {
  String cmd = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Console")),
      body: Stack(
        children: [
          DisplayLog(console: widget),
          Align(
            alignment: Alignment.bottomLeft,
            child: TextField(
              controller: TextEditingController(text: cmd),
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Send a Command", hintText: 'TAILHA'),
              maxLines: 1,
              maxLength: 128,
              autocorrect: false,
              onEditingComplete: () {
                widget.device.commandQueue.addCommand(BluetoothMessage(message: cmd, priority: Priority.high, type: CommandType.system, timestamp: DateTime.now()));
                setState(() {
                  cmd = "";
                });
              },
              onChanged: (nameValue) {
                cmd = nameValue.toUpperCase();
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: IconButton(
              onPressed: () {
                widget.device.commandQueue.addCommand(BluetoothMessage(message: cmd, priority: Priority.high, type: CommandType.system, timestamp: DateTime.now()));
                setState(() {
                  cmd = "";
                });
              },
              icon: const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }
}

class DisplayLog extends StatefulWidget {
  const DisplayLog({required this.console, super.key});

  final BluetoothConsole console;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  State<DisplayLog> createState() => _DisplayLogState();
}

class _DisplayLogState extends State<DisplayLog> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.console.device.commandQueue.commandHistory,
      builder: (context, child) {
        CircularBuffer buffer = widget.console.device.commandQueue.commandHistory.state;
        return Padding(
          padding: const EdgeInsets.only(bottom: 100),
          child: ListView.builder(
            reverse: true,
            shrinkWrap: true,
            itemCount: buffer.length,
            itemBuilder: (BuildContext context, int index) {
              MessageHistoryEntry messageHistoryEntry = buffer.reversed.toList()[index];
              return Text(messageHistoryEntry.message, textDirection: messageHistoryEntry.type == MessageHistoryType.send ? TextDirection.rtl : TextDirection.ltr);
            },
          ),
        );
      },
    );
  }
}
