import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../../../constants.dart';
import '../../logging_wrappers.dart';
import '../sensor_definition.dart';
import '../sensor_definition_action_definition.dart';

class RandomTriggerDefinition extends TriggerDefinition {
  Timer? randomTimer;

  RandomTriggerDefinition() {
    super.name = triggerRandomButtonTitle;
    super.description = triggerRandomButtonDescription;
    super.icon = const Icon(Icons.timelapse);
    super.requiredPermission = null;
    super.uuid = "12e01dea-219a-40e7-b51d-d89d6d4460ac";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "Action",
        translated: triggerRandomAction,
        uuid: "60011d58-1c29-49ae-ad31-6774b81df49b",
        defaultActions: true,
      ),
    ];
  }

  @override
  Future<void> onDisable() async {
    randomTimer?.cancel();
    randomTimer = null;
  }

  @override
  Future<void> onEnable() async {
    int min = HiveProxy.getOrDefault(
      settings,
      casualModeDelayMin,
      defaultValue: casualModeDelayMinDefault,
    );
    int max = HiveProxy.getOrDefault(
      settings,
      casualModeDelayMax,
      defaultValue: casualModeDelayMaxDefault,
    );
    debug = "Min delay $min seconds before next timer";
    await Future.delayed(Duration(seconds: min));
    if (enabled) {
      int timerDurationSeconds = Random().nextInt((max - min).clamp(1, max));
      randomTimer = Timer(Duration(seconds: timerDurationSeconds), () {
        sendCommands("Action");
        onEnable();
      });
      debug = "Timer Duration $timerDurationSeconds seconds";
    }
  }
}
