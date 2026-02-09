import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart' as log;
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';

import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';

final knownGearScanControllerLogger = log.Logger('KnownGearScanController');

class KnownGearScanController extends StatefulWidget {
  const KnownGearScanController({required this.child, super.key});

  final Widget child;

  @override
  State<KnownGearScanController> createState() => _KnownGearScanControllerState();
}

class _KnownGearScanControllerState extends State<KnownGearScanController> {
  final Duration scanDurationTimeout = const Duration(seconds: 30);
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () {
        Future(
          // force widget rebuild
          () => Scan.instance.isAllGearConnectedListener(),
        );
      },
      //onResume: () => _handleTransition('resume'),
      onHide: () async {
        if (KnownDevices.instance.connectedIdleGear.isEmpty) {
          await Scan.instance.stopScan();
        }
      },
      //onInactive: () => _handleTransition('inactive'),
      //onPause: () => _handleTransition('pause'),
      //onDetach: () => _handleTransition('detach'),
      //onRestart: () => _handleTransition('restart'),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _listener.dispose();
    //ref.read(scanProvider.notifier).stopScan();
  }

  @override
  Widget build(BuildContext context) {
    Scan.instance.isAllGearConnectedListener();
    return widget.child;
  }
}
