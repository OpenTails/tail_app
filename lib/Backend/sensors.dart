// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_android_volume_keydown/flutter_android_volume_keydown.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart' as log;
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shake/shake.dart';
import 'package:tail_app/Backend/wear_bridge.dart';

import '../Frontend/translation_string_definitions.dart';
import '../Frontend/utils.dart';
import '../constants.dart';
import 'Bluetooth/bluetooth_manager.dart';
import 'Bluetooth/bluetooth_manager_plus.dart';
import 'Bluetooth/bluetooth_message.dart';
import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/device_definition.dart';
import 'action_registry.dart';
import 'device_registry.dart';
import 'logging_wrappers.dart';
import 'move_lists.dart';

part 'sensors.freezed.dart';
part 'sensors.g.dart';

final sensorsLogger = log.Logger('Sensors');
final _random = Random();

@HiveType(typeId: 2)
class Trigger extends ChangeNotifier {
  @HiveField(1)
  late final String triggerDefUUID;
  TriggerDefinition? triggerDefinition;
  @HiveField(5, defaultValue: false)
  bool _storedEnable = false;

  bool get storedEnable => _storedEnable;

  set storedEnable(bool value) {
    _storedEnable = value;
    enabled = value;
  }

  bool _enabled = false;
  @HiveField(4)
  final String uuid;

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (_enabled) {
      triggerDefinition?.deviceTypes = _deviceType.toSet();
      triggerDefinition?.actions = actions;
      triggerDefinition?.addListener(triggerDefListener);
      triggerDefinition?.enabled = value;
    } else {
      triggerDefinition?.deviceTypes = {};
      triggerDefinition?.actions = [];
      triggerDefinition?.removeListener(triggerDefListener);
      triggerDefinition?.enabled = value;
    }
  }

  void triggerDefListener() {
    if (triggerDefinition?.enabled != _enabled && _enabled) {
      enabled = false;
      notifyListeners();
    }
    if (triggerDefinition?.enabled != _enabled && !_enabled) {
      enabled = true;
      notifyListeners();
    }
  }

  @HiveField(2, defaultValue: DeviceType.values)
  List<DeviceType> _deviceType = DeviceType.values.toList();

  List<DeviceType> get deviceType => _deviceType;

  set deviceType(List<DeviceType> value) {
    _deviceType = value;
    if (_enabled) {
      triggerDefinition?.deviceTypes = _deviceType.toSet();
    }
  }

  @HiveField(3)
  List<TriggerAction> _actions = [];

  List<TriggerAction> get actions => _actions;

  set actions(List<TriggerAction> value) {
    _actions = value;
    if (_enabled) {
      triggerDefinition?.actions = actions;
    }
  }

  Trigger(this.triggerDefUUID, this.uuid) {
    // called by hive when loading object
  }

  Trigger.trigDef(this.triggerDefinition, this.uuid) {
    triggerDefUUID = triggerDefinition!.uuid;
    actions.addAll(triggerDefinition!.actionTypes.map((e) => TriggerAction(e.uuid)));
  }
}

class TriggerPermissionHandle {
  final Set<Permission> android;
  final Set<Permission> ios;

  const TriggerPermissionHandle({this.android = const {}, this.ios = const {}});

  Future<bool> hasAllPermissions() async {
    if (platform.isAndroid) {
      for (Permission permission in android) {
        PermissionStatus permissionStatus = await permission.request();
        if (PermissionStatus.granted != permissionStatus) {
          return false;
        }
      }
    }
    if (platform.isIOS) {
      for (Permission permission in ios) {
        PermissionStatus permissionStatus = await permission.request();
        if (PermissionStatus.granted != permissionStatus) {
          return false;
        }
      }
    }
    return true;
  }
}

abstract class TriggerDefinition extends ChangeNotifier implements Comparable<TriggerDefinition> {
  late final String name;
  late final String description;
  late final Widget icon;
  late final String uuid;
  Set<DeviceType> deviceTypes = {};
  List<TriggerAction> actions = [];
  bool _enabled = false;

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (value == _enabled) {
      return;
    }
    if (!value && actions.isEmpty) {
      _enabled = false;
      onDisable();
      notifyListeners();
    } else if (requiredPermission != null && value) {
      requiredPermission?.hasAllPermissions().then(
        (granted) async {
          if (granted) {
            _enabled = true;
            onEnable();
          }
          notifyListeners();
        },
      );
    } else if (value) {
      _enabled = true;
      onEnable();
      notifyListeners();
    }

