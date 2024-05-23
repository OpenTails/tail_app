import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/move_lists.dart';

import '../constants.dart';
import 'Bluetooth/bluetooth_manager.dart';
import 'Bluetooth/bluetooth_manager_plus.dart';
import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/device_definition.dart';
import 'app_shortcuts.dart';

part 'action_registry.g.dart';

final actionRegistryLogger = Logger('ActionRegistry');

@immutable
class ActionRegistry {
  static Set<BaseAction> allCommands = {
    CommandAction("Slow 1", "TAILS1", [DeviceType.tail, DeviceType.wings], ActionCategory.calm, "TAILS1 END", "c53e980e-899e-4148-a13e-f57a8f9707f4"),
    CommandAction("Slow 2", "TAILS2", [DeviceType.tail, DeviceType.wings], ActionCategory.calm, "TAILS2 END", "eb1bdfe7-d374-4e97-943a-13e89f27ddcd"),
    CommandAction("Slow 3", "TAILS3", [DeviceType.tail, DeviceType.wings], ActionCategory.calm, "TAILS3 END", "6937b9af-3ff7-43fb-ae62-a403e5dfaf95"),
    CommandAction("Fast", "TAILFA", [DeviceType.tail, DeviceType.wings], ActionCategory.fast, "TAILFA END", "a04b558f-0ad5-410f-8e39-8f5c594791d2"),
    CommandAction("Short", "TAILSH", [DeviceType.tail, DeviceType.wings], ActionCategory.fast, "TAILSH END", "05a4c47b-45ee-4da8-bec2-4a46f4e04a7f"),
    CommandAction("Happy", "TAILHA", [DeviceType.tail, DeviceType.wings], ActionCategory.fast, "TAILHA END", "86b13d13-b09c-46ba-a887-b40d8118b00a"),
    CommandAction("Erect", "TAILER", [DeviceType.tail, DeviceType.wings], ActionCategory.fast, "TAILER END", "5b04ca3d-a22a-4aff-8f40-99363248fcaa"),
    CommandAction("Pulse", "TAILEP", [DeviceType.tail, DeviceType.wings], ActionCategory.tense, "TAILEP END", "39bbe39d-aa92-4189-ac90-4bb821a59f5e"),
    CommandAction("Tremble 1", "TAILT1", [DeviceType.tail, DeviceType.wings], ActionCategory.tense, "TAILT1 END", "8cc3fc60-b8d2-4f22-810a-1e042d3984f7"),
    CommandAction("Tremble 2", "TAILT2", [DeviceType.tail, DeviceType.wings], ActionCategory.tense, "TAILT2 END", "123557a2-5489-43da-99e2-da37a36f055a"),
    CommandAction("Tremble 3", "TAILET", [DeviceType.tail, DeviceType.wings], ActionCategory.tense, "TAILET END", "4909d4c2-0054-4f16-9589-6273ef6bf6c9"),
    CommandAction("LEDs off", "LEDOFF", [DeviceType.tail], ActionCategory.glowtip, null, "6b2a7fae-b58c-43f3-81bf-070aa21c2242"),
    CommandAction("Rectangle wave", "LEDREC", [DeviceType.tail], ActionCategory.glowtip, null, "34269c91-90bd-4a34-851d-d49daa6ac863"),
    CommandAction("Triangle wave", "LEDTRI", [DeviceType.tail], ActionCategory.glowtip, null, "64142e0b-4cc0-4b1e-845f-9c560875f993"),
    CommandAction("Sawtooth wave", "LEDSAW", [DeviceType.tail], ActionCategory.glowtip, null, "047b84ad-3eb8-4d9c-b59b-13186cf965ca"),
    CommandAction("SOS", "LEDSOS", [DeviceType.tail], ActionCategory.glowtip, null, "66164945-840f-4302-b27c-e7a7623bf475"),
    CommandAction("Beacon", "LEDBEA", [DeviceType.tail], ActionCategory.glowtip, null, "4955a936-7703-4ce6-8d4a-b18857c0ea0a"),
    CommandAction("Flame", "LEDFLA", [DeviceType.tail], ActionCategory.glowtip, null, "e46566b4-1071-4866-815b-1aefbf06b573"),
    //CommandAction("Left Twist", "LETWIST", [DeviceType.ears], ActionCategory.ears, "LETWIST END", "0d5a9dfa-38f2-4b09-9be1-cd36236a03b0"),
    //CommandAction("Right Twist", "RITWIST", [DeviceType.ears], ActionCategory.ears, "RITWIST END", "9a6be63e-36f5-4f50-88b6-7adf2680aa5c"),
    //CommandAction("Both Twist", "BOTWIST", [DeviceType.ears], ActionCategory.ears, "BOTWIST END", "2bc43e6c-65e7-4a35-834e-b2c31b8f83fe"),
    //CommandAction("Home Ears", "EARHOME", [DeviceType.ears], ActionCategory.ears, "EARHOME END", "cdd2e0ac-97a2-41d7-9ece-8d4dce4829d7"),
    EarsMoveList.builtIn(
      "Ears Wide",
      "d8384bcf-31ed-4b5d-a25a-da3a2f96e406",
      [
        CommandAction.hiddenEars("BOTWIST 30", "BOTWIST END"),
        Move.delay(100),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList.builtIn(
      "Double Left",
      "0d5a9dfa-38f2-4b09-9be1-cd36236a03b0",
      [
        CommandAction.hiddenEars("LETWIST 20", "LETWIST END"),
        Move.delay(25),
        CommandAction.hiddenEars("LETWIST 90", "LETWIST END"),
        CommandAction.hiddenEars("LETWIST 20", "LETWIST END"),
        Move.delay(25),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList.builtIn(
      "Double Right",
      "9a6be63e-36f5-4f50-88b6-7adf2680aa5c",
      [
        CommandAction.hiddenEars("RITWIST 20", "RITWIST END"),
        Move.delay(25),
        CommandAction.hiddenEars("RITWIST 90", "RITWIST END"),
        CommandAction.hiddenEars("RITWIST 20", "RITWIST END"),
        Move.delay(25),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList.builtIn(
      "Left Listen",
      "83590dc9-f9de-4134-bcc7-8157a62a33ef",
      [
        CommandAction.hiddenEars("LETWIST 20", "LETWIST END"),
        CommandAction.hiddenEars("RITWIST 100", "RITWIST END"),
        Move.delay(100),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList.builtIn(
      "Right Listen",
      "007c52d3-242a-4e27-bccc-b4b737502bfb",
      [
        CommandAction.hiddenEars("RITWIST 20", "RITWIST END"),
        CommandAction.hiddenEars("LETWIST 100", "LETWIST END"),
        Move.delay(100),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList.builtIn(
      "Flick Right",
      "769dbe84-3a6e-440d-8b20-234983d36cb6",
      [
        CommandAction.hiddenEars("RITWIST 30", "RITWIST END"),
        Move.delay(100),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList.builtIn(
      "Flick Left",
      "23144b42-6d3c-4822-8510-ec03c63c7808",
      [
        CommandAction.hiddenEars("LETWIST 30", "LETWIST END"),
        Move.delay(100),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList.builtIn(
      "Hewo",
      "fdaff205-0a51-46a0-a5fc-4ea283dce079",
      [
        CommandAction.hiddenEars("LETWIST 30", "LETWIST END"),
        Move.delay(50),
        CommandAction.hiddenEars("RITWIST 30", "RITWIST END"),
        Move.delay(150),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
  };
}

@Riverpod(keepAlive: false)
Map<ActionCategory, Set<BaseAction>> getAvailableActions(GetAvailableActionsRef ref) {
  if (!isAnyGearConnected.value) {
    return {};
  }
  Map<String, BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);
  Map<ActionCategory, Set<BaseAction>> sortedActions = {};
  for (BaseAction baseAction in List.from(ActionRegistry.allCommands)..addAll(ref.read(moveListsProvider))) {
    Set<BaseAction>? baseActions = {};
    for (BaseStatefulDevice baseStatefulDevice in knownDevices.values.where((element) => element.deviceConnectionState.value == ConnectivityState.connected)) {
      // check if command matches device type
      if (baseAction.deviceCategory.contains(baseStatefulDevice.baseDeviceDefinition.deviceType) && ((baseAction.actionCategory == ActionCategory.glowtip && baseStatefulDevice.hasGlowtip.value) || baseAction.actionCategory != ActionCategory.glowtip)) {
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

@riverpod
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

@HiveType(typeId: 13)
class FavoriteAction implements Comparable<FavoriteAction> {
  @HiveField(1)
  String actionUUID;
  @HiveField(2)
  int id;

  FavoriteAction({required this.actionUUID, required this.id});

  @override
  int compareTo(other) {
    id.compareTo(other.id);
    return 0;
  }
}

@Riverpod(keepAlive: true)
class FavoriteActions extends _$FavoriteActions {
  @override
  List<FavoriteAction> build() {
    List<FavoriteAction> results = [];
    try {
      results = SentryHive.box<FavoriteAction>(favoriteActionsBox).values.toList(growable: true);
    } catch (e, s) {
      actionRegistryLogger.severe("Unable to load favorites: $e", e, s);
    }
    return results;
  }

  void add(BaseAction action) {
    state.add(FavoriteAction(actionUUID: action.uuid, id: state.length + 1));
    state.sort();
    store();
  }

  void remove(BaseAction action) {
    state.removeWhere((element) => element.actionUUID == action.uuid);
    store();
  }

  bool contains(BaseAction action) {
    return state.any((element) => element.actionUUID == action.uuid);
  }

  Future<void> store() async {
    actionRegistryLogger.info("Storing favorites");
    SentryHive.box<FavoriteAction>(favoriteActionsBox)
      ..clear()
      ..addAll(state);
    updateShortcuts(ref);
  }
}
