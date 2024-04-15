import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_android_volume_keydown/flutter_android_volume_keydown.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:shake/shake.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_message.dart';
import 'package:tail_app/Backend/action_registry.dart';

import '../Frontend/intn_defs.dart';
import '../constants.dart';
import 'Bluetooth/bluetooth_manager.dart';
import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/device_definition.dart';
import 'device_registry.dart';
import 'move_lists.dart';

part 'sensors.g.dart';

@HiveType(typeId: 2)
class Trigger extends ChangeNotifier {
  @HiveField(1)
  late String triggerDefUUID;
  TriggerDefinition? triggerDefinition;
  bool _enabled = false;
  @HiveField(4)
  String uuid;

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (_enabled) {
      triggerDefinition?.deviceTypes[uuid] = _deviceType.toSet();
      triggerDefinition?.actions[uuid] = actions;
      triggerDefinition?.addListener(triggerDefListener);
      triggerDefinition?.enabled = value;
    } else {
      triggerDefinition?.deviceTypes.remove(uuid);
      triggerDefinition?.actions.remove(uuid);
      triggerDefinition?.removeListener(triggerDefListener);
      triggerDefinition?.enabled = value;
    }
  }

  void triggerDefListener() {
    if (triggerDefinition?.enabled != _enabled && _enabled) {
      enabled = false;
    }
  }

  @HiveField(2, defaultValue: [DeviceType.tail, DeviceType.ears, DeviceType.wings])
  List<DeviceType> _deviceType = [DeviceType.tail, DeviceType.ears, DeviceType.wings];

  List<DeviceType> get deviceType => _deviceType;

  set deviceType(List<DeviceType> value) {
    _deviceType = value;
    if (_enabled) {
      triggerDefinition?.deviceTypes[uuid] = _deviceType.toSet();
    }
  }

  @HiveField(3)
  List<TriggerAction> actions = [];

  Trigger(this.triggerDefUUID, this.uuid) {
    // called by hive when loading object
  }

  Trigger.trigDef(this.triggerDefinition, this.uuid) {
    triggerDefUUID = triggerDefinition!.uuid;
    actions.addAll(triggerDefinition!.actionTypes.map((e) => TriggerAction(e.uuid)));
  }
}

@Riverpod()
BaseAction? getActionFromUUID(GetActionFromUUIDRef ref, String? uuid) {
  if (uuid == null) {
    return null;
  }
  List<BaseAction> actions = List.from(ActionRegistry.allCommands);
  actions.addAll(ref.read(moveListsProvider));
  return actions.where((element) => element.uuid == uuid).firstOrNull;
}

abstract class TriggerDefinition extends ChangeNotifier implements Comparable<TriggerDefinition> {
  late String name;
  late String description;
  late Widget icon;
  late String uuid;
  Map<String, Set<DeviceType>> deviceTypes = {};
  Map<String, List<TriggerAction>> actions = {};
  bool _enabled = false;

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (value == _enabled) {
      return;
    }
    if (!value && actions.isEmpty) {
      _enabled = false;
      onDisable();
    } else if (requiredPermission != null && value) {
      requiredPermission?.request().then((permissionStatus) {
        if (permissionStatus == PermissionStatus.granted) {
          _enabled = true;
          onEnable();
        }
        notifyListeners();
      });
    } else if (value) {
      _enabled = true;
      onEnable();
    }
    notifyListeners();
  }

  Ref ref;

  Future<void> onEnable();

  Future<void> onDisable();

  Permission? requiredPermission;
  late List<TriggerActionDef> actionTypes;

  TriggerDefinition(this.ref);

  Future<void> sendCommands(String name, Ref ref) async {
    actions.values.flattened.where((e) => actionTypes.firstWhere((element) => element.name == name).uuid == e.uuid).forEach(
      (TriggerAction triggerAction) async {
        if (triggerAction.isActive.value) {
          // 15 second cooldown between moves
          return;
        }
        BaseAction? baseAction = ref.read(getActionFromUUIDProvider(triggerAction.action));
        if (baseAction == null) {
          return;
        }
        triggerAction.isActive.value = true;
        Map<String, BaseStatefulDevice> knownDevices = ref.read(knownDevicesProvider);
        List<BaseStatefulDevice> devices = knownDevices.values.where((BaseStatefulDevice element) => deviceTypes.values.flattened.toSet().contains(element.baseDeviceDefinition.deviceType)).where((element) => element.deviceState.value == DeviceState.standby).toList();
        for (BaseStatefulDevice baseStatefulDevice in List.of(devices)..shuffle()) {
          if (SentryHive.box(settings).get(kitsuneModeToggle, defaultValue: kitsuneModeDefault)) {
            await Future.delayed(Duration(milliseconds: Random().nextInt(kitsuneDelayRange)));
          }
          runAction(baseAction, baseStatefulDevice);
        }
        await Future.delayed(const Duration(seconds: 15));
        triggerAction.isActive.value = false;
      },
    );
  }

  @override
  int compareTo(TriggerDefinition other) {
    return name.compareTo(other.name);
  }
}

