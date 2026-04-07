import 'dart:async';
import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart' as log;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../constants.dart';
import '../Definitions/Device/device_definition.dart';
import '../Definitions/Device/device_type_enum.dart';
import '../Definitions/Device/stored_device.dart';
import '../device_registry.dart';
import '../logging_wrappers.dart';

final log.Logger bluetoothLog = log.Logger('Bluetooth');

class KnownDevices with ChangeNotifier {
  late BuiltMap<String, StatefulDevice> _state;

  BuiltMap<String, StatefulDevice> get state => _state;

  //https://stackoverflow.com/questions/12649573/how-do-you-build-a-singleton-in-dart
  static final KnownDevices instance = KnownDevices._internal();

  KnownDevices._internal() {
    BuiltList<StoredDevice> storedDevices = Hive.box<StoredDevice>(
      devicesBox,
    ).values.toBuiltList();

    // after all device entries are loaded, close the box. The box will be
    // re-opened as a lazy box to save ram
    Hive.box<StoredDevice>(devicesBox).close();
    Map<String, StatefulDevice> results = {};
    try {
      if (storedDevices.isNotEmpty) {
        for (StoredDevice e in storedDevices) {
          // We don't care for stored demo gear
          if (e.btMACAddress.contains(demoGearPrefix)) {
            continue;
          }
          DeviceDefinition deviceDefinition = DeviceRegistry.getByUUID(
            e.deviceDefinitionUUID,
          );
          StatefulDevice statefulDevice = StatefulDevice(deviceDefinition, e);
          results[e.btMACAddress] = statefulDevice;
        }
      }
    } catch (e, s) {
      bluetoothLog.severe("Unable to load stored devices due to $e", e, s);
    }
    _state = BuiltMap(results);

    //register listeners
    _onDevicePaired();
  }

  Future<void> add(StatefulDevice statefulDevice) async {
    _state = _state.rebuild(
      (p0) => p0[statefulDevice.storedDevice.btMACAddress] = statefulDevice,
    );
    await store();
  }

  Future<void> remove(String id) async {
    _state = _state.rebuild((p0) => p0.remove(id));
    await store();
  }

  Future<void> store() async {
    LazyBox<StoredDevice> lazyBox = await Hive.openLazyBox<StoredDevice>(
      devicesBox,
    );
    await lazyBox.clear();
    await lazyBox.addAll(state.values.map((e) => e.storedDevice));
    _onDevicePaired();
    _notify();
  }

  Future<void> removeDevGear() async {
    _state = _state.rebuild(
      (p0) => p0.removeWhere((p0, p1) => p0.contains(demoGearPrefix)),
    );
    await store();
  }

  // Helpers for gear connected

  void _notify() {
    notifyListeners();
  }

  BuiltList<StatefulDevice> get connectedGear {
    return KnownDevices.instance.state.values
        .where(
          (element) =>
              element.deviceConnectionState.value ==
              ConnectivityState.connected,
        )
        .where(
          // don't consider gear connected until services have been discovered
          (element) => element.bluetoothUartService.value != null,
        )
        .toBuiltList();
  }

  bool get isAllGearConnected {
    return connectedGear.length == state.length;
  }

  BuiltSet<DeviceType> get connectedGearTypes {
    return connectedGear.map((e) => e.deviceDefinition.deviceType).toBuiltSet();
  }

  BuiltList<StatefulDevice> getKnownGearForType(
    BuiltSet<DeviceType> deviceTypes,
  ) {
    return state.values
        .where(
          (element) =>
              deviceTypes.contains(element.deviceDefinition.deviceType),
        )
        .toBuiltList();
  }

  BuiltList<StatefulDevice> getConnectedGearForType(
    BuiltSet<DeviceType> deviceTypes,
  ) {
    return connectedGear
        .where(
          (element) =>
              deviceTypes.contains(element.deviceDefinition.deviceType),
        )
        .toBuiltList();
  }

  BuiltList<StatefulDevice> get connectedIdleGear {
    return connectedGear
        .where(
          (element) => element.deviceState.value == DeviceMoveState.standby,
        )
        .toBuiltList();
  }

  BuiltList<StatefulDevice> getConnectedIdleGearForType(
    BuiltSet<DeviceType> deviceTypes,
  ) {
    return connectedIdleGear
        .where(
          (element) =>
              deviceTypes.contains(element.deviceDefinition.deviceType),
        )
        .toBuiltList();
  }

  void _onDevicePaired() {
    for (StatefulDevice statefulDevice in state.values) {
      statefulDevice.deviceConnectionState
        ..removeListener(_notify)
        ..addListener(_notify);
      statefulDevice.deviceConnectionState
        ..removeListener(_wakelock)
        ..addListener(_wakelock);
      statefulDevice.deviceConnectionState
        ..removeListener(_foregroundService)
        ..addListener(_foregroundService);
      statefulDevice.bluetoothUartService
        ..removeListener(_notify)
        ..addListener(_notify);
      statefulDevice.storedDevice
        ..removeListener(_notify)
        ..addListener(_notify);
      //refresh on moves
      statefulDevice.deviceState
        ..removeListener(_notify)
        ..addListener(_notify);
    }
  }

  Future<void> _wakelock() async {
    if (HiveProxy.getOrDefault(
          settings,
          keepAwake,
          defaultValue: keepAwakeDefault,
        ) &&
        connectedGear.isNotEmpty) {
      WakelockPlus.enable();
    } else if (connectedGear.isEmpty) {
      WakelockPlus.disable();
    }
  }

  Future<void> _foregroundService() async {
    if (!Platform.isAndroid) {
      return;
    }
    if (connectedGear.isNotEmpty) {
      //start foreground service on device connected. Library handles duplicate start calls
      //TODO: translate strings
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'foreground_service',
          channelName: 'Gear Connected',
          channelDescription:
              'This notification appears when any gear is running.',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        foregroundTaskOptions: ForegroundTaskOptions(
          // required to keep the app awake
          eventAction: ForegroundTaskEventAction.repeat(100),
          allowWakeLock: true,
        ),
      );
      FlutterForegroundTask.startService(
        notificationTitle: "Gear Connected",
        notificationText: "Gear is connected to The Tail Company app",
        notificationIcon: const NotificationIcon(
          metaDataName: 'com.codel1417.tailApp.notificationIcon',
        ),
      );
      FlutterForegroundTask.setOnLockScreenVisibility(true);
    } else {
      FlutterForegroundTask.stopService();
    }
  }
}

class IsGearMoveRunning extends ChangeNotifier {
  static final IsGearMoveRunning instance = IsGearMoveRunning._internal();

  @override
  IsGearMoveRunning._internal() {
    KnownDevices.instance
      ..removeListener(_notify)
      ..addListener(_notify);
    for (StatefulDevice statefulDevice in KnownDevices.instance.state.values) {
      statefulDevice.deviceState
        ..removeListener(_notify)
        ..addListener(_notify);
    }
  }

  bool getState(BuiltSet<DeviceType> deviceTypes) {
    return KnownDevices.instance
        .getConnectedGearForType(deviceTypes)
        .where(
          (element) => element.deviceState.value == DeviceMoveState.runAction,
        )
        .isNotEmpty;
  }

  void _notify() {
    notifyListeners();
  }
}
