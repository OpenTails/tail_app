import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_hive/sentry_hive.dart';

import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../constants.dart';

class BtAppStateController extends ConsumerStatefulWidget {
  const BtAppStateController({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BtAppStateController> createState() => _BtAppStateControllerState();
}

class _BtAppStateControllerState extends ConsumerState<BtAppStateController> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () {
        ref.read(initFlutterBluePlusProvider);
      },
      onPause: () {
        if (!isAnyGearConnected.value) {
          ref.invalidate(initFlutterBluePlusProvider);
        }
      },
    );
    // start FlutterBluePlus if its not started already
    if (SentryHive.box(settings).get(hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault) >= hasCompletedOnboardingVersionToAgree) {
      ref.read(initFlutterBluePlusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    super.dispose();
    _listener.dispose();
    if (!isAnyGearConnected.value && ref.exists(initFlutterBluePlusProvider)) {
      ref.invalidate(initFlutterBluePlusProvider);
    }
  }
}