class WalkingTriggerDefinition extends TriggerDefinition {
  StreamSubscription<PedestrianStatus>? pedestrianStatusStream;
  StreamSubscription<StepCount>? stepCountStream;

  WalkingTriggerDefinition(super.ref) {
    super.name = triggerWalkingTitle();
    super.description = triggerWalkingDescription();
    super.icon = const Icon(Icons.directions_walk);
    super.requiredPermission = Permission.activityRecognition;
    super.uuid = "ee9379e2-ec4f-40bb-8674-fd223a6edfda";
    super.actionTypes = [TriggerActionDef("Walking", triggerWalkingTitle(), "77d22961-5a69-465a-bd27-5cf5508d10a6"), TriggerActionDef("Stopped", triggerWalkingStopped(), "7424097d-ba24-4d85-b963-bf58e85e289d"), TriggerActionDef("Step", triggerWalkingStep(), "c82b04ba-7d2e-475a-90ba-3d354e5b8ef0")];
  }

  @override
  Future<void> onDisable() async {
    pedestrianStatusStream?.cancel();
    stepCountStream?.cancel();
    pedestrianStatusStream = null;
    stepCountStream = null;
  }

  @override
  Future<void> onEnable() async {
    if (pedestrianStatusStream != null) {
      return;
    }
    pedestrianStatusStream = Pedometer.pedestrianStatusStream.listen(
      (PedestrianStatus event) {
        Flogger.i("PedestrianStatus:: ${event.status}");
        if (event.status == "walking") {
          sendCommands("Walking", ref);
        } else if (event.status == "stopped") {
          sendCommands("Stopped", ref);
        }
      },
    );
    stepCountStream = Pedometer.stepCountStream.listen(
      (StepCount event) {
        Flogger.d("StepCount:: ${event.steps}");
        sendCommands("Step", ref);
      },
    );
  }
}

class CoverTriggerDefinition extends TriggerDefinition {
  StreamSubscription<int>? proximityStream;

  CoverTriggerDefinition(super.ref) {
    super.name = triggerCoverTitle();
    super.description = triggerCoverDescription();
    super.icon = const Icon(Icons.sensors);
    super.requiredPermission = null;
    super.uuid = "a390cd3c-c314-44c1-b89d-57be75bfc3a2";
    super.actionTypes = [TriggerActionDef("Near", triggerCoverNear(), "bf3d0ce0-15c0-46db-95ce-e2cd6a5ecd0f"), TriggerActionDef("Far", triggerCoverFar(), "d121e4a8-a12d-4f0a-8348-89c62eb72a7a")];
  }

  @override
  Future<void> onDisable() async {
    proximityStream?.cancel();
    proximityStream = null;
  }

  @override
  Future<void> onEnable() async {
    if (proximityStream != null) {
      return;
    }
    proximityStream = ProximitySensor.events.listen((int event) {
      Flogger.d("CoverEvent:: $event");
      if (event >= 1) {
        sendCommands("Near", ref);
      } else if (event == 0) {
        sendCommands("Far", ref);
      }
    });
  }
}

class EarMicTriggerDefinition extends TriggerDefinition {
  List<StreamSubscription<List<int>>?> rxSubscriptions = [];
  ProviderSubscription<Map<String, BaseStatefulDevice>>? deviceRefSubscription;

  EarMicTriggerDefinition(super.ref) {
    super.name = triggerEarMicTitle();
    super.description = triggerEarMicDescription();
    super.icon = const Icon(Icons.mic);
    super.requiredPermission = null;
    super.uuid = "3bbd2306-ea53-44f5-a930-474ff23ec23d";
    super.actionTypes = [
      TriggerActionDef("Sound", triggerEarMicSound(), "839d8978-7b77-4ccb-b23f-28144bf95453"),
    ];
  }

