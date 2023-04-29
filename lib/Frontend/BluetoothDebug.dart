import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tail_app/main.dart';

class DeviceList extends ConsumerWidget {
  const DeviceList({super.key});

  List<Widget> getEntries(WidgetRef ref) {
    List<DevicePairEntry> entries = [];
    for (ScanResult device in ref.read(bluetoothProvider).listenableResults.value) {
      entries.add(DevicePairEntry(device));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Devices'),
        ),
        body: ValueListenableBuilder(
            builder: (context, value, child) {
              return ListView(
                children: getEntries(ref),
              );
            },
            valueListenable: ref.watch(bluetoothProvider).listenableResults));
  }
}

class DevicePairEntry extends ConsumerWidget {
  final ScanResult scanResult;

  const DevicePairEntry(
    this.scanResult, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(scanResult.device.name),
      onTap: () {
        showDialog<void>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(scanResult.device.name),
                content: Text(scanResult.toString()),
                actions: <Widget>[
                  TextButton(
                    style: TextButton.styleFrom(
                      textStyle: Theme.of(context).textTheme.labelLarge,
                    ),
                    child: const Text('Connect'),
                    onPressed: () {
                      ref.read(bluetoothProvider).registerNewDevice(scanResult.device);
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      textStyle: Theme.of(context).textTheme.labelLarge,
                    ),
                    child: const Text('Dismiss'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            });
      },
      leading: const Icon(Icons.bluetooth),
      subtitle: Text(scanResult.device.id.id),
    );
  }
}
