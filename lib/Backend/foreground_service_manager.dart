import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Backend/triggers/stored_triggers.dart';
import 'package:tail_app/Backend/triggers/trigger.dart';

// If the noise trigger is enabled/disabled, we need to update the foreground
// service type, otherwise mic access will be blocked in the background on
// android.
class ForegroundServiceManager with ChangeNotifier {
  final Logger _logger = Logger("ForegroundServiceManager");
  static final ForegroundServiceManager instance =
      ForegroundServiceManager._internal();

  ForegroundServiceManager._internal() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Gear Connected',
        channelDescription:
            'This notification appears when any gear is running.',
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // required to keep the app awake
        eventAction: ForegroundTaskEventAction.repeat(100),
        allowWakeLock: true,
        stopWithTask: true,
        allowAutoRestart: false,
      ),
    );
    FlutterForegroundTask.setOnLockScreenVisibility(true);
    FlutterForegroundTask.initCommunicationPort();
    KnownDevices.instance.addListener(_listener);
    TriggerList.instance.addListener(_triggerListener);

    _logger.info("Init foreground service manager");
  }

  // Keep track if the noise trigger exists and register listener if it does
  void _triggerListener() {
    Trigger? noiseTrigger = TriggerList.instance.state
        .where(
          (trigger) =>
              trigger.triggerDefUUID == "9b60a160-a4f9-4dbb-b675-9958546edd34",
        )
        .firstOrNull;
    if (noiseTrigger != null) {
      noiseTrigger
        ..removeListener(_listener)
        ..addListener(_listener);
    }
  }

  Future<void> _listener() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    bool isRunning = await FlutterForegroundTask.isRunningService;
    if (_serviceTypes.isEmpty && isRunning) {
      await _stop();
    } else {
      if (isRunning) {
        await _update();
      } else {
        await _start();
      }
    }
  }

  Future<void> _start() async {
    _runningServiceTypes = _serviceTypes;
    _logger.info(
      "Starting foreground service of types ${_runningServiceTypes.keys}",
    );
    ServiceRequestResult serviceRequestResult =
        await FlutterForegroundTask.startService(
          notificationTitle: "Gear Connected",
          notificationText: "Gear is connected to The Tail Company app",
          notificationIcon: const NotificationIcon(
            metaDataName: 'com.codel1417.tailApp.notificationIcon',
          ),
          serviceTypes: _runningServiceTypes.values.toList(),
        ).onError((error, stackTrace) {
          _logger.severe("Failed to start service $error", error, stackTrace);
          return ServiceRequestFailure(error: error!);
        });
    if (serviceRequestResult is ServiceRequestFailure) {
      _logger.severe("Failed to start service ${serviceRequestResult.error}");
    }
  }

  Future<void> _stop() async {
    _logger.info(
      "Stopping foreground service of types "
      "${_runningServiceTypes.keys}",
    );
    ServiceRequestResult serviceRequestResult =
        await FlutterForegroundTask.stopService().onError((error, stackTrace) {
          _logger.severe("Failed to stop service $error", error, stackTrace);
          return ServiceRequestFailure(error: error!);
        });
    if (serviceRequestResult is ServiceRequestFailure) {
      _logger.severe("Failed to stop service ${serviceRequestResult.error}");
    }
  }

  // This should only happen if the user connects gear or turns on/off the
  // noise trigger
  // Maybe expand with connected gear counts or something
  Future<void> _update() async {
    if (!ListEquality<String>().equals(
      _runningServiceTypes.keys.toList(),
      _serviceTypes.keys.toList(),
    )) {
      _logger.info("restarting foreground service due to service type change");
      await _stop();
      await _start();
    }
  }

  Map<String, ForegroundServiceTypes> _runningServiceTypes = {};

  // Has to be a map as ForegroundServiceTypes does not support equals
  Map<String, ForegroundServiceTypes> get _serviceTypes {
    Map<String, ForegroundServiceTypes> types = {};
    if (KnownDevices.instance.connectedGear.isNotEmpty) {
      types["connectedDevice"] = ForegroundServiceTypes.connectedDevice;
    }
    if (TriggerList.instance.state
        .where(
          (trigger) =>
              trigger.triggerDefUUID ==
                  "9b60a160-a4f9-4dbb-b675-9958546edd34" &&
              trigger.enabled,
        )
        .isNotEmpty) {
      types["microphone"] = ForegroundServiceTypes.microphone;
    }
    return types;
  }
}
