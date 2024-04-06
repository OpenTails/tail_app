import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart' as log;
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';

final knownGearScanControllerLogger = log.Logger('KnownGearScanController');

class KnownGearScanController extends ConsumerWidget {
  const KnownGearScanController({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Map<String, BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);
    if (knownDevices.isNotEmpty) {
      return MultiValueListenableBuilder(
        valueListenables: knownDevices.values.map((e) => e.deviceConnectionState).toList(),
        builder: (BuildContext context, List<dynamic> values, Widget? child) {
          // Check if all known devices are connected, stop passive scanning if true
          knownGearScanControllerLogger.info("Device connectivity state updated");
          if (!values.every((element) => element == DeviceConnectionState.connected)) {
            // Verify scanning can start
            knownGearScanControllerLogger.info("Not all gear connected");
            if (ref.watch(btStatusProvider).valueOrNull == BleStatus.ready) {
              //when running, automatically reconnects to devices
              knownGearScanControllerLogger.info("Scanning for gear");
              ref.watch(scanForDevicesProvider);
            }
          } else {
            knownGearScanControllerLogger.info("All devices connected");
          }
          return child!;
        },
        child: child,
      );
    }
    return child;
  }
}
