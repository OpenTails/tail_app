import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../sensor_definition.dart';
import '../sensor_definition_action_definition.dart';

class GamepadTriggerDefinition extends TriggerDefinition {
  StreamSubscription<NormalizedGamepadEvent>? streamSubscription;

  GamepadTriggerDefinition() {
    super.name = triggerGamepadTitle;
    super.description = triggerGamepadDescription;
    super.icon = const Icon(Icons.gamepad);
    super.requiredPermission = null;
    super.uuid = "3d53ce88-d86c-4635-8458-9e0779ac3e4f";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "A",
        translated: () => "A",
        uuid: "726bbb18-c3a0-4c14-a314-1be1ba8b8e05",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "B",
        translated: () => "B",
        uuid: "db10e5cb-4a3e-4e7a-9f2e-07dc4e2dbdb0",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "X",
        translated: () => "X",
        uuid: "330c2b90-3265-4df1-b594-4a7907705f95",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "Y",
        translated: () => "Y",
        uuid: "9906338b-f1b8-472c-acac-868644115520",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "LB",
        translated: () => "LB",
        uuid: "60995575-8e42-43d1-9670-68dd931e4d69",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "RB",
        translated: () => "RB",
        uuid: "e07e11d5-b092-469b-b7b9-fe311dc3c01f",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "LT",
        translated: () => "LT",
        uuid: "b180ed68-2fb4-428b-bd4b-6fe055d30b17",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "RT",
        translated: () => "RT",
        uuid: "260ba287-9a28-4887-a187-04a61709a2bb",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "UP",
        translated: () => "UP",
        icon: Icon(Icons.keyboard_arrow_up),
        uuid: "460904ef-5641-44f2-987c-b89dd4849219",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "Down",
        translated: () => "Down",
        icon: Icon(Icons.keyboard_arrow_down),
        uuid: "4f1990a8-0660-4723-8384-886ea5b18409",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "Left",
        translated: () => "Left",
        icon: Icon(Icons.keyboard_arrow_left),
        uuid: "93f4978b-e021-4d04-adca-ebc9510d684f",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "Right",
        translated: () => "Right",
        icon: Icon(Icons.keyboard_arrow_right),
        uuid: "82cd3c2c-f46a-44cd-9235-2af75cedbff5",
        defaultActions: true,
      ),
    ];
  }

  @override
  Future<bool> isSupported() async {
    return true;
  }

  @override
  Future<void> onDisable() async {
    streamSubscription?.cancel();
    streamSubscription = null;
  }

  @override
  Future<void> onEnable() async {
    if (streamSubscription != null) {
      return;
    }
    streamSubscription = Gamepads.normalizedEvents.listen((event) {
      debug = event.toString();
      if (event.button == GamepadButton.a && event.value != 0) {
        sendCommands("A");
      }
      if (event.button == GamepadButton.b && event.value != 0) {
        sendCommands("B");
      }
      if (event.button == GamepadButton.x && event.value != 0) {
        sendCommands("X");
      }
      if (event.button == GamepadButton.y && event.value != 0) {
        sendCommands("Y");
      }
      if (event.button == GamepadButton.leftBumper && event.value != 0) {
        sendCommands("LB");
      }
      if (event.button == GamepadButton.rightBumper && event.value != 0) {
        sendCommands("RB");
      }
      if (event.button == GamepadButton.leftTrigger && event.value != 0) {
        sendCommands("LT");
      }
      if (event.button == GamepadButton.rightTrigger && event.value != 0) {
        sendCommands("RT");
      }
      if (event.button == GamepadButton.dpadUp && event.value != 0) {
        sendCommands("UP");
      }
      if (event.button == GamepadButton.dpadDown && event.value != 0) {
        sendCommands("Down");
      }
      if (event.button == GamepadButton.dpadLeft && event.value != 0) {
        sendCommands("Left");
      }
      if (event.button == GamepadButton.dpadRight && event.value != 0) {
        sendCommands("Right");
      }
      if ([
        GamepadAxis.leftStickX,
        GamepadAxis.rightStickX,
      ].contains(event.axis)) {
        if (event.value > 0.5) {
          sendCommands("Right");
        } else if (event.value < -0.5) {
          sendCommands("Left");
        }
      }
      if ([
        GamepadAxis.leftStickY,
        GamepadAxis.rightStickY,
      ].contains(event.axis)) {
        if (event.value > 0.5) {
          sendCommands("Up");
        } else if (event.value < -0.5) {
          sendCommands("Down");
        }
      }
    });
  }
}
