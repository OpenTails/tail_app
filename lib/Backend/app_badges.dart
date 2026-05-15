import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';

import '../Frontend/utils.dart';

class AppBadgeManager with WidgetsBindingObserver {
  static final AppBadgeManager instance = AppBadgeManager._internal();
  final Logger _logger = Logger("App Badge");

  AppBadgeManager._internal() {
    if (!isMobile) {
      return;
    }
    _logger.info("Init badge manager");
    KnownDevices.instance.addListener(_listener);
    _listener();
  }

  Future<void> _listener() async {
    if (await AppBadgePlus.isSupported()) {
      await AppBadgePlus.updateBadge(
        KnownDevices.instance.connectedGear.length,
      );
    }
  }
}