    //Refresh wear data when a trigger is enabled/disabled
    ref.refresh(updateWearDataProvider.future);
  }

  Ref ref;

  Future<void> onEnable();

  Future<void> onDisable();

  TriggerPermissionHandle? requiredPermission;
  late final List<TriggerActionDef> actionTypes;

  TriggerDefinition(this.ref);

  // add check here if a trigger is supported on a given device/platform
  Future<bool> isSupported() {
    return Future.value(true);
  }

  Future<void> sendCommands(String name, Ref ref) async {
    if (ref.read(getAvailableGearProvider).isEmpty) {
      return;
    }
    actions.where((e) => actionTypes.firstWhere((element) => element.name == name).uuid == e.uuid).forEach(
      (TriggerAction triggerAction) async {
        if (triggerAction.isActive.value || triggerAction.actions.isEmpty) {
          // 15 second cool-down between moves
          return;
        }
        final List<BaseAction> allActionsMapped =
            triggerAction.actions.map((element) => ref.read(getActionFromUUIDProvider(element))).nonNulls.toList();

        // no moves exist
        if (allActionsMapped.isEmpty) {
          return;
        }
        // we need to handle legacy ears for now
        // assuming only legacy or tailcontrol ears are connected. no mixing
        bool hasLegacyEars = ref
            .read(getAvailableIdleGearForTypeProvider([DeviceType.ears].toBuiltSet()))
            .where(
              (p0) => p0.isTailCoNTROL.value == TailControlStatus.legacy,
            )
            .isNotEmpty;
        bool hasGlowtipGear = ref
            .read(getAvailableIdleGearProvider)
            .where(
              (p0) => p0.hasGlowtip.value == GlowtipStatus.glowtip,
            )
            .isNotEmpty;
        final List<BaseAction> moveActions = allActionsMapped
            .where((element) => !const [ActionCategory.glowtip, ActionCategory.audio].contains(element.actionCategory))
            .whereNot(
              // filter out legacy moves if legacy ears are not connected
              (element) => (element is EarsMoveList && !hasLegacyEars),
            )
            .toList();

        final List<BaseAction> glowActions = hasGlowtipGear
            ? allActionsMapped.where((element) => const [ActionCategory.glowtip].contains(element.actionCategory)).toList()
            : [];
        final List<BaseAction> audioActions =
            allActionsMapped.where((element) => const [ActionCategory.audio].contains(element.actionCategory)).toList();

        BaseAction? baseAction;
        List<BaseAction> actionsToRun = [];

        // add a glowtip action if it exists
        if (glowActions.isNotEmpty) {
          final BaseAction glowAction = glowActions[_random.nextInt(glowActions.length)];
          actionsToRun.add(glowAction);
        }
        // add a audio action if it exists
        if (audioActions.isNotEmpty) {
          final BaseAction audioAction = audioActions[_random.nextInt(audioActions.length)];
          actionsToRun.add(audioAction);
        }
        // check if non glowy actions are set
        if (moveActions.isNotEmpty) {
          baseAction = moveActions[_random.nextInt(moveActions.length)];
          actionsToRun.add(baseAction);
        }
        //only adding a check here
        if (baseAction != null &&
            moveActions.length > 1 &&
            ((baseAction is CommandAction && hasLegacyEars) ||
                !baseAction.deviceCategory.toSet().containsAll(deviceTypes))) {
          // find the missing device type
          // The goal here is if a user selects multiple moves, send a move to all gear
          final Set<DeviceType> baseActionDeviceCategories = baseAction.deviceCategory.where(
            // filtering out the first actions ears entry if its a unified move but legacy gear is connected
            (element) {
              if (element == DeviceType.ears) {
                if (baseAction is CommandAction) {
                  return hasLegacyEars;
                }
              }
              return true;
            },
          ).toSet();
          final Set<DeviceType> missingGearAction = deviceTypes.difference(baseActionDeviceCategories);
          final List<BaseAction> remainingActions = moveActions.where(
            // Check if any actions contain the device type of the gear the first action is missing
            (element) {
              // filters out remaining CommandActions if legacy ears are connected. Assumes Custom Actions send to ears too
              if (baseAction is CommandAction && hasLegacyEars) {
                if (element is EarsMoveList) {
                  return true;
                } else if (element is CommandAction) {
                  return false;
                }
              }
              return element.deviceCategory.toSet().intersection(missingGearAction).isNotEmpty;
            },
          ).toList();
          if (remainingActions.isNotEmpty) {
            final BaseAction otherAction = remainingActions[_random.nextInt(remainingActions.length)];
            actionsToRun.add(otherAction);
          }
        }
        // updates the frontend that a trigger activated
        triggerAction.isActive.value = true;

        Set<DeviceType> sentDeviceTypes = {};
        for (BaseAction baseAction in actionsToRun) {
          for (BaseStatefulDevice baseStatefulDevice in ref
              .read(getAvailableIdleGearForTypeProvider(baseAction.deviceCategory.toBuiltSet()))
              .where(
                // support sending to next device type if 2 actions+ actions are set
                (element) => !sentDeviceTypes.contains(element.baseDeviceDefinition.deviceType),
              )
              .where(
            (element) {
              // filter out devices without a glowtip if its a glowtip action
              if ([ActionCategory.glowtip].contains(baseAction.actionCategory)) {
                return element.hasGlowtip.value == GlowtipStatus.glowtip;
              }

              // tailcontrol migration
              if (element.baseDeviceDefinition.deviceType == DeviceType.ears) {
                if (baseAction is CommandAction &&
                    baseAction.actionCategory != ActionCategory.glowtip &&
                    element.baseDeviceDefinition.deviceType == DeviceType.ears &&
                    element.isTailCoNTROL.value == TailControlStatus.legacy) {
                  return false;
                } else if (baseAction is EarsMoveList &&
                    element.baseDeviceDefinition.deviceType == DeviceType.ears &&
                    element.isTailCoNTROL.value == TailControlStatus.tailControl) {
                  return false;
                }
              }
              // return remaining gear
              return true;
            },
          ).toList()
            ..shuffle()) {
            if (HiveProxy.getOrDefault(settings, kitsuneModeToggle, defaultValue: kitsuneModeDefault)) {
              await Future.delayed(Duration(milliseconds: Random().nextInt(kitsuneDelayRange)));
            }
            ref.read(runActionProvider(baseAction, baseStatefulDevice));
            if (!const [ActionCategory.glowtip].contains(baseAction.actionCategory)) {
              // handle tailcontrol migration by not counting the actions as used.
              if (baseAction is CommandAction &&
                  baseStatefulDevice.baseDeviceDefinition.deviceType == DeviceType.ears &&
                  baseStatefulDevice.isTailCoNTROL.value == TailControlStatus.legacy) {
                continue;
              } else if (baseAction is EarsMoveList &&
                  baseStatefulDevice.baseDeviceDefinition.deviceType == DeviceType.ears &&
                  baseStatefulDevice.isTailCoNTROL.value == TailControlStatus.tailControl) {
                continue;
              }
              sentDeviceTypes.add(baseStatefulDevice.baseDeviceDefinition.deviceType);
            }
          }
        }
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
    super.requiredPermission = TriggerPermissionHandle(android: {Permission.activityRecognition});
    super.uuid = "ee9379e2-ec4f-40bb-8674-fd223a6edfda";
    super.actionTypes = [
      TriggerActionDef(name: "Walking", translated: triggerWalkingTitle(), uuid: "77d22961-5a69-465a-bd27-5cf5508d10a6"),
      TriggerActionDef(name: "Stopped", translated: triggerWalkingStopped(), uuid: "7424097d-ba24-4d85-b963-bf58e85e289d"),
      TriggerActionDef(name: "Step", translated: triggerWalkingStep(), uuid: "c82b04ba-7d2e-475a-90ba-3d354e5b8ef0"),
    ];
  }

  @override
  Future<bool> isSupported() async {
    if (!platform.isAndroid && !platform.isIOS) {
      return false;
    }
    bool isStepCountSupported = await Pedometer.isStepCountSupported == true;
    bool isStepDetectionSupported = await Pedometer.isStepDetectionSupported == true;
    return isStepDetectionSupported && isStepCountSupported;
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
        sensorsLogger.info("PedestrianStatus:: ${event.status}");
        if (event.status == "walking") {
          sendCommands("Walking", ref);
        } else if (event.status == "stopped") {
          sendCommands("Stopped", ref);
        }
      },
    );
    stepCountStream = Pedometer.stepCountStream.listen(
      (StepCount event) {
        sensorsLogger.fine("StepCount:: ${event.steps}");
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
    super.actionTypes = [
      TriggerActionDef(name: "Near", translated: triggerCoverNear(), uuid: "bf3d0ce0-15c0-46db-95ce-e2cd6a5ecd0f"),
      TriggerActionDef(name: "Far", translated: triggerCoverFar(), uuid: "d121e4a8-a12d-4f0a-8348-89c62eb72a7a")
    ];
  }

  @override
  Future<bool> isSupported() async {
    if (!platform.isAndroid && !platform.isIOS) {
      return false;
    }
    return ProximitySensor.isSupported();
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
      sensorsLogger.fine("CoverEvent:: $event");
      if (event >= 1) {
        sendCommands("Near", ref);
      } else if (event == 0) {
        sendCommands("Far", ref);
      }
    });
  }
}