  @override
  Future<void> onDisable() async {
    deviceRefSubscription?.close();
    ref.read(knownDevicesProvider).values.where((element) => element.baseDeviceDefinition.deviceType == DeviceType.ears).forEach((element) {
      element.deviceConnectionState.removeListener(onDeviceConnected);
    });
    for (var element in rxSubscriptions) {
      element?.cancel();
    }
    rxSubscriptions = [];
    ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == ConnectivityState.connected && element.baseDeviceDefinition.deviceType == DeviceType.ears).forEach((element) {
      element.commandQueue.addCommand(BluetoothMessage(message: "ENDLISTEN", device: element, priority: Priority.low, responseMSG: "LISTEN OFF", type: Type.system));
    });
  }

  @override
  Future<void> onEnable() async {
    if (rxSubscriptions.isNotEmpty) {
      return;
    }
    ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == ConnectivityState.connected && element.baseDeviceDefinition.deviceType == DeviceType.ears).forEach((element) {
      element.commandQueue.addCommand(BluetoothMessage(message: "LISTEN FULL", device: element, priority: Priority.low, type: Type.system));
    });
    //add listeners on new device paired
    deviceRefSubscription = ref.listen(knownDevicesProvider, (previous, next) {
      onDeviceConnected();
    });
  }

  Future<void> onDeviceConnected() async {
    ref.read(knownDevicesProvider).values.where((element) => element.baseDeviceDefinition.deviceType == DeviceType.ears).map((e) {
      e.deviceConnectionState.removeListener(onDeviceConnected);
      e.deviceConnectionState.addListener(onDeviceConnected);
    });
    listen();
  }

  Future<void> listen() async {
    //cancel old subscriptions
    if (rxSubscriptions.isNotEmpty) {
      for (var element in rxSubscriptions) {
        element?.cancel();
      }
    }
    //Store the current streams to keep them open
    rxSubscriptions = ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == ConnectivityState.connected && element.baseDeviceDefinition.deviceType == DeviceType.ears).map(
      (element) {
        element.commandQueue.addCommand(BluetoothMessage(message: "LISTEN FULL", device: element, priority: Priority.low, type: Type.system));
        return element.rxCharacteristicStream?.listen(
          (event) {
            String msg = const Utf8Decoder().convert(event);
            if (msg.contains("LISTEN_FULL BANG")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              sendCommands("Sound", ref);
            }
          },
        );
      },
    ).toList();
  }
}

class EarTiltTriggerDefinition extends TriggerDefinition {
  List<StreamSubscription<List<int>>?> rxSubscriptions = [];
  ProviderSubscription<Map<String, BaseStatefulDevice>>? deviceRefSubscription;

  EarTiltTriggerDefinition(super.ref) {
    super.name = triggerEarTiltTitle();
    super.description = triggerEarTiltDescription();
    super.icon = const Icon(Icons.threed_rotation);
    super.requiredPermission = null;
    super.uuid = "93d72792-145e-4b56-92b9-3279a5e7d839";
    super.actionTypes = [
      TriggerActionDef("Left", triggerEarTiltLeft(), "0137efd7-5a6f-4ac3-8956-cd75e11e6fd4"),
      TriggerActionDef("Right", triggerEarTiltRight(), "21d233cc-aeaf-4096-a997-7070e38a8801"),
      TriggerActionDef("Forward", triggerEarTiltForward(), "7e32987a-588c-4969-a589-d95f94262da7"),
      TriggerActionDef("Backward", triggerEarTiltBackward(), "a4ad813e-a867-4c73-8e73-c4a294829667"),
    ];
  }

