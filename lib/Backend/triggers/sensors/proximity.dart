import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../sensor_definition.dart';
import '../sensor_definition_action_definition.dart';

class CoverTriggerDefinition extends TriggerDefinition {
  StreamSubscription<int>? proximityStream;
  final Logger _logger = Logger("ProximitySensor");

  CoverTriggerDefinition() {
    super.name = triggerCoverTitle;
    super.description = triggerCoverDescription;
    super.icon = const Icon(Icons.sensors);
    super.requiredPermission = null;
    super.uuid = "a390cd3c-c314-44c1-b89d-57be75bfc3a2";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "Near",
        translated: triggerCoverNear,
        uuid: "bf3d0ce0-15c0-46db-95ce-e2cd6a5ecd0f",
      ),
      TriggerActionDef(
        name: "Far",
        translated: triggerCoverFar,
        uuid: "d121e4a8-a12d-4f0a-8348-89c62eb72a7a",
      ),
    ];
  }

  @override
  Future<bool> isSupported() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }
    return ProximitySensor.isProximitySensorAvailable();
  }

  @override
  Future<void> onDisable() async {
    proximityStream?.cancel();
    proximityStream = null;
  }

  @override
  Future<void> onEnable() async {
    if (proximityStream != null) {
      return;
    }

    proximityStream = ProximitySensor.events.listen((int event) {
      _logger.fine("CoverEvent:: $event");
      if (event >= 1) {
        sendCommands("Near");
      } else if (event == 0) {
        sendCommands("Far");
      }
    });
  }
}