class EarMicTriggerDefinition extends TriggerDefinition {
  List<StreamSubscription<String>?> rxSubscriptions = [];
  ProviderSubscription<BuiltMap<String, BaseStatefulDevice>>? deviceRefSubscription;

  EarMicTriggerDefinition(super.ref) {
    super.name = triggerEarMicTitle();
    super.description = triggerEarMicDescription();
    super.icon = const Icon(Icons.mic);
    super.requiredPermission = null;
    super.uuid = "3bbd2306-ea53-44f5-a930-474ff23ec23d";
    super.actionTypes = [
      TriggerActionDef(name: "Sound", translated: triggerEarMicSound(), uuid: "839d8978-7b77-4ccb-b23f-28144bf95453"),
    ];
  }

  @override
  Future<bool> isSupported() async {
    return ref.read(getKnownGearForTypeProvider(BuiltSet([DeviceType.ears]))).isNotEmpty;
  }

  @override
  Future<void> onDisable() async {
    deviceRefSubscription?.close();
    ref.read(getKnownGearForTypeProvider(BuiltSet([DeviceType.ears]))).forEach((element) {
      element.deviceConnectionState.removeListener(onDeviceConnected);
    });
    for (var element in rxSubscriptions) {
      element?.cancel();
    }
    rxSubscriptions = [];
    ref.read(getAvailableGearForTypeProvider(BuiltSet([DeviceType.ears]))).forEach((element) {
      ref.read(commandQueueProvider(element).notifier).addCommand(BluetoothMessage(
          message: "ENDLISTEN",
          priority: Priority.low,
          responseMSG: "LISTEN OFF",
          type: CommandType.system,
          timestamp: DateTime.now()));
    });
  }

