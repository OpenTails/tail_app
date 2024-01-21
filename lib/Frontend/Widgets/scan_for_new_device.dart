import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_ble_platform_interface/src/model/discovered_device.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

import '../../Backend/Bluetooth/BluetoothManager.dart';
import '../../Backend/Settings.dart';

class ScanForNewDevice extends ConsumerStatefulWidget {
  const ScanForNewDevice({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ScanForNewDevice();
}

class ScanDevicesPage extends StatelessWidget {
  const ScanDevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to device'),
      ),
      body: const ScanForNewDevice(),
    );
  }
}

class _ScanForNewDevice extends ConsumerState<ScanForNewDevice> {
  final ScrollController _controller = ScrollController();
  Map<String, DiscoveredDevice> devices = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DiscoveredDevice> foundDevices = ref.watch(scanForDevicesProvider);
    if (foundDevices.valueOrNull != null) {
      DiscoveredDevice? value = foundDevices.valueOrNull;
      if (value != null && !devices.containsKey(value.id)) {
        if (ref.read(preferencesProvider).autoConnectNewDevices) {
          ref.read(btConnectProvider(value));
        } else {
          devices[value.id] = value;
        }
      }
    }
    List<DiscoveredDevice> devicesList = devices.values.toList();
    return Column(
      children: [
        ListTile(
          dense: true,
          trailing: Switch(
            onChanged: (bool value) {
              setState(() {
                ref.read(preferencesProvider).autoConnectNewDevices = value;
              });
              ref.read(preferencesProvider.notifier).store();
            },
            value: ref.read(preferencesProvider).autoConnectNewDevices,
          ),
          title: const Text("Automatically connect to new devices"),
        ),
        ListView.builder(
          shrinkWrap: true,
          itemCount: devices.length,
          controller: _controller,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(getNameFromBTName(devicesList[index].name)),
              trailing: Text(devicesList[index].id),
              onTap: () {
                ref.watch(btConnectProvider(devicesList[index]));
                setState(() {
                  devices.remove(devicesList[index].id);
                });
                //Navigator.pop(context);
              },
            );
          },
        ),
        const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Scanning for gear. Please make sure your gear is powered on and nearby"),
                  )
                ],
              ),
            )),
      ],
    );
  }
}
