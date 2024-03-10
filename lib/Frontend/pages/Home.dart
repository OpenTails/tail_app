import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:open_settings/open_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Backend/Bluetooth/BluetoothManager.dart';
import '../intnDefs.dart';

class Home extends ConsumerWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<Widget> values = [
      FadeIn(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.waving_hand),
                    title: Text(subTitle()),
                    subtitle: const Text('This is a fan made app to control The Tail Company tails, ears, and wings'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () async {
                          await launchUrl(Uri.parse('https://thetailcompany.com?utm_source=Tail_App'));
                        },
                        child: const Text('Tail Company Store'),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
    AsyncValue<BleStatus> btStatus = ref.watch(btStatusProvider);
    if (btStatus.valueOrNull == null || btStatus.valueOrNull != BleStatus.ready) {
      if (btStatus.valueOrNull == BleStatus.poweredOff || btStatus.valueOrNull == BleStatus.unsupported) {
        values.add(Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const ListTile(
                    leading: Icon(Icons.bluetooth_disabled),
                    title: Text('Bluetooth is Unavailable'),
                    subtitle: Text('Bluetooth is required to connect to Gear'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () async {
                          OpenSettings.openBluetoothSetting();
                        },
                        child: const Text('Open Settings'),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ));
      }
      if (btStatus.valueOrNull == BleStatus.unauthorized) {
        values.add(Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const ListTile(
                    leading: Icon(Icons.bluetooth_disabled),
                    title: Text('Permission required'),
                    subtitle: Text('Permission is required to connect to nearby Gear.'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () async {
                          Flogger.i("Permission BluetoothScan: ${await Permission.bluetoothScan.request()}");
                          Flogger.i("Permission BluetoothConnect: ${await Permission.bluetoothConnect.request()}");
                        },
                        child: const Text('Grant Permissions'),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ));
      }
    }
    return ListView(
      children: values,
    );
  }
}
