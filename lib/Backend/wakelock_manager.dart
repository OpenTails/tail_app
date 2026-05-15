import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Frontend/utils.dart';
import 'package:tail_app/constants.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'logging_wrappers.dart';

class WakelockManager {
  static final instance = WakelockManager._internal();
  final Logger _logger = Logger("Wakelock");

  WakelockManager._internal() {
    if (!isMobile) {
      return;
    }
    KnownDevices.instance.addListener(_listener);
    Hive.box(settings).listenable(keys: [keepAwake]).addListener(_listener);
  }

  Future<void> _listener() async {
    if (!isMobile) {
      return;
    }
    bool isAnyConnected = KnownDevices.instance.connectedGear.isNotEmpty;
    bool isKeepAwakeEnabled = HiveProxy.getOrDefault(
      settings,
      keepAwake,
      defaultValue: keepAwakeDefault,
    );
    bool isWakelockRunning = await WakelockPlus.enabled;
    if (isKeepAwakeEnabled && isAnyConnected && !isWakelockRunning) {
      _logger.info("Starting wakelock");
      WakelockPlus.enable();
    } else if ((!isAnyConnected || !isKeepAwakeEnabled) && isWakelockRunning) {
      _logger.info("Stopping wakelock");
      WakelockPlus.disable();
    }
  }
}