  @override
  Future<void> onDisable() async {
    deviceRefSubscription?.close();
    ref.read(knownDevicesProvider).values.where((element) => element.baseDeviceDefinition.deviceType == DeviceType.ears).forEach((element) {
      element.deviceConnectionState.removeListener(onDeviceConnected);
    });
    for (var element in rxSubscriptions) {
      element?.cancel();
    }
    rxSubscriptions = [];
    ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == ConnectivityState.connected && element.baseDeviceDefinition.deviceType == DeviceType.ears).forEach((element) {
      element.commandQueue.addCommand(BluetoothMessage(message: "ENDTILTMODE", device: element, priority: Priority.low, type: Type.system));
    });
  }

  @override
  Future<void> onEnable() async {
    if (rxSubscriptions.isNotEmpty) {
      return;
    }
    ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == ConnectivityState.connected && element.baseDeviceDefinition.deviceType == DeviceType.ears).forEach((element) {
      element.commandQueue.addCommand(BluetoothMessage(message: "TILTMODE START", device: element, priority: Priority.low, type: Type.system));
    });
    //add listeners on new device paired
    deviceRefSubscription = ref.listen(knownDevicesProvider, (previous, next) {
      onDeviceConnected();
    });
  }

  Future<void> onDeviceConnected() async {
    ref.read(knownDevicesProvider).values.where((element) => element.baseDeviceDefinition.deviceType == DeviceType.ears).map((e) {
      e.deviceConnectionState.removeListener(onDeviceConnected);
      e.deviceConnectionState.addListener(onDeviceConnected);
    });
    listen();
  }

  Future<void> listen() async {
    //cancel old subscriptions
    if (rxSubscriptions.isNotEmpty) {
      for (var element in rxSubscriptions) {
        element?.cancel();
      }
    }
    //Store the current streams to keep them open
    rxSubscriptions = ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == ConnectivityState.connected && element.baseDeviceDefinition.deviceType == DeviceType.ears).map(
      (element) {
        element.commandQueue.addCommand(BluetoothMessage(message: "TILTMODE START", device: element, priority: Priority.low, type: Type.system));
        return element.rxCharacteristicStream?.listen(
          (event) {
            String msg = const Utf8Decoder().convert(event);
            if (msg.contains("TILT LEFT")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              sendCommands("Left", ref);
            } else if (msg.contains("TILT RIGHT")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              sendCommands("Right", ref);
            } else if (msg.contains("TILT FORWARD")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              sendCommands("Forward", ref);
            } else if (msg.contains("TILT BACKWARD")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              sendCommands("Backward", ref);
            }
          },
        );
      },
    ).toList();
  }
}

class VolumeButtonTriggerDefinition extends TriggerDefinition {
  StreamSubscription<HardwareButton>? subscription;

  VolumeButtonTriggerDefinition(super.ref) {
    super.name = triggerVolumeButtonTitle();
    super.description = triggerVolumeButtonDescription();
    super.icon = const Icon(Icons.volume_up);
    super.requiredPermission = null;
    super.uuid = "26c1eaef-5976-43cb-bc68-f67cfb29de51";
    super.actionTypes = [TriggerActionDef("Volume Up", triggerVolumeButtonVolumeUp(), "834a9bef-9ae2-4623-81fa-bbead69eb28e"), TriggerActionDef("Volume Down", triggerVolumeButtonVolumeDown(), "2972aa14-33de-4d4f-ac67-4f572306b5c4")];
  }

  @override
  Future<void> onDisable() async {
    subscription?.cancel();
    subscription = null;
  }

  @override
  Future<void> onEnable() async {
    if (subscription != null) {
      return;
    }
    subscription = FlutterAndroidVolumeKeydown.stream.listen((event) {
      Flogger.d("Volume press detected:${event.name}");
      if (event == HardwareButton.volume_down) {
        sendCommands("Volume Up", ref);
      } else if (event == HardwareButton.volume_up) {
        sendCommands("Volume Down", ref);
      }
    });
  }
}

class ShakeTriggerDefinition extends TriggerDefinition {
  ShakeDetector? detector;

  ShakeTriggerDefinition(super.ref) {
    super.name = triggerShakeTitle();
    super.description = triggerShakeDescription();
    super.icon = const Icon(Icons.vibration);
    super.requiredPermission = null;
    super.uuid = "059d445a-35fe-45a3-8d3d-de8bce213a05";
    super.actionTypes = [TriggerActionDef("Shake", triggerShakeTitle(), "b84b4c7a-2330-4ede-82f4-dca7b6e74b0a")];
  }

  @override
  Future<void> onDisable() async {
    detector?.stopListening();
    detector = null;
  }

  @override
  Future<void> onEnable() async {
    if (detector != null) {
      return;
    }
    detector = ShakeDetector.waitForStart(onPhoneShake: () {
      Flogger.d("Shake Detected");
      sendCommands("Shake", ref);
    });
    detector?.startListening();
  }
}

