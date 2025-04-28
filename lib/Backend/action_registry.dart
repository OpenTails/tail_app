import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'Bluetooth/bluetooth_manager.dart';
import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/device_definition.dart';
import 'audio.dart';
import 'device_registry.dart';
import 'move_lists.dart';

part 'action_registry.g.dart';

@immutable
class ActionRegistry {
  /// TODO: Changes needed for TAILCoNTROL
  /// Add DeviceType.ears to CommandAction actions
  /// Remove legacy EarMoveList and CommandAction.hiddenEars
  /// Add Ear action aliases
  static final BuiltSet<BaseAction> allCommands = {
    CommandAction(
      name: "Slow 1",
      command: "TAILS1",
      deviceCategory: [DeviceType.tail, DeviceType.wings, DeviceType.miniTail, DeviceType.ears],
      actionCategory: ActionCategory.calm,
      response: "TAILS1 END",
      uuid: "c53e980e-899e-4148-a13e-f57a8f9707f4",
      nameAlias: {
        DeviceType.wings: "Flutter 1",
      },
    ),
    CommandAction(
      name: "Slow 2",
      command: "TAILS2",
      deviceCategory: [DeviceType.tail, DeviceType.wings, DeviceType.miniTail, DeviceType.ears],
      actionCategory: ActionCategory.calm,
      response: "TAILS2 END",
      uuid: "eb1bdfe7-d374-4e97-943a-13e89f27ddcd",
      nameAlias: {
        DeviceType.wings: "Flutter 2",
      },
    ),
    CommandAction(
      name: "Slow 3",
      command: "TAILS3",
      deviceCategory: [DeviceType.tail, DeviceType.wings, DeviceType.miniTail, DeviceType.ears],
      actionCategory: ActionCategory.calm,
      response: "TAILS3 END",
      uuid: "6937b9af-3ff7-43fb-ae62-a403e5dfaf95",
      nameAlias: {
        DeviceType.wings: "Flutter 3",
      },
    ),
    CommandAction(
      name: "Fast 1",
      command: "TAILFA",
      deviceCategory: [DeviceType.tail, DeviceType.wings, DeviceType.miniTail, DeviceType.ears],
      actionCategory: ActionCategory.fast,
      response: "TAILFA END",
      uuid: "a04b558f-0ad5-410f-8e39-8f5c594791d2",
      nameAlias: {
        DeviceType.wings: "Flap 1",
      },
    ),
    CommandAction(
      name: "Fast 2",
      command: "TAILSH",
      deviceCategory: [DeviceType.tail, DeviceType.wings, DeviceType.ears],
      actionCategory: ActionCategory.fast,
      response: "TAILSH END",
      uuid: "05a4c47b-45ee-4da8-bec2-4a46f4e04a7f",
      nameAlias: {
        DeviceType.wings: "Flap 2",
      },
    ),
    CommandAction(
      name: "Fast 3",
      command: "TAILHA",
      deviceCategory: [DeviceType.tail, DeviceType.wings, DeviceType.ears],
      actionCategory: ActionCategory.fast,
      response: "TAILHA END",
      uuid: "86b13d13-b09c-46ba-a887-b40d8118b00a",
      nameAlias: {
        DeviceType.wings: "Flap 3",
      },
    ),
    CommandAction(
      name: "Fast 4",
      command: "TAILER",
      deviceCategory: [DeviceType.tail, DeviceType.wings, DeviceType.ears],
      actionCategory: ActionCategory.fast,
      response: "TAILER END",
      uuid: "5b04ca3d-a22a-4aff-8f40-99363248fcaa",
      nameAlias: {
        DeviceType.wings: "Flap 4",
      },
    ),
    CommandAction(
      name: "Tense 1",
      command: "TAILEP",
      deviceCategory: [DeviceType.tail, DeviceType.wings, DeviceType.ears],
      actionCategory: ActionCategory.tense,
      response: "TAILEP END",
      uuid: "39bbe39d-aa92-4189-ac90-4bb821a59f5e",
      nameAlias: {
        DeviceType.wings: "Rustles 1",
      },
    ),
    CommandAction(
      name: "Tense 2",
      command: "TAILT1",
      deviceCategory: [DeviceType.tail, DeviceType.wings, DeviceType.ears],
      actionCategory: ActionCategory.tense,
      response: "TAILT1 END",
      uuid: "8cc3fc60-b8d2-4f22-810a-1e042d3984f7",
      nameAlias: {
        DeviceType.wings: "Rustles 2",
      },
    ),
    CommandAction(
      name: "Tense 3",
      command: "TAILT2",
      deviceCategory: [DeviceType.tail, DeviceType.wings, DeviceType.ears],
      actionCategory: ActionCategory.tense,
      response: "TAILT2 END",
      uuid: "123557a2-5489-43da-99e2-da37a36f055a",
      nameAlias: {
        DeviceType.wings: "Rustles 3",
      },
    ),
    CommandAction(
      name: "Tense 4",
      command: "TAILET",
      deviceCategory: [DeviceType.tail, DeviceType.wings, DeviceType.ears],
      actionCategory: ActionCategory.tense,
      response: "TAILET END",
      uuid: "4909d4c2-0054-4f16-9589-6273ef6bf6c9",
      nameAlias: {
        DeviceType.wings: "Rustles 4",
      },
    ),
    CommandAction(
      name: "LEDs off",
      command: "LEDOFF",
      deviceCategory: [DeviceType.tail, DeviceType.miniTail, DeviceType.ears],
      actionCategory: ActionCategory.glowtip,
      uuid: "6b2a7fae-b58c-43f3-81bf-070aa21c2242",
    ),
    CommandAction(
      name: "Rectangle wave",
      command: "LEDREC",
      deviceCategory: [DeviceType.tail, DeviceType.miniTail, DeviceType.ears],
      actionCategory: ActionCategory.glowtip,
      uuid: "34269c91-90bd-4a34-851d-d49daa6ac863",
    ),
    CommandAction(
      name: "Triangle wave",
      command: "LEDTRI",
      deviceCategory: [DeviceType.tail, DeviceType.miniTail, DeviceType.ears],
      actionCategory: ActionCategory.glowtip,
      uuid: "64142e0b-4cc0-4b1e-845f-9c560875f993",
    ),
    CommandAction(
      name: "Sawtooth wave",
      command: "LEDSAW",
      deviceCategory: [DeviceType.tail, DeviceType.miniTail, DeviceType.ears],
      actionCategory: ActionCategory.glowtip,
      uuid: "047b84ad-3eb8-4d9c-b59b-13186cf965ca",
    ),
    CommandAction(
      name: "SOS",
      command: "LEDSOS",
      deviceCategory: [DeviceType.tail, DeviceType.miniTail, DeviceType.ears],
      actionCategory: ActionCategory.glowtip,
      uuid: "66164945-840f-4302-b27c-e7a7623bf475",
    ),
    CommandAction(
      name: "Beacon",
      command: "LEDBEA",
      deviceCategory: [DeviceType.tail, DeviceType.miniTail, DeviceType.ears],
      actionCategory: ActionCategory.glowtip,
      uuid: "4955a936-7703-4ce6-8d4a-b18857c0ea0a",
    ),
    CommandAction(
      name: "Flame",
      command: "LEDFLA",
      deviceCategory: [DeviceType.tail, DeviceType.miniTail, DeviceType.ears],
      actionCategory: ActionCategory.glowtip,
      uuid: "e46566b4-1071-4866-815b-1aefbf06b573",
    ),
    EarsMoveList(
      name: "Ears Wide",
      uuid: "d8384bcf-31ed-4b5d-a25a-da3a2f96e406",
      deviceCategory: [DeviceType.ears],
      actionCategory: ActionCategory.ears,
      commandMoves: [
        CommandAction.hiddenEars("BOTWIST 30", "BOTWIST END"),
        Move.delay(100),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList(
      name: "Double Right",
      uuid: "0d5a9dfa-38f2-4b09-9be1-cd36236a03b0",
      deviceCategory: [DeviceType.ears],
      actionCategory: ActionCategory.ears,
      commandMoves: [
        CommandAction.hiddenEars("LETWIST 20", "LETWIST END"),
        Move.delay(25),
        CommandAction.hiddenEars("LETWIST 90", "LETWIST END"),
        CommandAction.hiddenEars("LETWIST 20", "LETWIST END"),
        Move.delay(25),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList(
      name: "Double Left",
      uuid: "9a6be63e-36f5-4f50-88b6-7adf2680aa5c",
      deviceCategory: [DeviceType.ears],
      actionCategory: ActionCategory.ears,
      commandMoves: [
        CommandAction.hiddenEars("RITWIST 20", "RITWIST END"),
        Move.delay(25),
        CommandAction.hiddenEars("RITWIST 90", "RITWIST END"),
        CommandAction.hiddenEars("RITWIST 20", "RITWIST END"),
        Move.delay(25),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList(
      name: "Right Listen",
      uuid: "83590dc9-f9de-4134-bcc7-8157a62a33ef",
      deviceCategory: [DeviceType.ears],
      actionCategory: ActionCategory.ears,
      commandMoves: [
        CommandAction.hiddenEars("LETWIST 20", "LETWIST END"),
        CommandAction.hiddenEars("RITWIST 100", "RITWIST END"),
        Move.delay(100),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList(
      name: "Left Listen",
      uuid: "007c52d3-242a-4e27-bccc-b4b737502bfb",
      deviceCategory: [DeviceType.ears],
      actionCategory: ActionCategory.ears,
      commandMoves: [
        CommandAction.hiddenEars("RITWIST 20", "RITWIST END"),
        CommandAction.hiddenEars("LETWIST 100", "LETWIST END"),
        Move.delay(100),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList(
      name: "Flick Left",
      uuid: "769dbe84-3a6e-440d-8b20-234983d36cb6",
      deviceCategory: [DeviceType.ears],
      actionCategory: ActionCategory.ears,
      commandMoves: [
        CommandAction.hiddenEars("RITWIST 30", "RITWIST END"),
        Move.delay(100),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList(
      name: "Flick Right",
      uuid: "23144b42-6d3c-4822-8510-ec03c63c7808",
      deviceCategory: [DeviceType.ears],
      actionCategory: ActionCategory.ears,
      commandMoves: [
        CommandAction.hiddenEars("LETWIST 30", "LETWIST END"),
        Move.delay(100),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    EarsMoveList(
      name: "Hewo",
      uuid: "fdaff205-0a51-46a0-a5fc-4ea283dce079",
      deviceCategory: [DeviceType.ears],
      actionCategory: ActionCategory.ears,
      commandMoves: [
        CommandAction.hiddenEars("LETWIST 30", "LETWIST END"),
        Move.delay(50),
        CommandAction.hiddenEars("RITWIST 30", "RITWIST END"),
        Move.delay(150),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
  }.build();
}

@Riverpod(keepAlive: true)
class GetAvailableActions extends _$GetAvailableActions {
  @override
  BuiltMap<ActionCategory, BuiltSet<BaseAction>> build() {
    for (BaseStatefulDevice baseStatefulDevice in ref.watch(knownDevicesProvider).values) {
      baseStatefulDevice.hasGlowtip
        ..removeListener(_listener)
        ..addListener(_listener);
      baseStatefulDevice.isTailCoNTROL
        ..removeListener(_listener)
        ..addListener(_listener);
    }
    return getState();
  }

  BuiltMap<ActionCategory, BuiltSet<BaseAction>> getState() {
    Map<ActionCategory, Set<BaseAction>> sortedActions = {};
    final BuiltMap<ActionCategory, BuiltSet<BaseAction>> allActions = ref.watch(getAllActionsProvider);
    final BuiltList<BaseStatefulDevice> availableGear = ref.watch(getAvailableGearProvider);
    for (BaseAction baseAction in allActions.values.flattened) {
      Set<BaseAction>? baseActions = {};
      for (BaseStatefulDevice baseStatefulDevice in availableGear) {
        // check if command matches device type
        if (baseAction.deviceCategory.contains(baseStatefulDevice.baseDeviceDefinition.deviceType) &&
            ((baseAction.actionCategory == ActionCategory.glowtip &&
                    baseStatefulDevice.hasGlowtip.value == GlowtipStatus.glowtip) ||
                baseAction.actionCategory != ActionCategory.glowtip)) {
          // Handle migrating ears to unified firmware
          if (baseAction.deviceCategory.contains(DeviceType.ears) &&
              baseStatefulDevice.baseDeviceDefinition.deviceType == DeviceType.ears) {
            if (baseStatefulDevice.isTailCoNTROL.value == TailControlStatus.tailControl) {
              // skip legacy moves
              if (baseAction is EarsMoveList) {
                continue;
              }
              // skip unified moves for legacy firmware ears
            } else if (baseStatefulDevice.isTailCoNTROL.value == TailControlStatus.legacy) {
              if (baseAction is CommandAction) {
                continue;
              }
            }
          }

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
    return BuiltMap(
      sortedActions.map(
        (key, value) => MapEntry(key, value.build()),
      ),
    );
  }

  void _listener() {
    state = getState();
  }
}

@Riverpod(keepAlive: true)
BuiltMap<ActionCategory, BuiltSet<BaseAction>> getAllActions(Ref ref) {
  Map<ActionCategory, Set<BaseAction>> sortedActions = {};
  final BuiltList<MoveList> moveLists = ref.watch(moveListsProvider);
  final BuiltList<AudioAction> audioActions = ref.watch(userAudioActionsProvider);
  for (BaseAction baseAction in List.from(ActionRegistry.allCommands)
    ..addAll(moveLists)
    ..addAll(audioActions)) {
    Set<BaseAction>? baseActions = {};
    // get category if it exists
    if (sortedActions.containsKey(baseAction.actionCategory)) {
      baseActions = sortedActions[baseAction.actionCategory];
    }
    // add action to category
    baseActions?.add(baseAction);
    // store result
    if (baseActions != null && baseActions.isNotEmpty) {
      sortedActions[baseAction.actionCategory] = baseActions;
    }
  }
  return BuiltMap(
    sortedActions.map(
      (key, value) => MapEntry(key, value.build()),
    ),
  );
}

@Riverpod(keepAlive: true)
BaseAction? getActionFromUUID(Ref ref, String? uuid) {
  if (uuid == null) {
    return null;
  }
  final BuiltMap<ActionCategory, BuiltSet<BaseAction>> watch = ref.watch(getAllActionsProvider);
  return watch.values.flattened.where((element) => element.uuid == uuid).firstOrNull;
}
