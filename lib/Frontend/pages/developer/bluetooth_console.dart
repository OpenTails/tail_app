import 'package:circular_buffer/circular_buffer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/command_history.dart';
import 'package:tail_app/Backend/command_queue.dart';

import '../../../Backend/Bluetooth/bluetooth_message.dart';
import '../../../Backend/Definitions/Device/device_definition.dart';
import '../../go_router_config.dart';

class BluetoothConsole extends ConsumerStatefulWidget {
  final BaseStatefulDevice device;

  const BluetoothConsole({required this.device, super.key});

  @override
  ConsumerState<BluetoothConsole> createState() => _BluetoothConsoleState();
}

class _BluetoothConsoleState extends ConsumerState<BluetoothConsole> {
  String cmd = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Console"),
      ),
      body: Stack(
        children: [
          DisplayLog(widget: widget),
          Align(
            alignment: Alignment.bottomLeft,
            child: TextField(
              controller: TextEditingController(text: cmd),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Send a Command",
                hintText: 'TAILHA',
              ),
              maxLines: 1,
              maxLength: 128,
              autocorrect: false,
              onEditingComplete: () {
                ref.read(commandQueueProvider(widget.device).notifier).addCommand(
                      BluetoothMessage(message: cmd, priority: Priority.high, type: CommandType.system, timestamp: DateTime.now()),
                    );
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
                ref.read(commandQueueProvider(widget.device).notifier).addCommand(
                      BluetoothMessage(message: cmd, priority: Priority.high, type: CommandType.system, timestamp: DateTime.now()),
                    );
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

class DisplayLog extends ConsumerStatefulWidget {
  const DisplayLog({
    required this.widget,
    super.key,
  });

  final BluetoothConsole widget;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  ConsumerState<DisplayLog> createState() => _DisplayLogState();
}

class _DisplayLogState extends ConsumerState<DisplayLog> {
  @override
  Widget build(BuildContext context) {
    CircularBuffer buffer = ref.watch(commandHistoryProvider(widget.widget.device));
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: ListView.builder(
        reverse: true,
        shrinkWrap: true,
        itemCount: buffer.length,
        itemBuilder: (BuildContext context, int index) {
          MessageHistoryEntry messageHistoryEntry = buffer.reversed.toList()[index];
          //TODO: autocomplete for known commands
          return Text(
            messageHistoryEntry.message,
            textDirection: messageHistoryEntry.type == MessageHistoryType.send ? TextDirection.rtl : TextDirection.ltr,
          );
        },
      ),
    );
  }
}
