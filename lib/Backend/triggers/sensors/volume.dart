import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_android_volume_keydown/flutter_android_volume_keydown.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../sensor_definition.dart';
import '../sensor_definition_action_definition.dart';

class VolumeButtonTriggerDefinition extends TriggerDefinition {
  StreamSubscription<HardwareButton>? subscription;

  VolumeButtonTriggerDefinition() {
    super.name = triggerVolumeButtonTitle;
    super.description = triggerVolumeButtonDescription;
    super.icon = const Icon(Icons.volume_up);
    super.requiredPermission = null;
    super.uuid = "26c1eaef-5976-43cb-bc68-f67cfb29de51";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "Volume Up",
        translated: triggerVolumeButtonVolumeUp,
        uuid: "834a9bef-9ae2-4623-81fa-bbead69eb28e",
      ),
      TriggerActionDef(
        name: "Volume Down",
        translated: triggerVolumeButtonVolumeDown,
        uuid: "2972aa14-33de-4d4f-ac67-4f572306b5c4",
      ),
    ];
  }

  @override
  Future<bool> isSupported() async {
    return Platform.isAndroid;
  }

  @override
  Future<void> onDisable() async {
    subscription?.cancel();
    subscription = null;
  }

  @override
  Future<void> onEnable() async {
    if (subscription != null) {
      return;
    }
    subscription = FlutterAndroidVolumeKeydown.stream.listen((event) {
      if (event == HardwareButton.volume_up) {
        sendCommands("Volume Up");
      } else if (event == HardwareButton.volume_down) {
        sendCommands("Volume Down");
      }
    });
  }
}
