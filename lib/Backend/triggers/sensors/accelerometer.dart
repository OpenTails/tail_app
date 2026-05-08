import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../sensor_definition.dart';
import '../sensor_definition_action_definition.dart';

enum AccelerometerOrientationState {
  faceUp,
  faceDown,
  up,
  down,
  left,
  right,
  unknown,
}

class AccelerometerTriggerDefinition extends TriggerDefinition {
  final Logger _logger = Logger("AccelerometerTrigger");
  StreamSubscription<AccelerometerEvent>? accelSensorStream;
  AccelerometerOrientationState state = AccelerometerOrientationState.unknown;

  AccelerometerTriggerDefinition() {
    super.name = triggerAccelerometerTitle;
    super.description = triggerAccelerometerDescription;
    super.icon = const Icon(Icons.screen_rotation);
    super.requiredPermission = null;
    super.uuid = "155fab58-e3ee-4c6e-b64e-6a0b49811825";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "Face Up",
        translated: triggerAccelerometerFaceUp,
        uuid: "7e206688-57df-4dad-a006-7fd3e92297d4",
      ),
      TriggerActionDef(
        name: "Face Down",
        translated: triggerAccelerometerFaceDown,
        uuid: "14d52189-2d8e-403e-bd07-14f921e04c5e",
      ),
      TriggerActionDef(
        name: "Up",
        translated: triggerAccelerometerUp,
        uuid: "8faa4617-0d4b-4024-9436-20bfd54399da",
      ),
      TriggerActionDef(
        name: "Down",
        translated: triggerAccelerometerDown,
        uuid: "b84b4c7a-2330-4ede-82f4-dca7b6e74b0a",
      ),
      TriggerActionDef(
        name: "Left",
        translated: triggerAccelerometerLeft,
        uuid: "0c147975-c542-42e5-960a-31448b74b837",
      ),
      TriggerActionDef(
        name: "Right",
        translated: triggerAccelerometerRight,
        uuid: "4681be0c-8ef5-495a-adf1-81c8f451e992",
      ),
    ];
  }

  @override
  Future<bool> isSupported() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }
    return true;
  }

  @override
  Future<void> onDisable() async {
    accelSensorStream?.cancel();
    accelSensorStream = null;
    state = AccelerometerOrientationState.unknown;
  }

  double threshold = 9;

  @override
  Future<void> onEnable() async {
    if (accelSensorStream != null) {
      return;
    }
    accelSensorStream = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        debug = event.toString();

        if (state != AccelerometerOrientationState.right &&
            event.x > threshold) {
          sendCommands("Right");
        } else if (state != AccelerometerOrientationState.left &&
            event.x < -threshold) {
          state = AccelerometerOrientationState.left;
          sendCommands("Left");
        }
        if (state != AccelerometerOrientationState.up && event.y > threshold) {
          state = AccelerometerOrientationState.up;
          sendCommands("Up");
        } else if (state != AccelerometerOrientationState.down &&
            event.y < -threshold) {
          state = AccelerometerOrientationState.down;
          sendCommands("Down");
        }
        if (state != AccelerometerOrientationState.faceUp &&
            event.z > threshold) {
          state = AccelerometerOrientationState.faceUp;
          sendCommands("Face Up");
        } else if (state != AccelerometerOrientationState.faceDown &&
            event.z < -threshold) {
          state = AccelerometerOrientationState.faceDown;
          sendCommands("Face Down");
        }
      },
      onError: (error) {
        enabled = false;
      },
      cancelOnError: true,
    );
  }
}
