import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'sensor_definition.dart';
import 'sensors/walking.dart';
import 'stored_triggers.dart';
import 'trigger.dart';

import 'sensors/ble_proximity.dart';
import 'sensors/casual.dart';
import 'sensors/claws/claw_clap.dart';
import 'sensors/claws/claw_tilt.dart';
import 'sensors/ears/ear_mic.dart';
import 'sensors/ears/ear_tilt.dart';
import 'sensors/proximity.dart';
import 'sensors/shake.dart';
import 'sensors/volume.dart';

// Defines what triggers show in the UI
class TriggerDefinitionList {
  static final BuiltList<TriggerDefinition> allTriggerDefinitions = [
    WalkingTriggerDefinition(),
    CoverTriggerDefinition(),
    TailProximityTriggerDefinition(),
    ShakeTriggerDefinition(),
    EarMicTriggerDefinition(),
    EarTiltTriggerDefinition(),
    RandomTriggerDefinition(),
    VolumeButtonTriggerDefinition(),
    ClawClapTriggerDefinition(),
    ClawTiltTriggerDefinition(),
  ].build();

  //Filter by unused sensors
  static List<TriggerDefinition> get() => allTriggerDefinitions
      .toSet()
      .difference(
        TriggerList.instance.state
            .map((Trigger e) => e.triggerDefinition!)
            .toSet(),
      )
      .sorted()
      .toList();

  static Future<List<TriggerDefinition>> getSupported() async {
    List<TriggerDefinition> unusedTriggerDefinitions = get();
    List<TriggerDefinition> supportedTriggerDefinitions = [];
    for (TriggerDefinition triggerDefinition in unusedTriggerDefinitions) {
      if (await triggerDefinition.isSupported()) {
        supportedTriggerDefinitions.add(triggerDefinition);
      }
    }
    return supportedTriggerDefinitions;
  }
}
