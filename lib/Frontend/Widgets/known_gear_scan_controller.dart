import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:logging/logging.dart' as log;
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/constants.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';

final knownGearScanControllerLogger = log.Logger('KnownGearScanController');

class KnownGearScanController extends ConsumerStatefulWidget {
  const KnownGearScanController({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KnownGearScanController> createState() => _KnownGearScanControllerState();
}

class _KnownGearScanControllerState extends ConsumerState<KnownGearScanController> {
  bool shouldScan = false;
  final Duration scanDurationTimeout = const Duration(seconds: 30);
  Timer? scanTimeout;

  @override
  Widget build(BuildContext context) {
    Map<String, BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);
    if (knownDevices.isNotEmpty) {
      return ValueListenableBuilder(
        valueListenable: isBluetoothEnabled,
        builder: (BuildContext context, bool bluetoothEnabled, Widget? child) {
          return ValueListenableBuilder(
            builder: (BuildContext context, alwaysScan, Widget? child) {
              return MultiValueListenableBuilder(
                valueListenables: knownDevices.values.map((e) => e.deviceConnectionState).toList(),
                builder: (BuildContext context, List<dynamic> values, Widget? child) {
                  // Check if all known devices are connected, stop passive scanning if true
                  knownGearScanControllerLogger.info("Device connectivity state updated");
                  if (!values.every((element) => element == ConnectivityState.connected) && (SentryHive.box(settings).get(alwaysScanning, defaultValue: alwaysScanningDefault) || shouldScan)) {
                    // Verify scanning can start
                    knownGearScanControllerLogger.info("Not all gear connected");
                    if (bluetoothEnabled) {
                      //when running, automatically reconnects to devices
                      knownGearScanControllerLogger.info("Scanning for gear");
                      beginScan();
                    }
                  } else {
                    knownGearScanControllerLogger.info("All devices connected");
                    if (shouldScan) {
                      Future(
                        () => setState(
                          () {
                            shouldScan = false;
                            scanTimeout?.cancel();
                            scanTimeout = null;
                          },
                        ),
                      );
                    }
                    scanTimeout?.cancel();
                    scanTimeout = null;
                    stopScan();
                  }
                  return child!;
                },
                child: Stack(
                  children: [
                    AnimatedCrossFade(firstChild: Container(), secondChild: const LinearProgressIndicator(), crossFadeState: shouldScan ? CrossFadeState.showSecond : CrossFadeState.showFirst, duration: animationTransitionDuration),
                    NotificationListener<OverscrollNotification>(
                        onNotification: (OverscrollNotification notification) {
                          knownGearScanControllerLogger.info('Overscroll ${notification.overscroll}');
                          if (notification.overscroll < 2 && notification.overscroll > -2) {
                            // ignore, don't do anything
                            return false;
                          }
                          startScanTimer();
                          return true;
                        },
                        child: widget.child),
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
    stopScan();
    return widget.child;
  }

  void startScanTimer() {
    if (scanTimeout != null && scanTimeout!.isActive) {
      return;
    }
    knownGearScanControllerLogger.info('Starting scan timer');
    scanTimeout = Timer(
      scanDurationTimeout,
      () {
        knownGearScanControllerLogger.info('Scan timer finished');
        if (mounted) {
          setState(
            () {
              shouldScan = false;
            },
          );
        }
        scanTimeout = null;
      },
    );
    if (mounted) {
      setState(
        () {
          shouldScan = true;
        },
      );
    } else {
      shouldScan = true;
    }
  }
}
