import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_android_volume_keydown/flutter_android_volume_keydown.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shake/shake.dart';

import '../main.dart';
import 'Bluetooth/BluetoothManager.dart';
import 'Definitions/Action/BaseAction.dart';
import 'Definitions/Device/BaseDeviceDefinition.dart';
import 'DeviceRegistry.dart';
import 'moveLists.dart';

part 'Sensors.g.dart';

//TODO: wrap EarGear Mic and Tilt to Sensors, send enable/disable commands with toggle
//TODO: error callback to disable the sensor from the trigger definition, such as when permission is denied
@JsonSerializable(explicitToJson: true)
class Trigger {
  late String triggerDef;
  @JsonKey(includeToJson: false, includeFromJson: false)
  TriggerDefinition? triggerDefinition;
  bool _enabled = false;
  Set<DeviceType> _deviceType = {DeviceType.tail, DeviceType.ears, DeviceType.wings};

  Set<DeviceType> get deviceType => _deviceType;

  set deviceType(Set<DeviceType> value) {
    _deviceType = value;
    if (_enabled) {
      triggerDefinition?.onDisable();
      triggerDefinition?.onEnable(actions, deviceType);
    }
  }

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (triggerDefinition?.requiredPermission != null) {
      triggerDefinition?.requiredPermission?.request().then((permissionStatus) {
        if (permissionStatus == PermissionStatus.granted) {
          _enabled = value;
          if (_enabled) {
            triggerDefinition?.onEnable(actions, deviceType);
          } else {
            triggerDefinition?.onDisable();
          }
        }
      });
    } else {
      _enabled = value;
      if (_enabled) {
        triggerDefinition?.onEnable(actions, deviceType);
      } else {
        triggerDefinition?.onDisable();
      }
    }
  }

  List<TriggerAction> actions = [];

  Trigger(this.triggerDef) {
    //actions.addAll(triggerDefinition?.actionTypes.map((e) => TriggerAction(e)));
  }

  Trigger.trigDef(this.triggerDefinition) {
    triggerDef = triggerDefinition!.name;
    actions.addAll(triggerDefinition!.actionTypes.map((e) => TriggerAction(e)));
  }

  factory Trigger.fromJson(Map<String, dynamic> json) => _$TriggerFromJson(json);

  Map<String, dynamic> toJson() => _$TriggerToJson(this);
}

abstract class TriggerDefinition implements Comparable<TriggerDefinition> {
  late String name;
  late String description;
  late Widget icon;
  Ref ref;

  Future<void> onEnable(List<TriggerAction> actions, Set<DeviceType> deviceType);

  Future<void> onDisable();

  Permission? requiredPermission;
  late List<String> actionTypes;

  TriggerDefinition(this.ref);

  Future<void> sendCommands(Set<DeviceType> deviceType, BaseAction? baseAction, Ref ref) async {
    if (baseAction == null) {
      return;
    }
    Map<String, BaseStatefulDevice> knownDevices = ref.read(knownDevicesProvider);
    List<BaseStatefulDevice> devices = knownDevices.values.where((BaseStatefulDevice element) => deviceType.contains(element.baseDeviceDefinition.deviceType)).toList();

    for (BaseStatefulDevice baseStatefulDevice in devices) {
      runAction(baseAction, baseStatefulDevice);
    }
  }

  @override
  int compareTo(TriggerDefinition other) {
    return name.compareTo(other.name);
  }
}

class WalkingTriggerDefinition extends TriggerDefinition {
  Stream<PedestrianStatus>? pedestrianStatusStream;
  Stream<StepCount>? stepCountStream;

  WalkingTriggerDefinition(super.ref) {
    super.name = "Walking";
    super.description = "Trigger an action on walking";
    super.icon = const Icon(Icons.directions_walk);
    super.requiredPermission = Permission.activityRecognition;
    super.actionTypes = ["Walking", "Stopped", "Even Step", "Odd Step", "Step"];
  }

  @override
  Future<void> onDisable() async {
    pedestrianStatusStream = null;
    stepCountStream = null;
  }

