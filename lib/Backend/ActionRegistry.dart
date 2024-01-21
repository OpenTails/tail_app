import 'package:flutter/cupertino.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'Bluetooth/BluetoothManager.dart';
import 'Definitions/Action/BaseAction.dart';
import 'Definitions/Device/BaseDeviceDefinition.dart';

part 'ActionRegistry.g.dart';

@immutable
class ActionRegistry {
  static Set<BaseAction> allCommands = {
    const BaseAction("Slow wag 1", "TAILS1", DeviceType.tail, ActionCategory.calm),
    const BaseAction("Slow wag 2", "TAILS2", DeviceType.tail, ActionCategory.calm),
    const BaseAction("Slow wag 3", "TAILS3", DeviceType.tail, ActionCategory.calm),
    const BaseAction("Fast wag", "TAILFA", DeviceType.tail, ActionCategory.fast),
    const BaseAction("Short wag", "TAILSH", DeviceType.tail, ActionCategory.fast),
    const BaseAction("Happy wag", "TAILHA", DeviceType.tail, ActionCategory.fast),
    const BaseAction("Erect", "TAILER", DeviceType.tail, ActionCategory.fast),
    const BaseAction("Erect Pulse", "TAILEP", DeviceType.tail, ActionCategory.tense),
    const BaseAction("Tremble 1", "TAILT1", DeviceType.tail, ActionCategory.tense),
    const BaseAction("Tremble 2", "TAILT2", DeviceType.tail, ActionCategory.tense),
    const BaseAction("Erect Tremble", "TAILET", DeviceType.tail, ActionCategory.tense),
    const BaseAction("LEDs off", "LEDOFF", DeviceType.tail, ActionCategory.glowtip),
    const BaseAction("Rectangle wave", "LEDREC", DeviceType.tail, ActionCategory.glowtip),
    const BaseAction("Triangle wave", "LEDTRI", DeviceType.tail, ActionCategory.glowtip),
    const BaseAction("Sawtooth wave", "LEDSAW", DeviceType.tail, ActionCategory.glowtip),
    const BaseAction("SOS", "LEDSOS", DeviceType.tail, ActionCategory.glowtip),
    const BaseAction("Beacon", "LEDBEA", DeviceType.tail, ActionCategory.glowtip),
    const BaseAction("Flame", "LEDFLA", DeviceType.tail, ActionCategory.glowtip),
    const BaseAction("Left Twist", "LETWIST", DeviceType.ears, ActionCategory.ears),
    const BaseAction("Right Twist", "RITWIST", DeviceType.ears, ActionCategory.ears),
    const BaseAction("Both Twist", "BOTWIST", DeviceType.ears, ActionCategory.ears),
    const BaseAction("Home Ears", "EARHOME", DeviceType.ears, ActionCategory.ears)
  };
}

@Riverpod(dependencies: [KnownDevices])
Map<ActionCategory, Set<BaseAction>> getAvailableActions(GetAvailableActionsRef ref) {
  Map<String, BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);
  Map<ActionCategory, Set<BaseAction>> sortedActions = {};
  for (BaseAction baseAction in ActionRegistry.allCommands) {
    Set<BaseAction>? baseActions = {};
    for (BaseStatefulDevice baseStatefulDevice in knownDevices.values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected)) {
      // check if command matches device type
      if (baseStatefulDevice.baseDeviceDefinition.deviceType == baseAction.deviceCategory) {
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
