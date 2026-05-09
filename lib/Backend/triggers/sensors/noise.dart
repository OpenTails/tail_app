import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tail_app/Backend/triggers/permissions.dart';
import 'package:tail_app/Frontend/Widgets/noise_threshold_widget.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../sensor_definition.dart';
import '../sensor_definition_action_definition.dart';

enum NoiseState { loud, quiet, unknown }

class NoiseTriggerDefinition extends TriggerDefinition {
  StreamSubscription<NoiseReading>? noiseMeterStream;
  NoiseState state = NoiseState.unknown;

  NoiseTriggerDefinition() {
    super.name = triggerPhoneMicTitle;
    super.description = triggerPhoneMicDescription;
    super.icon = const Icon(Icons.mic);
    super.requiredPermission = TriggerPermissionHandle(
      android: {Permission.microphone},
      ios: {Permission.microphone},
    );
    super.uuid = "9b60a160-a4f9-4dbb-b675-9958546edd34";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "Loud",
        translated: triggerPhoneMicLoud,
        uuid: "fbfbbd7c-5757-4317-96b1-a578a610d3bf",
      ),
      TriggerActionDef(
        name: "Quiet",
        translated: triggerPhoneMicQuiet,
        uuid: "8030eabb-e729-4203-8397-fdfd386270ed",
      ),
    ];
    super.settingsWidget = NoiseThresholdWidget(triggerDefinition: this);
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
    noiseMeterStream?.cancel();
    noiseMeterStream = null;
    state = NoiseState.unknown;
  }

  double threshold = 9;

  @override
  Future<void> onEnable() async {
    if (noiseMeterStream != null) {
      return;
    }
    noiseMeterStream = NoiseMeter().noise.listen(
      (NoiseReading noiseReading) {
        debug = noiseReading.toString();
        if (state != NoiseState.loud && noiseReading.meanDecibel > threshold) {
          state = NoiseState.loud;
          sendCommands("Loud");
        } else if (state != NoiseState.quiet &&
            noiseReading.meanDecibel < threshold) {
          state = NoiseState.quiet;
          sendCommands("Quiet");
        }
      },
      onError: (Object error) {
        enabled = false;
      },
      cancelOnError: true,
    );
  }
}
