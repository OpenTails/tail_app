import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../Backend/device_registry.dart';
import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';

class BtAppStateController extends ConsumerStatefulWidget {
  const BtAppStateController({required this.child, super.key});

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
        // start FlutterBluePlus if its not started already
        if (HiveProxy.getOrDefault(settings, hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault) >= hasCompletedOnboardingVersionToAgree) {
          ref.read(initFlutterBluePlusProvider);
        }
      },
      onPause: () {
        if (ref.read(getAvailableGearProvider).isEmpty && ref.exists(initFlutterBluePlusProvider)) {
          ref.invalidate(initFlutterBluePlusProvider);
        }
      },
    );
    // start FlutterBluePlus if its not started already
    if (HiveProxy.getOrDefault(settings, hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault) >= hasCompletedOnboardingVersionToAgree) {
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
    if (ref.read(getAvailableGearProvider).isEmpty && ref.exists(initFlutterBluePlusProvider)) {
      ref.invalidate(initFlutterBluePlusProvider);
    }
  }
}
