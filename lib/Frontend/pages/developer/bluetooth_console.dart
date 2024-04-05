import 'package:flutter/material.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_message.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';

class BluetoothConsole extends StatefulWidget {
  final BaseStatefulDevice device;

  const BluetoothConsole({super.key, required this.device});

  @override
  State<BluetoothConsole> createState() => _BluetoothConsoleState();
}

class _BluetoothConsoleState extends State<BluetoothConsole> {
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
                widget.device.commandQueue.addCommand(
                  BluetoothMessage(message: cmd, device: widget.device, priority: Priority.high, type: Type.system),
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
                widget.device.commandQueue.addCommand(
                  BluetoothMessage(message: cmd, device: widget.device, priority: Priority.high, type: Type.system),
                );
                setState(() {
                  cmd = "";
                });
              },
              icon: const Icon(Icons.send),
            ),
          )
        ],
      ),
    );
  }
}

class DisplayLog extends StatefulWidget {
  const DisplayLog({
    super.key,
    required this.widget,
  });

  final BluetoothConsole widget;

  @override
  State<DisplayLog> createState() => _DisplayLogState();
}

class _DisplayLogState extends State<DisplayLog> {
  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 100)).then(
      (value) {
        if (context.mounted) {
          setState(() {});
        }
      },
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: ListView.builder(
        reverse: true,
        shrinkWrap: true,
        itemCount: widget.widget.device.messageHistory.length,
        itemBuilder: (BuildContext context, int index) {
          MessageHistoryEntry messageHistoryEntry = widget.widget.device.messageHistory.reversed.toList()[index];
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