class TailProximityTriggerDefinition extends TriggerDefinition {
  StreamSubscription<DiscoveredDevice>? btConnectStream;
  Timer? btnearbyCooldown;

  TailProximityTriggerDefinition(super.ref) {
    super.name = triggerProximityTitle();
    super.description = triggerProximityDescription();
    super.icon = const Icon(Icons.bluetooth_connected);
    super.requiredPermission = Permission.bluetoothScan;
    super.uuid = "5418e7a5-850b-482e-ba35-163564c848ab";
    super.actionTypes = [TriggerActionDef("Nearby Gear", triggerProximityTitle(), "e78a749b-8b78-47df-a5a1-1ed365292214")];
  }

  @override
  Future<void> onDisable() async {
    if (ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).isEmpty) {
      btConnectStream?.cancel();
      btConnectStream = null;
    }
  }

  @override
  Future<void> onEnable() async {
    if (btConnectStream != null) {
      return;
    }
    btConnectStream = ref.read(reactiveBLEProvider).scanForDevices(withServices: DeviceRegistry.getAllIds()).where((event) => !ref.read(knownDevicesProvider).keys.contains(event.id)).listen(
      (DiscoveredDevice device) {
        if (btnearbyCooldown != null && btnearbyCooldown!.isActive) {
          return;
        }

        sendCommands("Nearby Gear", ref);

        btnearbyCooldown = Timer(const Duration(seconds: 30), () {});
      },
    );
  }
}

class TriggerActionDef {
  //Store in trigger def instance
  String name;
  String translated; //Translated name
  String uuid; // uuid
  TriggerActionDef(this.name, this.translated, this.uuid);

  @override
  bool operator ==(Object other) => identical(this, other) || other is TriggerActionDef && runtimeType == other.runtimeType && uuid == other.uuid;

  @override
  int get hashCode => uuid.hashCode;
}

@HiveType(typeId: 8)
class TriggerAction {
  @HiveField(1)
  String uuid; //uuid matches triggerActionDef
  @HiveField(2)
  String? action;
  ValueNotifier<bool> isActive = ValueNotifier(false);

  TriggerAction(this.uuid);

  @override
  bool operator ==(Object other) => identical(this, other) || other is TriggerAction && runtimeType == other.runtimeType && uuid == other.uuid;

  @override
  int get hashCode => uuid.hashCode;
}

@Riverpod(
  keepAlive: true,
)
class TriggerList extends _$TriggerList {
  @override
  List<Trigger> build() {
    if (SentryHive.box(settings).get(firstLaunchSensors, defaultValue: firstLaunchSensorsDefault)) {
      TriggerDefinition triggerDefinition = ref.read(triggerDefinitionListProvider).where((element) => element.uuid == 'ee9379e2-ec4f-40bb-8674-fd223a6edfda').first;
      Trigger trigger = Trigger.trigDef(triggerDefinition, '91e3d421-6a52-45ab-a23e-f38e4987a8f5');
      trigger.actions.firstWhere((element) => element.uuid == '77d22961-5a69-465a-bd27-5cf5508d10a6').action = ActionRegistry.allCommands.firstWhere((element) => element.uuid == 'c53e980e-899e-4148-a13e-f57a8f9707f4').uuid;
      trigger.actions.firstWhere((element) => element.uuid == '7424097d-ba24-4d85-b963-bf58e85e289d').action = ActionRegistry.allCommands.firstWhere((element) => element.uuid == '86b13d13-b09c-46ba-a887-b40d8118b00a').uuid;
      SentryHive.box(settings).put(firstLaunchSensors, false);
      SentryHive.box<Trigger>(triggerBox)
        ..clear()
        ..addAll([trigger]);
      return [trigger];
    } else {
      return SentryHive.box<Trigger>(triggerBox).values.map((trigger) {
        Trigger trigger2 = Trigger.trigDef(ref.read(triggerDefinitionListProvider).firstWhere((element) => element.uuid == trigger.triggerDefUUID), trigger.uuid);
        trigger2.actions = trigger.actions;
        trigger2.deviceType = trigger.deviceType;
        return trigger2;
      }).toList();
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
    SentryHive.box<Trigger>(triggerBox)
      ..clear()
      ..addAll(state);
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
      EarMicTriggerDefinition(ref),
      EarTiltTriggerDefinition(ref),
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
