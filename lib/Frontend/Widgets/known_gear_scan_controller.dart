import 'dart:async';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:logging/logging.dart' as log;

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/device_registry.dart';
import '../../constants.dart';

final knownGearScanControllerLogger = log.Logger('KnownGearScanController');

class KnownGearScanController extends ConsumerStatefulWidget {
  const KnownGearScanController({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<KnownGearScanController> createState() => _KnownGearScanControllerState();
}

class _KnownGearScanControllerState extends ConsumerState<KnownGearScanController> {
  final Duration scanDurationTimeout = const Duration(seconds: 30);
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () {
        Future(
          // force widget rebuild
          () => ref.read(scanProvider.notifier).isAllGearConnectedListener(),
        );
      },
      //onResume: () => _handleTransition('resume'),
      onHide: () async {
        if (ref.read(getAvailableGearProvider).isEmpty) {
          await ref.read(scanProvider.notifier).stopScan();
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
    ref.read(scanProvider.notifier).isAllGearConnectedListener();
    return widget.child;
  }
}
