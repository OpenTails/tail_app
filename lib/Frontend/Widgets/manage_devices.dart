import 'package:flutter/material.dart';
import 'package:tail_app/Frontend/Widgets/manage_known_devices.dart';
import 'package:tail_app/Frontend/Widgets/scan_for_new_device.dart';

class ManageDevices extends StatelessWidget {
  const ManageDevices({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        ManageKnownDevices(),
        ScanForNewDevice(),
      ],
    );
  }
}
