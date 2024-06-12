import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:logging/logging.dart' as log;
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:sentry_hive/sentry_hive.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
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
        if (!isAnyGearConnected.value) {
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
    Map<String, BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);
    if (knownDevices.isNotEmpty) {
      return ValueListenableBuilder(
        valueListenable: isBluetoothEnabled,
        builder: (BuildContext context, bool bluetoothEnabled, Widget? child) {
          return ValueListenableBuilder(
            builder: (BuildContext context, alwaysScanBox, Widget? child) {
              bool alwaysScan = alwaysScanBox.get(alwaysScanning, defaultValue: alwaysScanningDefault);
              return MultiValueListenableBuilder(
                valueListenables: knownDevices.values.map((e) => e.deviceConnectionState).toList(),
                builder: (BuildContext context, List<dynamic> values, Widget? child) {
                  // Check if all known devices are connected, stop passive scanning if true
                  knownGearScanControllerLogger.info("Device connectivity state updated");
                  if (!values.every((element) => element == ConnectivityState.connected) && alwaysScan) {
                    // Verify scanning can start
                    knownGearScanControllerLogger.info("Not all gear connected");
                    if (bluetoothEnabled) {
                      //when running, automatically reconnects to devices
                      knownGearScanControllerLogger.info("Scanning for gear");
                      unawaited(beginScan());
                    }
                  } else {
                    knownGearScanControllerLogger.info("All devices connected");
                    unawaited(stopScan());
                  }
                  return child!;
                },
                child: Stack(
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
                          unawaited(beginScan(timeout: scanDurationTimeout));
                        }
                        return true;
                      },
                      child: widget.child,
                    ),
                  ],
                ),
              );
            },
            valueListenable: SentryHive.box(settings).listenable(keys: [alwaysScanning]),
            child: widget.child,
          );
        },
      );
    }
    unawaited(stopScan());
    return widget.child;
  }
}
