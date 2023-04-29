import 'package:flutter/cupertino.dart';

import 'Definitions/Action/BaseAction.dart';
import 'Definitions/Device/BaseDeviceDefinition.dart';

@immutable
class ActionRegistry {
  static const Set<BaseAction> allCommands = {
    BaseAction("Slow wag 1", "TAILS1", DeviceType.tail, ActionCategory.calm),
    BaseAction("Slow wag 2", "TAILS2", DeviceType.tail, ActionCategory.calm),
    BaseAction("Slow wag 3", "TAILS3", DeviceType.tail, ActionCategory.calm),
    BaseAction("Fast wag", "TAILFA", DeviceType.tail, ActionCategory.fast),
    BaseAction("Short wag", "TAILSH", DeviceType.tail, ActionCategory.fast),
    BaseAction("Happy wag", "TAILHA", DeviceType.tail, ActionCategory.fast),
    BaseAction("Erect", "TAILER", DeviceType.tail, ActionCategory.fast),
    BaseAction("Erect Pulse", "TAILEP", DeviceType.tail, ActionCategory.tense),
    BaseAction("Tremble 1", "TAILT1", DeviceType.tail, ActionCategory.tense),
    BaseAction("Tremble 2", "TAILT2", DeviceType.tail, ActionCategory.tense),
    BaseAction(
        "Erect Tremble", "TAILET", DeviceType.tail, ActionCategory.tense),
    BaseAction(
        "User Defined 1", "TAILU1", DeviceType.tail, ActionCategory.user),
    BaseAction(
        "User Defined 2", "TAILU2", DeviceType.tail, ActionCategory.user),
    BaseAction(
        "User Defined 3", "TAILU3", DeviceType.tail, ActionCategory.user),
    BaseAction(
        "User Defined 4", "TAILU4", DeviceType.tail, ActionCategory.user),
    BaseAction("LEDs off", "LEDOFF", DeviceType.tail, ActionCategory.glowtip),
    BaseAction(
        "Rectangle wave", "LEDREC", DeviceType.tail, ActionCategory.glowtip),
    BaseAction(
        "Triangle wave", "LEDTRI", DeviceType.tail, ActionCategory.glowtip),
    BaseAction(
        "Sawtooth wave", "LEDSAW", DeviceType.tail, ActionCategory.glowtip),
    BaseAction("SOS", "LEDSOS", DeviceType.tail, ActionCategory.glowtip),
    BaseAction("Beacon", "LEDBEA", DeviceType.tail, ActionCategory.glowtip),
    BaseAction("Flame", "LEDFLA", DeviceType.tail, ActionCategory.glowtip),
    BaseAction(
        "User Defined 1", "LEDUS1", DeviceType.tail, ActionCategory.user),
    BaseAction(
        "User Defined 2", "LEDUS2", DeviceType.tail, ActionCategory.user),
    BaseAction(
        "User Defined 3", "LEDUS3", DeviceType.tail, ActionCategory.user),
    BaseAction(
        "User Defined 4", "LEDUS4", DeviceType.tail, ActionCategory.user),
    BaseAction("Left Twist", "LETWIST", DeviceType.ears, ActionCategory.other),
    BaseAction("Right Twist", "RITWIST", DeviceType.ears, ActionCategory.other),
    BaseAction("Both Twist", "BOTWIST", DeviceType.ears, ActionCategory.other)
  };

  static Map<ActionCategory, Set<BaseAction>> getSortedActions() {
    Map<ActionCategory, Set<BaseAction>> sortedActions = {};
    for (BaseAction baseAction in allCommands) {
      Set<BaseAction>? baseActions = {};
      if (sortedActions.containsKey(baseAction.actionCategory)) {
        baseActions = sortedActions[baseAction.actionCategory];
      }
      baseActions?.add(baseAction);
      sortedActions[baseAction.actionCategory] = baseActions!;
    }
    return sortedActions;
  }
}
