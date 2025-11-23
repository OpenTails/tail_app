import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Frontend/utils.dart';

import 'Bluetooth/known_devices.dart';
import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/device_definition.dart';
import 'audio.dart';
import 'move_lists.dart';

part 'action_registry.g.dart';

@immutable
class ActionRegistry {
  static final BuiltSet<BaseAction> clawMoves = {
    CommandAction(name: "Extend Slow", command: "MOVE1", deviceCategory: [DeviceType.claws], response: "MOVE1 END", uuid: "a373f116-4c0a-4ab7-894d-caedc4e76d1d"),
    CommandAction(name: "Extend Fast", command: "MOVE2", deviceCategory: [DeviceType.claws], response: "MOVE2 END", uuid: "9446d5a2-7178-4177-ad61-29f7e8980791"),
    CommandAction(name: "1/2 Extend Slow", command: "MOVE3", deviceCategory: [DeviceType.claws], response: "MOVE3 END", uuid: "2eb1278a-d366-4406-99cd-26710dbd6417"),
    CommandAction(name: "1/2 Extend Fast", command: "MOVE4", deviceCategory: [DeviceType.claws], response: "MOVE4 END", uuid: "f17a781a-670e-4365-ba4b-18c8f503da56"),
    CommandAction(name: "Retract Slow", command: "MOVE5", deviceCategory: [DeviceType.claws], response: "MOVE5 END", uuid: "9074fb1f-1526-467e-8a84-a4752d9160f1"),
    CommandAction(name: "Retract Fast", command: "MOVE6", deviceCategory: [DeviceType.claws], response: "MOVE6 END", uuid: "08d19e6c-fed7-46b5-8c49-e019d74b5ac9"),
    CommandAction(name: "Rawr", command: "RAWR", deviceCategory: [DeviceType.claws], response: "RAWR END", uuid: "58b5465f-2f1b-492d-9390-ea0d43d2ee90"),
  }.build();

