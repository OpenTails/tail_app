import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';

import '../../constants.dart';
import '../Device/common_device_stuffs.dart';
import '../Device/device_definition.dart';
import '../Device/device_type_enum.dart';
import '../Device/stateful/connected_gear.dart';
import '../Device/stored_device.dart';
import '../Device/tail_control_status_enum.dart';
import '../device_registry.dart';

final Logger _logger = Logger("KnownGear");

class KnownDevices with ChangeNotifier {
  Map<String, StatefulDevice> _state = {};

  Map<String, StatefulDevice> get state => Map.unmodifiable(_state);

  //https://stackoverflow.com/questions/12649573/how-do-you-build-a-singleton-in-dart
  static final KnownDevices instance = KnownDevices._internal();

  KnownDevices._internal() {
    Iterable<StoredDevice> storedDevices = Hive.box<StoredDevice>(
      devicesBox,
    ).values;

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
      _logger.severe("Unable to load stored devices due to $e", e, s);
    }
    _state = results;

    //register listeners
    _onDevicePaired();
    this
      ..removeListener(_onDevicePaired)
      ..addListener(_onDevicePaired);
  }

  /// Register and store the connected/dev gear.
  /// Must be called *BEFORE* setting any values as listeners are not
  /// registered yet
  Future<void> add(StatefulDevice statefulDevice) async {
    _state[statefulDevice.storedDevice.btMACAddress] = statefulDevice;
    await store();
  }

  Future<void> remove(String id) async {
    _state.remove(id);
    await store();
  }

  Future<void> store() async {
    _logger.info("Storing gear");
    LazyBox<StoredDevice> lazyBox = await Hive.openLazyBox<StoredDevice>(
      devicesBox,
    );
    await lazyBox.clear();
    await lazyBox.addAll(state.values.map((e) => e.storedDevice));
    _onDevicePaired();
    _notify();
  }

  Future<void> removeDevGear() async {
    _state.removeWhere((p0, p1) => p0.contains(demoGearPrefix));
    await store();
  }

  // Helpers for gear connected

  void _notify() {
    notifyListeners();
  }

  Iterable<StatefulDevice> get connectedGear {
    return _state.values
        .where(
          (element) =>
              element.deviceConnectionState.value ==
              ConnectivityState.connected,
        )
        .where(
          // don't consider gear connected until services have been discovered
          (element) => element.bluetoothUartService.value != null,
        );
  }

  bool get isGlowtipGearConnected {
    return state.values
        .map((e) => e.storedDevice.hasGlowtip)
        .any((element) => element == GlowtipStatus.glowtip);
  }

  bool get isLegacyEarsConnected {
    return connectedGear
        .where((p0) => p0.deviceDefinition.deviceType == DeviceType.ears)
        .where((p0) => p0.isTailCoNTROL.value == TailControlStatus.legacy)
        .isNotEmpty;
  }

  bool get isRgbGearConnected {
    return state.values
        .map((e) => e.storedDevice.hasRGB)
        .any((element) => element == RGBStatus.rgb);
  }

  bool get isAllGearConnected {
    return connectedGear.length == state.length;
  }

  Set<DeviceType> get connectedGearTypes {
    return connectedGear.map((e) => e.deviceDefinition.deviceType).toSet();
  }

  Iterable<StatefulDevice> getKnownGearForType(Set<DeviceType> deviceTypes) {
    return state.values.where(
      (element) => deviceTypes.contains(element.deviceDefinition.deviceType),
    );
  }

  Iterable<StatefulDevice> getConnectedGearForType(
    Set<DeviceType> deviceTypes,
  ) {
    return connectedGear.where(
      (element) => deviceTypes.contains(element.deviceDefinition.deviceType),
    );
  }

  Iterable<StatefulDevice> get connectedIdleGear {
    return connectedGear.where(
      (element) => element.deviceState.value == DeviceMoveState.standby,
    );
  }

  Iterable<StatefulDevice> getConnectedIdleGearForType(
    Set<DeviceType> deviceTypes,
  ) {
    return connectedIdleGear.where(
      (element) => deviceTypes.contains(element.deviceDefinition.deviceType),
    );
  }

  void _onDevicePaired() {
    for (StatefulDevice statefulDevice in state.values) {
      statefulDevice.deviceConnectionState
        ..removeListener(_notify)
        ..addListener(_notify);
      statefulDevice.bluetoothUartService
        ..removeListener(_notify)
        ..addListener(_notify);

      // Listen for gear color change (Probably should be handled somewhere
      // else)
      statefulDevice.storedDevice
        ..removeListener(_notify)
        ..addListener(_notify);
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

  bool getState(Set<DeviceType> deviceTypes) {
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
