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
          () => setState(() {}),
        );
      },
      //onResume: () => _handleTransition('resume'),
      onHide: () async {
        if (ref.read(getAvailableGearProvider).isEmpty) {
          await stopScan();
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
    unawaited(stopScan());
  }

  @override
  Widget build(BuildContext context) {
    BuiltMap<String, BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);
    if (knownDevices.isNotEmpty) {
      return ValueListenableBuilder(
        valueListenable: isBluetoothEnabled,
        builder: (BuildContext context, bool bluetoothEnabled, Widget? child) {
          return ValueListenableBuilder(
            builder: (BuildContext context, alwaysScanBox, Widget? child) {
              bool alwaysScan = alwaysScanBox.get(alwaysScanning, defaultValue: alwaysScanningDefault);
              return Stack(
                children: [
                  StreamBuilder(
                    stream: isScanning(),
                    builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                      return AnimatedCrossFade(firstChild: Container(), secondChild: const LinearProgressIndicator(), crossFadeState: snapshot.hasData && snapshot.data! && !alwaysScan ? CrossFadeState.showSecond : CrossFadeState.showFirst, duration: animationTransitionDuration);
                    },
                  ),
                  NotificationListener<OverscrollNotification>(
                    onNotification: (OverscrollNotification notification) {
                      //knownGearScanControllerLogger.info('Overscroll ${notification.overscroll}');
                      if (notification.overscroll < 2 && notification.overscroll > -2) {
                        // ignore, don't do anything
                        return false;
                      }
                      if (!alwaysScan) {
                        unawaited(beginScan(timeout: scanDurationTimeout, scanReason: ScanReason.manual));
                      }
                      return true;
                    },
                    child: widget.child,
                  ),
                ],
              );
            },
            valueListenable: Hive.box(settings).listenable(keys: [alwaysScanning]),
            child: widget.child,
          );
        },
      );
    }
    unawaited(stopScan());
    return widget.child;
  }
}
