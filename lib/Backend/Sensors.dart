import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_android_volume_keydown/flutter_android_volume_keydown.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
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
import 'package:tail_app/Backend/ActionRegistry.dart';
import 'package:tail_app/Backend/Bluetooth/btMessage.dart';

import '../Frontend/intnDefs.dart';
import 'Bluetooth/BluetoothManager.dart';
import 'Definitions/Action/BaseAction.dart';
import 'Definitions/Device/BaseDeviceDefinition.dart';
import 'moveLists.dart';

part 'Sensors.g.dart';

//TODO: wrap EarGear Mic and Tilt to Sensors, send enable/disable commands with toggle
//TODO: error callback to disable the sensor from the trigger definition, such as when permission is denied
@HiveType(typeId: 2)
class Trigger extends ChangeNotifier {
  @HiveField(1)
  late String triggerDef;
  TriggerDefinition? triggerDefinition;
  bool _enabled = false;
  @HiveField(2, defaultValue: [DeviceType.tail, DeviceType.ears, DeviceType.wings])
  List<DeviceType> _deviceType = [DeviceType.tail, DeviceType.ears, DeviceType.wings];

  List<DeviceType> get deviceType => _deviceType;

  set deviceType(List<DeviceType> value) {
    _deviceType = value;
    if (_enabled) {
      triggerDefinition?.onDisable();
      triggerDefinition?.onEnable();
    }
  }

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (triggerDefinition?.requiredPermission != null && value) {
      triggerDefinition?.requiredPermission?.request().then((permissionStatus) {
        if (permissionStatus == PermissionStatus.granted) {
          _enabled = true;
          triggerDefinition?.onEnable();
        } else {
          _enabled = false;
        }
        notifyListeners();
      });
    } else {
      _enabled = value;
      if (_enabled) {
        triggerDefinition?.onEnable();
      } else {
        triggerDefinition?.onDisable();
      }
    }
    notifyListeners();
  }

  @HiveField(3)
  List<TriggerAction> actions = [];

  Trigger(this.triggerDef) {
    // called by hive when loading object
  }

  Trigger.trigDef(this.triggerDefinition) {
    triggerDef = triggerDefinition!.name;
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

abstract class TriggerDefinition implements Comparable<TriggerDefinition> {
  late String name;
  late String description;
  late Widget icon;
  Ref ref;

  Future<void> onEnable();

  Future<void> onDisable();

  Permission? requiredPermission;
  late List<TriggerActionDef> actionTypes;

  TriggerDefinition(this.ref);

  Future<void> sendCommands(Set<DeviceType> deviceType, String? action, Ref ref) async {
    BaseAction? baseAction = ref.read(getActionFromUUIDProvider(action));
    if (baseAction == null) {
      return;
    }
    Map<String, BaseStatefulDevice> knownDevices = ref.read(knownDevicesProvider);
    List<BaseStatefulDevice> devices = knownDevices.values.where((BaseStatefulDevice element) => deviceType.contains(element.baseDeviceDefinition.deviceType)).where((element) => element.deviceState.value == DeviceState.standby).toList();
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
  StreamSubscription<PedestrianStatus>? pedestrianStatusStream;
  StreamSubscription<StepCount>? stepCountStream;

  WalkingTriggerDefinition(super.ref) {
    super.name = triggerWalkingTitle();
    super.description = triggerWalkingDescription();
    super.icon = const Icon(Icons.directions_walk);
    super.requiredPermission = Permission.activityRecognition;
    super.actionTypes = [
      TriggerActionDef("Walking", triggerWalkingTitle(), "77d22961-5a69-465a-bd27-5cf5508d10a6"),
      TriggerActionDef("Stopped", triggerWalkingStopped(), "7424097d-ba24-4d85-b963-bf58e85e289d"),
      TriggerActionDef("Even Step", triggerWalkingEvenStep(), "79bb5829-f147-4f97-af8a-6534264dc764"),
      TriggerActionDef("Odd Step", triggerWalkingOddStep(), "8097c565-326e-43fc-a077-bd46181a11d8"),
      TriggerActionDef("Step", triggerWalkingStep(), "c82b04ba-7d2e-475a-90ba-3d354e5b8ef0")
    ];
  }

  @override
  Future<void> onDisable() async {
    if (ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).isEmpty) {
      pedestrianStatusStream?.cancel();
      stepCountStream?.cancel();
      pedestrianStatusStream = null;
      stepCountStream = null;
    }
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
          ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Walking").uuid == e.uuid).forEach(
                (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
              );
        } else if (event.status == "stopped") {
          ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Stopped").uuid == e.uuid).forEach(
                (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
              );
        }
      },
    );
    stepCountStream = Pedometer.stepCountStream.listen(
      (StepCount event) {
        Flogger.d("StepCount:: ${event.steps}");
        ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Step").uuid == e.uuid).forEach(
              (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
            );
        if (event.steps.isEven) {
          ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Even Step").uuid == e.uuid).forEach(
                (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
              );
        } else {
          ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Odd Step").uuid == e.uuid).forEach(
                (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
              );
        }
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
    super.actionTypes = [TriggerActionDef("Near", triggerCoverNear(), "bf3d0ce0-15c0-46db-95ce-e2cd6a5ecd0f"), TriggerActionDef("Far", triggerCoverFar(), "d121e4a8-a12d-4f0a-8348-89c62eb72a7a")];
  }

  @override
  Future<void> onDisable() async {
    if (ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).isEmpty) {
      proximityStream?.cancel();
      proximityStream = null;
    }
  }

  @override
  Future<void> onEnable() async {
    if (proximityStream != null) {
      return;
    }
    proximityStream = ProximitySensor.events.listen((int event) {
      Flogger.d("CoverEvent:: $event");
      if (event >= 1) {
        ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Near").uuid == e.uuid).forEach(
              (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
            );
      } else if (event == 0) {
        ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Far").uuid == e.uuid).forEach(
              (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
            );
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
    super.actionTypes = [
      TriggerActionDef("Sound", triggerEarMicSound(), "839d8978-7b77-4ccb-b23f-28144bf95453"),
    ];
  }

  @override
  Future<void> onDisable() async {
    if (ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).isEmpty) {
      deviceRefSubscription?.close();
      ref.read(knownDevicesProvider).values.where((element) => element.baseDeviceDefinition.deviceType == DeviceType.ears).forEach((element) {
        element.deviceConnectionState.removeListener(onDeviceConnected);
      });
      for (var element in rxSubscriptions) {
        element?.cancel();
      }
      rxSubscriptions = [];
      ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected && element.baseDeviceDefinition.deviceType == DeviceType.ears).forEach((element) {
        element.commandQueue.addCommand(BluetoothMessage.response("ENDLISTEN", element, Priority.normal, "LISTEN OFF"));
      });
    }
  }

  @override
  Future<void> onEnable() async {
    if (rxSubscriptions.isNotEmpty) {
      return;
    }
    ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected && element.baseDeviceDefinition.deviceType == DeviceType.ears).forEach((element) {
      element.commandQueue.addCommand(BluetoothMessage("LISTEN FULL", element, Priority.normal));
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
    rxSubscriptions = ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected && element.baseDeviceDefinition.deviceType == DeviceType.ears).map(
      (element) {
        element.commandQueue.addCommand(BluetoothMessage("LISTEN FULL", element, Priority.normal));
        return element.rxCharacteristicStream?.listen(
          (event) {
            String msg = const Utf8Decoder().convert(event);
            if (msg.contains("LISTEN_FULL BANG")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Sound").uuid == e.uuid).forEach(
                    (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
                  );
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
    super.actionTypes = [
      TriggerActionDef("Left", triggerEarTiltLeft(), "0137efd7-5a6f-4ac3-8956-cd75e11e6fd4"),
      TriggerActionDef("Right", triggerEarTiltRight(), "21d233cc-aeaf-4096-a997-7070e38a8801"),
      TriggerActionDef("Forward", triggerEarTiltForward(), "7e32987a-588c-4969-a589-d95f94262da7"),
      TriggerActionDef("Backward", triggerEarTiltbackward(), "a4ad813e-a867-4c73-8e73-c4a294829667"),
    ];
  }

  @override
  Future<void> onDisable() async {
    if (ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).isEmpty) {
      deviceRefSubscription?.close();
      ref.read(knownDevicesProvider).values.where((element) => element.baseDeviceDefinition.deviceType == DeviceType.ears).forEach((element) {
        element.deviceConnectionState.removeListener(onDeviceConnected);
      });
      for (var element in rxSubscriptions) {
        element?.cancel();
      }
      rxSubscriptions = [];
      ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected && element.baseDeviceDefinition.deviceType == DeviceType.ears).forEach((element) {
        element.commandQueue.addCommand(BluetoothMessage("ENDTILTMODE", element, Priority.normal));
      });
    }
  }

  @override
  Future<void> onEnable() async {
    if (rxSubscriptions.isNotEmpty) {
      return;
    }
    ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected && element.baseDeviceDefinition.deviceType == DeviceType.ears).forEach((element) {
      element.commandQueue.addCommand(BluetoothMessage("TILTMODE START", element, Priority.normal));
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
    rxSubscriptions = ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected && element.baseDeviceDefinition.deviceType == DeviceType.ears).map(
      (element) {
        element.commandQueue.addCommand(BluetoothMessage("TILTMODE START", element, Priority.normal));
        return element.rxCharacteristicStream?.listen(
          (event) {
            String msg = const Utf8Decoder().convert(event);
            if (msg.contains("TILT LEFT")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Left").uuid == e.uuid).forEach(
                    (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
                  );
            } else if (msg.contains("TILT RIGHT")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Right").uuid == e.uuid).forEach(
                    (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
                  );
            } else if (msg.contains("TILT FORWARD")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Forward").uuid == e.uuid).forEach(
                    (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
                  );
            } else if (msg.contains("TILT BACKWARD")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Backward").uuid == e.uuid).forEach(
                    (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
                  );
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
    super.actionTypes = [TriggerActionDef("Volume Up", triggerVolumeButtonVolumeUp(), "834a9bef-9ae2-4623-81fa-bbead69eb28e"), TriggerActionDef("Volume Down", triggerVolumeButtonVolumeDown(), "2972aa14-33de-4d4f-ac67-4f572306b5c4")];
  }

  @override
  Future<void> onDisable() async {
    if (ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).isEmpty) {
      subscription?.cancel();
      subscription = null;
    }
  }

  @override
  Future<void> onEnable() async {
    if (subscription != null) {
      return;
    }
    subscription = FlutterAndroidVolumeKeydown.stream.listen((event) {
      Flogger.d("Volume press detected:${event.name}");
      if (event == HardwareButton.volume_down) {
        ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Volume Up").uuid == e.uuid).forEach(
              (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
            );
      } else if (event == HardwareButton.volume_up) {
        ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Volume Down").uuid == e.uuid).forEach(
              (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
            );
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
    super.actionTypes = [TriggerActionDef("Shake", triggerShakeTitle(), "b84b4c7a-2330-4ede-82f4-dca7b6e74b0a")];
  }

  @override
  Future<void> onDisable() async {
    if (ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).isEmpty) {
      detector?.stopListening();
      detector = null;
    }
  }

  @override
  Future<void> onEnable() async {
    if (detector != null) {
      return;
    }
    detector = ShakeDetector.waitForStart(onPhoneShake: () {
      Flogger.d("Shake Detected");
      ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Shake").uuid == e.uuid).forEach(
            (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
          );
    });
    detector?.startListening();
  }
}

class TailProximityTriggerDefinition extends TriggerDefinition {
  StreamSubscription? subscription;
  NearbyService? nearbyService;

  TailProximityTriggerDefinition(super.ref) {
    super.name = triggerProximityTitle();
    super.description = triggerProximityDescription();
    super.icon = const Icon(Icons.bluetooth_connected);
    super.requiredPermission = Permission.bluetoothScan;
    super.actionTypes = [TriggerActionDef("Nearby Gear", triggerProximityTitle(), "e78a749b-8b78-47df-a5a1-1ed365292214")];
  }

  @override
  Future<void> onDisable() async {
    if (ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).isEmpty) {
      subscription?.cancel();
      subscription = null;
      await nearbyService?.stopAdvertisingPeer();
      await nearbyService?.stopBrowsingForPeers();
    }
  }

  @override
  Future<void> onEnable() async {
    if (subscription != null) {
      return;
    }
    nearbyService = NearbyService();
    await nearbyService?.init(
        serviceType: "tailapp",
        strategy: Strategy.P2P_POINT_TO_POINT,
        callback: (isRunning) async {
          if (isRunning) {
            await nearbyService?.startAdvertisingPeer();
            await nearbyService?.startBrowsingForPeers();
          }
        });
    subscription = nearbyService?.stateChangedSubscription(callback: (devicesList) {
      Flogger.d("TailProximityTriggerDefinition::");
      ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.actions).flattened.where((e) => actionTypes.firstWhere((element) => element.name == "Nearby Gear").uuid == e.uuid).forEach(
            (element) => sendCommands(ref.read(triggerListProvider).where((element) => element.triggerDefinition == this && element.enabled).map((e) => e.deviceType).flattened.toSet(), element.action, ref),
          );
    });
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

  TriggerAction(this.uuid);

  @override
  bool operator ==(Object other) => identical(this, other) || other is TriggerAction && runtimeType == other.runtimeType && uuid == other.uuid;

  @override
  int get hashCode => uuid.hashCode;
}

@Riverpod(keepAlive: true, dependencies: [TriggerDefinitionList])
class TriggerList extends _$TriggerList {
  @override
  List<Trigger> build() {
    return SentryHive.box<Trigger>('triggers').values.map((trigger) {
      Trigger trigger2 = Trigger.trigDef(ref.read(triggerDefinitionListProvider).firstWhere((element) => element.name == trigger.triggerDef));
      trigger2.actions = trigger.actions;
      trigger2.enabled = trigger2.enabled;
      trigger2.deviceType = trigger.deviceType;
      return trigger2;
    }).toList();
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
    SentryHive.box<Trigger>('triggers')
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
