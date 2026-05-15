import 'package:flutter/material.dart';
import 'package:shake/shake.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../../../Frontend/utils.dart';
import '../sensor_definition.dart';
import '../sensor_definition_action_definition.dart';

class ShakeTriggerDefinition extends TriggerDefinition {
  ShakeDetector? detector;

  ShakeTriggerDefinition() {
    super.name = triggerShakeTitle;
    super.description = triggerShakeDescription;
    super.icon = const Icon(Icons.vibration);
    super.requiredPermission = null;
    super.uuid = "059d445a-35fe-45a3-8d3d-de8bce213a05";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "Shake",
        translated: triggerShakeTitle,
        uuid: "b84b4c7a-2330-4ede-82f4-dca7b6e74b0a",
        defaultActions: true,
      ),
    ];
  }

  @override
  Future<bool> isSupported() async {
    if (!isMobile) {
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
        debug = DateTime.timestamp().toString();
        sendCommands("Shake");
      },
    );
    detector?.startListening();
  }
}