  @override
  Future<void> onEnable(List<TriggerAction> actions, Set<DeviceType> deviceType) async {
    pedestrianStatusStream = Pedometer.pedestrianStatusStream;
    stepCountStream = Pedometer.stepCountStream;
    pedestrianStatusStream?.listen((PedestrianStatus event) {
      Flogger.i("PedestrianStatus:: ${event.status}");
      if (event.status == "Walking") {
        TriggerAction action = actions.firstWhere((TriggerAction element) => element.name == "Walking");
        sendCommands(deviceType, action.action, ref);
      } else if (event.status == "Stopped") {
        TriggerAction action = actions.firstWhere((TriggerAction element) => element.name == "Stopped");
        sendCommands(deviceType, action.action, ref);
      }
    });
    stepCountStream?.listen((StepCount event) {
      Flogger.d("StepCount:: ${event.steps}");
      TriggerAction action = actions.firstWhere((TriggerAction element) => element.name == "Step");
      sendCommands(deviceType, action.action, ref);
      if (event.steps.isEven) {
        TriggerAction action = actions.firstWhere((TriggerAction element) => element.name == "Even Step");
        sendCommands(deviceType, action.action, ref);
      } else {
        TriggerAction action = actions.firstWhere((TriggerAction element) => element.name == "Odd Step");
        sendCommands(deviceType, action.action, ref);
      }
    });
  }
}

class CoverTriggerDefinition extends TriggerDefinition {
  Stream<int>? proximityStream;

  CoverTriggerDefinition(super.ref) {
    super.name = "Cover";
    super.description = "Trigger an action by covering the proximity sensor";
    super.icon = const Icon(Icons.sensors);
    super.requiredPermission = null;
    super.actionTypes = ["Near", "Far"];
  }

  @override
  Future<void> onDisable() async {
    proximityStream = null;
  }

  @override
  Future<void> onEnable(List<TriggerAction> actions, Set<DeviceType> deviceType) async {
    proximityStream = ProximitySensor.events;
    proximityStream?.listen((int event) {
      Flogger.d("CoverEvent:: $event");
      if (event >= 1) {
        TriggerAction action = actions.firstWhere((TriggerAction element) => element.name == "Near");
        sendCommands(deviceType, action.action, ref);
      } else if (event == 0) {
        TriggerAction action = actions.firstWhere((TriggerAction element) => element.name == "Far");
        sendCommands(deviceType, action.action, ref);
      }
    });
  }
}

class VolumeButtonTriggerDefinition extends TriggerDefinition {
  StreamSubscription<HardwareButton>? subscription;

  VolumeButtonTriggerDefinition(super.ref) {
    super.name = "Volume Buttons";
    super.description = "Trigger an action by pressing the volume button";
    super.icon = const Icon(Icons.volume_up);
    super.requiredPermission = null;
    super.actionTypes = ["Volume Up", "Volume Down"];
  }

  @override
  Future<void> onDisable() async {
    if (subscription != null) {
      subscription!.cancel();
    }
    subscription = null;
  }

  @override
  Future<void> onEnable(List<TriggerAction> actions, Set<DeviceType> deviceType) async {
    subscription = FlutterAndroidVolumeKeydown.stream.listen((event) {
      Flogger.d("Volume press detected:${event.name}");
      if (event == HardwareButton.volume_down) {
        TriggerAction action = actions.firstWhere((TriggerAction element) => element.name == "Volume Up");
        sendCommands(deviceType, action.action, ref);
      } else if (event == HardwareButton.volume_up) {
        TriggerAction action = actions.firstWhere((TriggerAction element) => element.name == "Volume Down");
        sendCommands(deviceType, action.action, ref);
      }
    });
  }
}

class ShakeTriggerDefinition extends TriggerDefinition {
  ShakeDetector? detector;

  ShakeTriggerDefinition(super.ref) {
    super.name = "Shake";
    super.description = "Trigger an action by shaking your device";
    super.icon = const Icon(Icons.vibration);
    super.requiredPermission = null;
    super.actionTypes = ["Shake"];
  }