  @override
  Future<void> onEnable() async {
    if (rxSubscriptions.isNotEmpty) {
      return;
    }
    ref.read(getAvailableGearForTypeProvider(BuiltSet([DeviceType.ears]))).forEach((element) {
      ref.read(commandQueueProvider(element).notifier).addCommand(BluetoothMessage(
          message: "LISTEN FULL", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
    });
    //add listeners on new device paired
    deviceRefSubscription = ref.listen(knownDevicesProvider, (previous, next) {
      onDeviceConnected();
    });
  }

  Future<void> onDeviceConnected() async {
    ref.read(getKnownGearForTypeProvider(BuiltSet([DeviceType.ears]))).map((e) {
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
    rxSubscriptions = ref.read(getAvailableGearForTypeProvider(BuiltSet([DeviceType.ears]))).map(
      (element) {
        ref.read(commandQueueProvider(element).notifier).addCommand(BluetoothMessage(
            message: "LISTEN FULL", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
        return element.rxCharacteristicStream.listen(
          (msg) {
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
  List<StreamSubscription<String>?> rxSubscriptions = [];
  ProviderSubscription<BuiltMap<String, BaseStatefulDevice>>? deviceRefSubscription;

  EarTiltTriggerDefinition(super.ref) {
    super.name = triggerEarTiltTitle();
    super.description = triggerEarTiltDescription();
    super.icon = const Icon(Icons.threed_rotation);
    super.requiredPermission = null;
    super.uuid = "93d72792-145e-4b56-92b9-3279a5e7d839";
    super.actionTypes = [
      TriggerActionDef(name: "Left", translated: triggerEarTiltLeft(), uuid: "0137efd7-5a6f-4ac3-8956-cd75e11e6fd4"),
      TriggerActionDef(name: "Right", translated: triggerEarTiltRight(), uuid: "21d233cc-aeaf-4096-a997-7070e38a8801"),
      TriggerActionDef(name: "Forward", translated: triggerEarTiltForward(), uuid: "7e32987a-588c-4969-a589-d95f94262da7"),
      TriggerActionDef(
          name: "Backward", translated: triggerEarTiltBackward(), uuid: "a4ad813e-a867-4c73-8e73-c4a294829667"),
    ];
  }

  @override
  Future<bool> isSupported() async {
    return ref.read(getKnownGearForTypeProvider(BuiltSet([DeviceType.ears]))).isNotEmpty;
  }

  @override
  Future<void> onDisable() async {
    deviceRefSubscription?.close();
    ref.read(getKnownGearForTypeProvider(BuiltSet([DeviceType.ears]))).forEach((element) {
      element.deviceConnectionState.removeListener(onDeviceConnected);
    });
    for (var element in rxSubscriptions) {
      element?.cancel();
    }
    rxSubscriptions = [];
    ref.read(getAvailableGearForTypeProvider(BuiltSet([DeviceType.ears]))).forEach((element) {
      ref.read(commandQueueProvider(element).notifier).addCommand(BluetoothMessage(
          message: "ENDTILTMODE", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
    });
  }

  @override
  Future<void> onEnable() async {
    if (rxSubscriptions.isNotEmpty) {
      return;
    }
    ref.read(getAvailableGearForTypeProvider(BuiltSet([DeviceType.ears]))).forEach((element) {
      ref.read(commandQueueProvider(element).notifier).addCommand(BluetoothMessage(
          message: "TILTMODE START", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
    });
    //add listeners on new device paired
    deviceRefSubscription = ref.listen(knownDevicesProvider, (previous, next) {
      onDeviceConnected();
    });
  }

  Future<void> onDeviceConnected() async {
    ref.read(getKnownGearForTypeProvider(BuiltSet([DeviceType.ears]))).map((e) {
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
    rxSubscriptions = ref.read(getAvailableGearForTypeProvider(BuiltSet([DeviceType.ears]))).map(
      (element) {
        ref.read(commandQueueProvider(element).notifier).addCommand(BluetoothMessage(
            message: "TILTMODE START", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
        return element.rxCharacteristicStream.listen(
          (msg) {
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

class RandomTriggerDefinition extends TriggerDefinition {
  Timer? randomTimer;

  RandomTriggerDefinition(super.ref) {
    super.name = triggerRandomButtonTitle();
    super.description = triggerRandomButtonDescription();
    super.icon = const Icon(Icons.timelapse);
    super.requiredPermission = null;
    super.uuid = "12e01dea-219a-40e7-b51d-d89d6d4460ac";
    super.actionTypes = [
      TriggerActionDef(name: "Action", translated: triggerRandomAction(), uuid: "60011d58-1c29-49ae-ad31-6774b81df49b")
    ];
  }

  @override
  Future<void> onDisable() async {
    randomTimer?.cancel();
    randomTimer = null;
  }

  @override
  Future<void> onEnable() async {
    int min = HiveProxy.getOrDefault(settings, casualModeDelayMin, defaultValue: casualModeDelayMinDefault);
    int max = HiveProxy.getOrDefault(settings, casualModeDelayMax, defaultValue: casualModeDelayMaxDefault);
    await Future.delayed(Duration(seconds: min));
    if (enabled) {
      randomTimer = Timer(Duration(seconds: Random().nextInt((max - min).clamp(1, max))), () {
        sendCommands("Action", ref);
        onEnable();
      });
    }
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
    super.actionTypes = [
      TriggerActionDef(
          name: "Volume Up", translated: triggerVolumeButtonVolumeUp(), uuid: "834a9bef-9ae2-4623-81fa-bbead69eb28e"),
      TriggerActionDef(
          name: "Volume Down", translated: triggerVolumeButtonVolumeDown(), uuid: "2972aa14-33de-4d4f-ac67-4f572306b5c4")
    ];
  }

  @override
  Future<bool> isSupported() async {
    return platform.isAndroid;
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
      sensorsLogger.fine("Volume press detected:${event.name}");
      if (event == HardwareButton.volume_up) {
        sendCommands("Volume Up", ref);
      } else if (event == HardwareButton.volume_down) {
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
    super.actionTypes = [
      TriggerActionDef(name: "Shake", translated: triggerShakeTitle(), uuid: "b84b4c7a-2330-4ede-82f4-dca7b6e74b0a")
    ];
  }

  @override
  Future<bool> isSupported() async {
    if (!platform.isAndroid && !platform.isIOS) {
      return false;
    }
    return true;
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
    detector = ShakeDetector.waitForStart(
      onPhoneShake: () {
        sensorsLogger.fine("Shake Detected");
        sendCommands("Shake", ref);
      },
    );
    detector?.startListening();
  }
}

class TailProximityTriggerDefinition extends TriggerDefinition {
  StreamSubscription<List<ScanResult>>? btConnectStream;
  Timer? btnearbyCooldown;

  TailProximityTriggerDefinition(super.ref) {
    super.name = triggerProximityTitle();
    super.description = triggerProximityDescription();
    super.icon = const Icon(Icons.bluetooth_connected);
    super.requiredPermission = TriggerPermissionHandle(android: {Permission.bluetoothScan}, ios: {Permission.bluetooth});
    super.uuid = "5418e7a5-850b-482e-ba35-163564c848ab";
    super.actionTypes = [
      TriggerActionDef(
          name: "Nearby Gear", translated: triggerProximityTitle(), uuid: "e78a749b-8b78-47df-a5a1-1ed365292214")
    ];
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
    btConnectStream = flutterBluePlus.onScanResults.listen(
      (event) {
        if (event
                .where((element) => !ref.read(knownDevicesProvider).keys.contains(element.device.remoteId.str))
                .isNotEmpty &&
            btnearbyCooldown != null &&
            btnearbyCooldown!.isActive) {
          sendCommands("Nearby Gear", ref);

          btnearbyCooldown = Timer(const Duration(seconds: 30), () {});
        }
      },
    );
  }
}

@freezed
abstract class TriggerActionDef with _$TriggerActionDef {
  //Store in trigger def instance
  const factory TriggerActionDef({
    required String name,
    required String translated,
    required String uuid,
    @Default(false) final bool defaultActions,
  }) = _TriggerActionDef;
}

@HiveType(typeId: 8)
class TriggerAction {
  Timer? _timer;
  Timer? _periodicTimer;
  @HiveField(1)
  final String uuid; //uuid matches triggerActionDef
  @HiveField(2)
  List<String> actions = [];
  ValueNotifier<bool> isActive = ValueNotifier(false);
  ValueNotifier<double> isActiveProgress = ValueNotifier(0);

  TriggerAction(this.uuid) {
    isActive.addListener(
      () {
        if (isActive.value) {
          isActiveProgress.value = 0.01;
          _timer = Timer(
            Duration(
                seconds:
                    HiveProxy.getOrDefault(settings, triggerActionCooldown, defaultValue: triggerActionCooldownDefault)),
            () {
              isActive.value = false;
              _periodicTimer?.cancel();
              _timer?.cancel();
              isActiveProgress.value = 0;
              _periodicTimer = null;
              _timer = null;
            },
          );
          _periodicTimer = Timer.periodic(
            const Duration(milliseconds: 500),
            (Timer timer) {
              timer.tick;
              double change = (timer.tick + 1) / 30;
              if (change > 1) {
                change = 1;
              }
              isActiveProgress.value = change;
            },
          );
        }
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TriggerAction && runtimeType == other.runtimeType && uuid == other.uuid;

  @override
  int get hashCode => uuid.hashCode;
}

@Riverpod(
  keepAlive: true,
)
class TriggerList extends _$TriggerList {
  @override
  BuiltList<Trigger> build() {
    List<Trigger> results = [];
    ref.listen(
      getAvailableGearProvider,
      (previous, next) {
        for (Trigger trigger in state) {
          if (trigger.storedEnable) {
            trigger.enabled = next.isNotEmpty;
          }
        }
      },
    );
    try {
      results = HiveProxy.getAll<Trigger>(triggerBox).map((trigger) {
        Trigger trigger2 = Trigger.trigDef(
            ref.read(triggerDefinitionListProvider).firstWhere((element) => element.uuid == trigger.triggerDefUUID),
            trigger.uuid);
        trigger2.actions = trigger.actions;
        trigger2.deviceType = trigger.deviceType;
        return trigger2;
      }).toList(growable: true);
    } catch (e, s) {
      sensorsLogger.severe("Unable to load stored triggers: $e", e, s);
    }
    if (results.isEmpty) {
      TriggerDefinition triggerDefinition = ref
          .read(triggerDefinitionListProvider)
          .where((element) => element.uuid == 'ee9379e2-ec4f-40bb-8674-fd223a6edfda')
          .first;
      Trigger trigger = Trigger.trigDef(triggerDefinition, '91e3d421-6a52-45ab-a23e-f38e4987a8f5');
      trigger.actions.firstWhere((element) => element.uuid == '77d22961-5a69-465a-bd27-5cf5508d10a6').actions.add(
          ActionRegistry.allCommands.firstWhere((element) => element.uuid == 'c53e980e-899e-4148-a13e-f57a8f9707f4').uuid);
      trigger.actions.firstWhere((element) => element.uuid == '77d22961-5a69-465a-bd27-5cf5508d10a6').actions.addAll(
            ActionRegistry.allCommands
                .where(
                  (element) => element.actionCategory == ActionCategory.glowtip,
                )
                .map(
                  (e) => e.uuid,
                ),
          );
      trigger.actions.firstWhere((element) => element.uuid == '77d22961-5a69-465a-bd27-5cf5508d10a6').actions.add(
          ActionRegistry.allCommands.firstWhere((element) => element.uuid == 'fdaff205-0a51-46a0-a5fc-4ea283dce079').uuid);
      trigger.actions.firstWhere((element) => element.uuid == '7424097d-ba24-4d85-b963-bf58e85e289d').actions.add(
          ActionRegistry.allCommands.firstWhere((element) => element.uuid == '86b13d13-b09c-46ba-a887-b40d8118b00a').uuid);
      trigger.actions.firstWhere((element) => element.uuid == '7424097d-ba24-4d85-b963-bf58e85e289d').actions.add(
          ActionRegistry.allCommands.firstWhere((element) => element.uuid == 'd8384bcf-31ed-4b5d-a25a-da3a2f96e406').uuid);

      store();
      return [trigger].build();
    }
    return results.build();
  }

  Future<void> add(Trigger trigger) async {
    state = state.rebuild(
      (p0) => p0.add(trigger),
    );
    await store();
  }

  Future<void> remove(Trigger trigger) async {
    trigger.enabled = false;
    state = state.rebuild(
      (p0) => p0.remove(trigger),
    );
    await store();
  }

  Future<void> store() async {
    sensorsLogger.info("Storing triggers");
    await HiveProxy.clear<Trigger>(triggerBox);
    await HiveProxy.addAll<Trigger>(triggerBox, state);
  }
}

// Defines what triggers show in the UI
@Riverpod(keepAlive: true)
class TriggerDefinitionList extends _$TriggerDefinitionList {
  @override
  BuiltList<TriggerDefinition> build() {
    List<TriggerDefinition> triggerDefinitions = [
      WalkingTriggerDefinition(ref),
      CoverTriggerDefinition(ref),
      TailProximityTriggerDefinition(ref),
      ShakeTriggerDefinition(ref),
      EarMicTriggerDefinition(ref),
      EarTiltTriggerDefinition(ref),
      RandomTriggerDefinition(ref),
    ];
    if (platform.isAndroid) {
      triggerDefinitions.add(VolumeButtonTriggerDefinition(ref));
    }
    triggerDefinitions.sort();
    return triggerDefinitions.build();
  }

  //Filter by unused sensors
  List<TriggerDefinition> get() =>
      state.toSet().difference(ref.read(triggerListProvider).map((Trigger e) => e.triggerDefinition!).toSet()).toList();

  Future<List<TriggerDefinition>> getSupported() async {
    List<TriggerDefinition> unusedTriggerDefinitions = get();
    List<TriggerDefinition> supportedTriggerDefinitions = [];
    for (TriggerDefinition triggerDefinition in unusedTriggerDefinitions) {
      if (await triggerDefinition.isSupported()) {
        supportedTriggerDefinitions.add(triggerDefinition);
      }
    }
    return supportedTriggerDefinitions;
  }
}
