import 'package:flutter/cupertino.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/moveLists.dart';

import 'Bluetooth/BluetoothManager.dart';
import 'Definitions/Action/BaseAction.dart';
import 'Definitions/Device/BaseDeviceDefinition.dart';

part 'ActionRegistry.g.dart';

@immutable
class ActionRegistry {
  static Set<BaseAction> allCommands = {
    CommandAction("Slow wag 1", "TAILS1", [DeviceType.tail], ActionCategory.calm, "END TAILS1"),
    CommandAction("Slow wag 2", "TAILS2", [DeviceType.tail], ActionCategory.calm, "END TAILS2"),
    CommandAction("Slow wag 3", "TAILS3", [DeviceType.tail], ActionCategory.calm, "END TAILS3"),
    CommandAction("Fast wag", "TAILFA", [DeviceType.tail], ActionCategory.fast, "END TAILFA"),
    CommandAction("Short wag", "TAILSH", [DeviceType.tail], ActionCategory.fast, "END TAILSH"),
    CommandAction("Happy wag", "TAILHA", [DeviceType.tail], ActionCategory.fast, "END TAILHA"),
    CommandAction("Erect", "TAILER", [DeviceType.tail], ActionCategory.fast, "END TAILER"),
    CommandAction("Erect Pulse", "TAILEP", [DeviceType.tail], ActionCategory.tense, "END TAILEP"),
    CommandAction("Tremble 1", "TAILT1", [DeviceType.tail], ActionCategory.tense, "END TAILT1"),
    CommandAction("Tremble 2", "TAILT2", [DeviceType.tail], ActionCategory.tense, "END TAILT2"),
    CommandAction("Erect Tremble", "TAILET", [DeviceType.tail], ActionCategory.tense, "END TAILET"),
    CommandAction("LEDs off", "LEDOFF", [DeviceType.tail], ActionCategory.glowtip, null),
    CommandAction("Rectangle wave", "LEDREC", [DeviceType.tail], ActionCategory.glowtip, null),
    CommandAction("Triangle wave", "LEDTRI", [DeviceType.tail], ActionCategory.glowtip, null),
    CommandAction("Sawtooth wave", "LEDSAW", [DeviceType.tail], ActionCategory.glowtip, null),
    CommandAction("SOS", "LEDSOS", [DeviceType.tail], ActionCategory.glowtip, null),
    CommandAction("Beacon", "LEDBEA", [DeviceType.tail], ActionCategory.glowtip, null),
    CommandAction("Flame", "LEDFLA", [DeviceType.tail], ActionCategory.glowtip, null),
    CommandAction("Left Twist", "LETWIST", [DeviceType.ears], ActionCategory.ears, "LETWIST END"),
    CommandAction("Right Twist", "RITWIST", [DeviceType.ears], ActionCategory.ears, "RITWIST END"),
    CommandAction("Both Twist", "BOTWIST", [DeviceType.ears], ActionCategory.ears, "BOTWIST END"),
    CommandAction("Home Ears", "EARHOME", [DeviceType.ears], ActionCategory.ears, "EARHOME END")
  };
}

@Riverpod(dependencies: [KnownDevices])
Map<ActionCategory, Set<BaseAction>> getAvailableActions(GetAvailableActionsRef ref) {
  Map<String, BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);
  Map<ActionCategory, Set<BaseAction>> sortedActions = {};
  for (BaseAction baseAction in List.from(ActionRegistry.allCommands)..addAll(ref.read(moveListsProvider))) {
    Set<BaseAction>? baseActions = {};
    for (BaseStatefulDevice baseStatefulDevice in knownDevices.values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected)) {
      // check if command matches device type
      if (baseAction.deviceCategory.contains(baseStatefulDevice.baseDeviceDefinition.deviceType)) {
        // get category if it exists
        if (sortedActions.containsKey(baseAction.actionCategory)) {
          baseActions = sortedActions[baseAction.actionCategory];
        }
        // add action to category
        baseActions?.add(baseAction);
      }
    }
    // store result
    if (baseActions != null && baseActions.isNotEmpty) {
      sortedActions[baseAction.actionCategory] = baseActions;
    }
  }
  return sortedActions;
}

@Riverpod(dependencies: [KnownDevices])
Map<ActionCategory, Set<BaseAction>> getAllActions(GetAllActionsRef ref, Set<DeviceType> deviceType) {
  Map<ActionCategory, Set<BaseAction>> sortedActions = {};
  for (BaseAction baseAction in List.from(ActionRegistry.allCommands)..addAll(ref.read(moveListsProvider))) {
    Set<BaseAction>? baseActions = {};
    // check if command matches device type
    if (baseAction.deviceCategory.toSet().intersection(deviceType).isNotEmpty) {
      // get category if it exists
      if (sortedActions.containsKey(baseAction.actionCategory)) {
        baseActions = sortedActions[baseAction.actionCategory];
      }
      // add action to category
      baseActions?.add(baseAction);
    }
    // store result
    if (baseActions != null && baseActions.isNotEmpty) {
      sortedActions[baseAction.actionCategory] = baseActions;
    }
  }
  return sortedActions;
}