  @override
  Future<void> onDisable() async {
    detector?.stopListening();
    detector = null;
  }

  @override
  Future<void> onEnable(List<TriggerAction> actions, Set<DeviceType> deviceType) async {
    detector = ShakeDetector.waitForStart(onPhoneShake: () {
      Flogger.d("Shake Detected");
      TriggerAction action = actions.firstWhere((TriggerAction element) => element.name == "Shake");
      sendCommands(deviceType, action.action, ref);
    });
    detector?.startListening();
  }
}

class TailProximityTriggerDefinition extends TriggerDefinition {
  Stream<DiscoveredDevice>? btStream;

  TailProximityTriggerDefinition(super.ref) {
    super.name = "Proximity";
    super.description = "Trigger an action if gear is nearby";
    super.icon = const Icon(Icons.bluetooth_connected);
    super.requiredPermission = Permission.bluetoothScan;
    super.actionTypes = ["Nearby Gear"];
  }

  @override
  Future<void> onDisable() async {
    btStream = null;
  }

  @override
  Future<void> onEnable(List<TriggerAction> actions, Set<DeviceType> deviceType) async {
    btStream = ref.read(reactiveBLEProvider).scanForDevices(withServices: DeviceRegistry.getAllIds()).where((event) => !ref.read(knownDevicesProvider).keys.contains(event.id));
    btStream?.listen((DiscoveredDevice device) {
      Flogger.d("TailProximityTriggerDefinition:: $device");
      TriggerAction action = actions.firstWhere((TriggerAction element) => element.name == "Nearby Gear");
      sendCommands(deviceType, action.action, ref);
    });
  }
}

@JsonSerializable(explicitToJson: true)
class TriggerAction {
  String name;
  BaseAction? action;

  TriggerAction(this.name);

  factory TriggerAction.fromJson(Map<String, dynamic> json) => _$TriggerActionFromJson(json);

  Map<String, dynamic> toJson() => _$TriggerActionToJson(this);
}

@Riverpod(keepAlive: true, dependencies: [TriggerDefinitionList])
class TriggerList extends _$TriggerList {
  @override
  List<Trigger> build() {
    List<String>? stringList = prefs.getStringList("triggers");
    if (stringList != null) {
      return stringList.map((e) {
        Trigger trigger = Trigger.fromJson(jsonDecode(e));
        Trigger trigger2 = Trigger.trigDef(ref.read(triggerDefinitionListProvider).firstWhere((element) => element.name == trigger.triggerDef));
        trigger2.actions = trigger.actions;
        trigger2.enabled = trigger2.enabled;
        trigger2.deviceType = trigger.deviceType;
        return trigger2;
      }).toList();
    } else {
      return [];
    }
  }

  void add(Trigger trigger) {
    state.add(trigger);
    store();
  }

  void remove(Trigger trigger) {
    trigger.enabled = false;
    state.remove(trigger);
    store();
  }

  Future<void> store() async {
    Flogger.i("Storing triggers");
    await prefs.setStringList(
        "triggers",
        state.map((e) {
          return const JsonEncoder.withIndent("    ").convert(e.toJson());
        }).toList());
  }
}

// Defines what triggers show in the UI
@Riverpod(keepAlive: true)
class TriggerDefinitionList extends _$TriggerDefinitionList {
  @override
  List<TriggerDefinition> build() {
    List<TriggerDefinition> triggerDefinitions = [
      WalkingTriggerDefinition(ref),
      CoverTriggerDefinition(ref),
      TailProximityTriggerDefinition(ref),
      ShakeTriggerDefinition(ref),
    ];
    if (Platform.isAndroid) {
      triggerDefinitions.add(VolumeButtonTriggerDefinition(ref));
    }
    triggerDefinitions.sort();
    return triggerDefinitions;
  }

  //Filter by unused sensors
  List<TriggerDefinition> get() => ref.read(triggerListProvider).map((Trigger e) => e.triggerDefinition!).toSet().difference(state.toSet()).toList();
}