  static final BuiltSet<BaseAction> earMoves = {
    //TailControl only
    CommandAction(name: "Slow Forward", command: "TAILS1", deviceCategory: [DeviceType.ears], response: "TAILS1 END", uuid: "a463cdb0-6d23-480b-9478-3db25828e764"),
    CommandAction(name: "Slow left", command: "TAILS2", deviceCategory: [DeviceType.ears], response: "TAILS2 END", uuid: "c53e2db5-a425-4280-ba4b-91e193d7b445"),
    CommandAction(name: "Slow Right", command: "TAILS3", deviceCategory: [DeviceType.ears], response: "TAILS3 END", uuid: "2518178a-c6b6-45c5-9bb0-9cf932e7f06a"),
    //TailControl and Legacy
    CommandAction(
      name: "Ears Wide",
      command: "TAILHA",
      uuid: "d8384bcf-31ed-4b5d-a25a-da3a2f96e406",
      deviceCategory: [DeviceType.ears],
      response: "TAILHA END",
      legacyEarCommandMoves: [CommandAction.hiddenEars("BOTWIST 30", "BOTWIST END"), Move.delay(100), CommandAction.hiddenEars("EARHOME", "EARHOME END")],
    ),
    CommandAction(
      name: "Double Right",
      uuid: "0d5a9dfa-38f2-4b09-9be1-cd36236a03b0",
      command: "TAILEP",
      deviceCategory: [DeviceType.ears],
      response: "TAILEP END",
      legacyEarCommandMoves: [
        CommandAction.hiddenEars("LETWIST 20", "LETWIST END"),
        Move.delay(25),
        CommandAction.hiddenEars("LETWIST 90", "LETWIST END"),
        CommandAction.hiddenEars("LETWIST 20", "LETWIST END"),
        Move.delay(25),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    CommandAction(
      name: "Double Left",
      uuid: "9a6be63e-36f5-4f50-88b6-7adf2680aa5c",
      command: "TAILET",
      deviceCategory: [DeviceType.ears],
      response: "TAILET END",
      legacyEarCommandMoves: [
        CommandAction.hiddenEars("RITWIST 20", "RITWIST END"),
        Move.delay(25),
        CommandAction.hiddenEars("RITWIST 90", "RITWIST END"),
        CommandAction.hiddenEars("RITWIST 20", "RITWIST END"),
        Move.delay(25),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    CommandAction(
      name: "Right Listen",
      uuid: "83590dc9-f9de-4134-bcc7-8157a62a33ef",
      command: "TAILSH",
      deviceCategory: [DeviceType.ears],
      response: "TAILSH END",
      legacyEarCommandMoves: [
        CommandAction.hiddenEars("LETWIST 20", "LETWIST END"),
        CommandAction.hiddenEars("RITWIST 100", "RITWIST END"),
        Move.delay(100),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    CommandAction(
      name: "Left Listen",
      uuid: "007c52d3-242a-4e27-bccc-b4b737502bfb",
      command: "TAILFA",
      deviceCategory: [DeviceType.ears],
      response: "TAILFA END",
      legacyEarCommandMoves: [
        CommandAction.hiddenEars("RITWIST 20", "RITWIST END"),
        CommandAction.hiddenEars("LETWIST 100", "LETWIST END"),
        Move.delay(100),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
    CommandAction(
      name: "Flick Left",
      uuid: "769dbe84-3a6e-440d-8b20-234983d36cb6",
      command: "TAILT1",
      deviceCategory: [DeviceType.ears],
      response: "TAILT1 END",
      legacyEarCommandMoves: [CommandAction.hiddenEars("RITWIST 30", "RITWIST END"), Move.delay(100), CommandAction.hiddenEars("EARHOME", "EARHOME END")],
    ),
    CommandAction(
      name: "Flick Right",
      uuid: "23144b42-6d3c-4822-8510-ec03c63c7808",
      command: "TAILT2",
      deviceCategory: [DeviceType.ears],
      response: "TAILT2 END",
      legacyEarCommandMoves: [CommandAction.hiddenEars("LETWIST 30", "LETWIST END"), Move.delay(100), CommandAction.hiddenEars("EARHOME", "EARHOME END")],
    ),
    CommandAction(
      name: "Hewo",
      uuid: "fdaff205-0a51-46a0-a5fc-4ea283dce079",
      command: "TAILER",
      deviceCategory: [DeviceType.ears],
      response: "TAILER END",
      legacyEarCommandMoves: [
        CommandAction.hiddenEars("LETWIST 30", "LETWIST END"),
        Move.delay(50),
        CommandAction.hiddenEars("RITWIST 30", "RITWIST END"),
        Move.delay(150),
        CommandAction.hiddenEars("EARHOME", "EARHOME END"),
      ],
    ),
  }.build();

  static final BuiltSet<BaseAction> glowtipCommands = {
    CommandAction(name: "LEDs off", command: "LEDOFF", deviceCategory: DeviceType.values, actionCategory: ActionCategory.glowtip, uuid: "6b2a7fae-b58c-43f3-81bf-070aa21c2242"),
    CommandAction(name: "Rectangle wave", command: "LEDREC", deviceCategory: DeviceType.values, actionCategory: ActionCategory.glowtip, uuid: "34269c91-90bd-4a34-851d-d49daa6ac863"),
    CommandAction(name: "Triangle wave", command: "LEDTRI", deviceCategory: DeviceType.values, actionCategory: ActionCategory.glowtip, uuid: "64142e0b-4cc0-4b1e-845f-9c560875f993"),
    CommandAction(name: "Sawtooth wave", command: "LEDSAW", deviceCategory: DeviceType.values, actionCategory: ActionCategory.glowtip, uuid: "047b84ad-3eb8-4d9c-b59b-13186cf965ca"),
    CommandAction(name: "SOS", command: "LEDSOS", deviceCategory: DeviceType.values, actionCategory: ActionCategory.glowtip, uuid: "66164945-840f-4302-b27c-e7a7623bf475"),
    CommandAction(name: "Beacon", command: "LEDBEA", deviceCategory: DeviceType.values, actionCategory: ActionCategory.glowtip, uuid: "4955a936-7703-4ce6-8d4a-b18857c0ea0a"),
    CommandAction(name: "Flame", command: "LEDFLA", deviceCategory: DeviceType.values, actionCategory: ActionCategory.glowtip, uuid: "e46566b4-1071-4866-815b-1aefbf06b573"),
  }.build();

  static final BuiltSet<BaseAction> rgbCommands = {
    CommandAction(name: "LEDs off", command: "RGBOFF", deviceCategory: DeviceType.values, actionCategory: ActionCategory.rgb, uuid: "3b40bd70-c90c-4939-a3e8-d3910a54cf9d"),
    CommandAction(name: "Rainbow", command: "RGBRBO", deviceCategory: DeviceType.values, actionCategory: ActionCategory.rgb, uuid: "f5cc3750-006c-4f89-be7c-36e4e3a16d39"),
    CommandAction(name: "Rainbow Sparkles", command: "RGBRB2", deviceCategory: DeviceType.values, actionCategory: ActionCategory.rgb, uuid: "0ce16767-bbab-4cd5-9c9c-421f7edad3ee"),
    CommandAction(name: "Rainbow Confetti", command: "RGBCON", deviceCategory: DeviceType.values, actionCategory: ActionCategory.rgb, uuid: "cbaf45fb-45be-424a-a6e1-01ba49ceabee"),
    CommandAction(name: "Rainbow Sine", command: "RGBSIN", deviceCategory: DeviceType.values, actionCategory: ActionCategory.rgb, uuid: "8e084317-13de-4bf5-a7ce-29a36021402c"),
    CommandAction(name: "Rainbow Jungle", command: "RGBJUG", deviceCategory: DeviceType.values, actionCategory: ActionCategory.rgb, uuid: "b5d93f4d-cf9c-433d-a739-c7316e3008b0"),
    CommandAction(name: "Rainbow BPM", command: "RGBBPM", deviceCategory: DeviceType.values, actionCategory: ActionCategory.rgb, uuid: "7837e80a-98d8-4eb1-8208-cb209579d511"),
    CommandAction(name: "Demo", command: "RGBDMO", deviceCategory: DeviceType.values, actionCategory: ActionCategory.rgb, uuid: "01f2f0b3-7ba4-4a14-9405-f8e412073ce0"),
  }.build();
  static final BuiltSet<BaseAction> tailMoves = {
    CommandAction(name: "Slow Wag 1", command: "TAILS1", deviceCategory: [DeviceType.tail], response: "TAILS1 END", uuid: "c53e980e-899e-4148-a13e-f57a8f9707f4"),
    CommandAction(name: "Slow Wag 2", command: "TAILS2", deviceCategory: [DeviceType.tail], response: "TAILS2 END", uuid: "eb1bdfe7-d374-4e97-943a-13e89f27ddcd"),
    CommandAction(name: "Slow Wag 3", command: "TAILS3", deviceCategory: [DeviceType.tail], response: "TAILS3 END", uuid: "6937b9af-3ff7-43fb-ae62-a403e5dfaf95"),
    CommandAction(name: "Fast Wag", command: "TAILFA", deviceCategory: [DeviceType.tail], response: "TAILFA END", uuid: "a04b558f-0ad5-410f-8e39-8f5c594791d2"),
    CommandAction(name: "Short Wag", command: "TAILSH", deviceCategory: [DeviceType.tail], response: "TAILSH END", uuid: "05a4c47b-45ee-4da8-bec2-4a46f4e04a7f"),
    CommandAction(name: "Happy Wag", command: "TAILHA", deviceCategory: [DeviceType.tail], response: "TAILHA END", uuid: "86b13d13-b09c-46ba-a887-b40d8118b00a"),
    CommandAction(name: "Lift", command: "TAILER", deviceCategory: [DeviceType.tail], response: "TAILER END", uuid: "5b04ca3d-a22a-4aff-8f40-99363248fcaa"),
    CommandAction(name: "Lift Pulse", command: "TAILEP", deviceCategory: [DeviceType.tail], response: "TAILEP END", uuid: "39bbe39d-aa92-4189-ac90-4bb821a59f5e"),
    CommandAction(name: "Tense Wag 1", command: "TAILT1", deviceCategory: [DeviceType.tail], response: "TAILT1 END", uuid: "8cc3fc60-b8d2-4f22-810a-1e042d3984f7"),
    CommandAction(name: "Tense Wag 2", command: "TAILT2", deviceCategory: [DeviceType.tail], response: "TAILT2 END", uuid: "123557a2-5489-43da-99e2-da37a36f055a"),
    CommandAction(name: "Lift Tremble", command: "TAILET", deviceCategory: [DeviceType.tail], response: "TAILET END", uuid: "4909d4c2-0054-4f16-9589-6273ef6bf6c9"),
  }.build();
  static final BuiltSet<BaseAction> miniTailMoves = {
    CommandAction(name: "Wag 1", command: "TAILS1", deviceCategory: [DeviceType.miniTail], response: "TAILS1 END", uuid: "f44b2ce8-ca8e-493c-98eb-74149e9ae0a5"),
    CommandAction(name: "Wag 2", command: "TAILS2", deviceCategory: [DeviceType.miniTail], response: "TAILS2 END", uuid: "7e6cb80d-e78a-4179-8194-04f7068a43bb"),
    CommandAction(name: "Wag 3", command: "TAILS3", deviceCategory: [DeviceType.miniTail], response: "TAILS3 END", uuid: "78a1304c-33ec-4722-b808-231deb2efc30"),
    CommandAction(name: "Wag 4", command: "TAILFA", deviceCategory: [DeviceType.miniTail], response: "TAILFA END", uuid: "86852cff-b640-4e8d-a482-ac16d909f107"),
  }.build();
  static final BuiltSet<BaseAction> flutterWingsMoves = {
    CommandAction(name: "Flutter 1", command: "TAILS1", deviceCategory: [DeviceType.wings], response: "TAILS1 END", uuid: "de9cb3f5-79a3-49aa-ab6d-1a21be9c88ff"),
    CommandAction(name: "Flutter 2", command: "TAILS2", deviceCategory: [DeviceType.wings], response: "TAILS2 END", uuid: "c0868d65-0651-4697-b1f9-b5d641da6d83"),
    CommandAction(name: "Flutter 3", command: "TAILS3", deviceCategory: [DeviceType.wings], response: "TAILS3 END", uuid: "7333bb98-a989-401a-9052-94b8374df34e"),
    CommandAction(name: "Flap 1", command: "TAILFA", deviceCategory: [DeviceType.wings], response: "TAILFA END", uuid: "f404f3fe-c7e0-47f6-98a7-b231f799683e"),
    CommandAction(name: "Flap 2", command: "TAILSH", deviceCategory: [DeviceType.wings], response: "TAILSH END", uuid: "9eb0a78c-027b-4a36-ab40-e7e36fe68f70"),
    CommandAction(name: "Flap 3", command: "TAILHA", deviceCategory: [DeviceType.wings], response: "TAILHA END", uuid: "642855ef-d211-4ada-b737-ecd2aaf05ed2"),
    CommandAction(name: "Flap 4", command: "TAILER", deviceCategory: [DeviceType.wings], response: "TAILER END", uuid: "4af89565-2612-4bdf-a6e3-61d38cf96fc1"),
    CommandAction(name: "Rustles 1", command: "TAILEP", deviceCategory: [DeviceType.wings], response: "TAILEP END", uuid: "fbdc0003-a477-433e-9e07-ac2ac5323275"),
    CommandAction(name: "Rustles 2", command: "TAILT1", deviceCategory: [DeviceType.wings], response: "TAILT1 END", uuid: "909fabdd-5403-4fb0-9e49-68bde1140647"),
    CommandAction(name: "Rustles 3", command: "TAILT2", deviceCategory: [DeviceType.wings], response: "TAILT2 END", uuid: "5f7e16e4-04f6-46ab-bbc9-e6f908fc559c"),
    CommandAction(name: "Rustles 4", command: "TAILET", deviceCategory: [DeviceType.wings], response: "TAILET END", uuid: "0dfeb464-572b-452b-be4a-5a36affd2da9"),
  }.build();
  static final BuiltSet<BaseAction> allCommands = BuiltSet<BaseAction>()
      .union(glowtipCommands)
      .union(earMoves)
      .union(flutterWingsMoves)
      .union(miniTailMoves)
      .union(tailMoves)
      .union(rgbCommands)
      .union(clawMoves);
}

@Riverpod(keepAlive: true)
class GetAvailableActions extends _$GetAvailableActions {
  @override
  BuiltMap<String, BuiltSet<BaseAction>> build() {
    KnownDevices.instance
      ..removeListener(onDeviceConnected)
      ..addListener(onDeviceConnected);
    for (BaseStatefulDevice baseStatefulDevice in KnownDevices.instance.state.values) {
      baseStatefulDevice.hasGlowtip
        ..removeListener(_listener)
        ..addListener(_listener);
      baseStatefulDevice.hasRGB
        ..removeListener(_listener)
        ..addListener(_listener);
      baseStatefulDevice.isTailCoNTROL
        ..removeListener(_listener)
        ..addListener(_listener);
    }
    return getState();
  }

  void onDeviceConnected() {
    ref.invalidateSelf();
  }

  BuiltMap<String, BuiltSet<BaseAction>> getState() {
    Map<String, Set<BaseAction>> sortedActions = {};
    final BuiltMap<String, BuiltSet<BaseAction>> allActions = ref.watch(getAllActionsProvider);
    final BuiltList<BaseStatefulDevice> availableGear = KnownDevices.instance.connectedGear;
    for (BaseAction baseAction in allActions.values.flattened) {
      Set<BaseAction>? baseActions = {};
      for (BaseStatefulDevice baseStatefulDevice in availableGear) {
        // check if command matches device type
        Set<ActionCategory> lightMoveCategories = {ActionCategory.glowtip, ActionCategory.rgb};
        bool isNotLightMove = !lightMoveCategories.contains(baseAction.actionCategory);

        bool shouldIncludeGlowtipMove = baseAction.actionCategory == ActionCategory.glowtip && baseStatefulDevice.hasGlowtip.value == GlowtipStatus.glowtip;
        bool shouldIncludeRGBMove = baseAction.actionCategory == ActionCategory.rgb && baseStatefulDevice.hasRGB.value == RGBStatus.rgb;

        bool shouldIncludeLightMove = shouldIncludeRGBMove || shouldIncludeGlowtipMove;
        bool skipActionForLegacyEars =
            baseAction is CommandAction &&
            baseAction.legacyEarCommandMoves == null &&
            baseAction.deviceCategory.length == 1 &&
            baseAction.deviceCategory.first == DeviceType.ears &&
            baseStatefulDevice.baseDeviceDefinition.deviceType == DeviceType.ears &&
            baseStatefulDevice.isTailCoNTROL.value == TailControlStatus.legacy;

        if (!skipActionForLegacyEars && baseAction.deviceCategory.contains(baseStatefulDevice.baseDeviceDefinition.deviceType) && (shouldIncludeLightMove || isNotLightMove)) {
          //filter out the three tailcontrol actions on legacy ears

          // get category if it exists
          if (sortedActions.containsKey(baseAction.getCategoryName())) {
            baseActions = sortedActions[baseAction.getCategoryName()];
          }
          // add action to category
          baseActions?.add(baseAction);
        }
      }
      // store result
      if (baseActions != null && baseActions.isNotEmpty) {
        sortedActions[baseAction.getCategoryName()] = baseActions;
      }
    }
    return BuiltMap(sortedActions.map((key, value) => MapEntry(key, value.build())));
  }

  void _listener() {
    state = getState();
  }
}

// Technically not all moves
// only return moves that would be available if all gear was connected
@Riverpod(keepAlive: true)
class GetAllActions extends _$GetAllActions {
  @override
  BuiltMap<String, BuiltSet<BaseAction>> build() {
    ref.watch(initLocaleProvider); // to rebuild category names
    KnownDevices.instance
      ..removeListener(onDeviceConnect)
      ..addListener(onDeviceConnect);
    Map<String, Set<BaseAction>> sortedActions = {};
    final BuiltList<MoveList> moveLists = ref.watch(moveListsProvider);
    final BuiltList<AudioAction> audioActions = ref.watch(userAudioActionsProvider);
    for (BaseStatefulDevice baseStatefulDevice in KnownDevices.instance.state.values) {
      baseStatefulDevice.hasRGB
        ..removeListener(onDeviceConnect)
        ..addListener(onDeviceConnect);
      baseStatefulDevice.hasGlowtip
        ..removeListener(onDeviceConnect)
        ..addListener(onDeviceConnect);
    }
    // Filter out moves from unpaired gear
    Set<DeviceType> pairedDeviceTypes = KnownDevices.instance.state.values.map((e) => e.baseDeviceDefinition.deviceType).toSet();
    bool hasRGB = KnownDevices.instance.state.values.map((e) => e.baseStoredDevice.hasRGB).any((element) => element == RGBStatus.rgb);
    bool hasGlowTip = KnownDevices.instance.state.values.map((e) => e.baseStoredDevice.hasGlowtip).any((element) => element == GlowtipStatus.glowtip);

    for (BaseAction baseAction
        in List.from(
            ActionRegistry.allCommands
                .where((element) => pairedDeviceTypes.intersection(element.deviceCategory.toSet()).isNotEmpty)
                .whereNot((element) => element.actionCategory == ActionCategory.rgb && !hasRGB)
                .whereNot((element) => element.actionCategory == ActionCategory.glowtip && !hasGlowTip),
          )
          ..addAll(moveLists)
          ..addAll(audioActions)) {
      Set<BaseAction>? baseActions = {};
      // get category if it exists
      if (sortedActions.containsKey(baseAction.getCategoryName())) {
        baseActions = sortedActions[baseAction.getCategoryName()];
      }
      // add action to category
      baseActions?.add(baseAction);
      // store result
      if (baseActions != null && baseActions.isNotEmpty) {
        sortedActions[baseAction.getCategoryName()] = baseActions;
      }
    }
    return BuiltMap(sortedActions.map((key, value) => MapEntry(key, value.build())));
  }

  void onDeviceConnect() {
    ref.invalidateSelf();
  }
}

@Riverpod(keepAlive: true)
BaseAction? getActionFromUUID(Ref ref, String? uuid) {
  if (uuid == null) {
    return null;
  }
  final BuiltMap<String, BuiltSet<BaseAction>> watch = ref.watch(getAllActionsProvider);
  return watch.values.flattened.where((element) => element.uuid == uuid).firstOrNull;
}
