import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../permissions.dart';
import '../sensor_definition.dart';
import '../sensor_definition_action_definition.dart';

class WalkingTriggerDefinition extends TriggerDefinition {
  StreamSubscription<PedestrianStatus>? pedestrianStatusStream;
  StreamSubscription<StepCount>? stepCountStream;
  final Logger _logger = Logger("WalkingSensor");

  WalkingTriggerDefinition() {
    super.name = triggerWalkingTitle;
    super.description = triggerWalkingDescription;
    super.icon = const Icon(Icons.directions_walk);
    super.requiredPermission = TriggerPermissionHandle(
      android: {Permission.activityRecognition},
      ios: {Permission.sensors},
    );
    super.uuid = "ee9379e2-ec4f-40bb-8674-fd223a6edfda";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "Walking",
        translated: triggerWalkingTitle,
        uuid: "77d22961-5a69-465a-bd27-5cf5508d10a6",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "Stopped",
        translated: triggerWalkingStopped,
        uuid: "7424097d-ba24-4d85-b963-bf58e85e289d",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "Step",
        translated: triggerWalkingStep,
        uuid: "c82b04ba-7d2e-475a-90ba-3d354e5b8ef0",
        defaultActions: true,
      ),
    ];
  }

  @override
  Future<bool> isSupported() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }
    bool isStepCountSupported = await Pedometer.isStepCountSupported == true;
    bool isStepDetectionSupported =
        await Pedometer.isStepDetectionSupported == true;
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
    pedestrianStatusStream = Pedometer.pedestrianStatusStream.listen((
      PedestrianStatus event,
    ) {
      _logger.info("PedestrianStatus:: ${event.status}");
      if (event.status == "walking") {
        sendCommands("Walking");
      } else if (event.status == "stopped") {
        sendCommands("Stopped");
      }
    });
    stepCountStream = Pedometer.stepCountStream.listen((StepCount event) {
      _logger.fine("StepCount:: ${event.steps}");
      sendCommands("Step");
    });
  }
}
