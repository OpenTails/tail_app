import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/Backend/triggers/sensors/gamepad.dart';
import 'package:tail_app/Backend/triggers/sensors/noise.dart';

import 'sensor_definition.dart';
import 'sensors/accelerometer.dart';
import 'sensors/ble_proximity.dart';
import 'sensors/casual.dart';
import 'sensors/claws/claw_clap.dart';
import 'sensors/claws/claw_tilt.dart';
import 'sensors/ears/ear_mic.dart';
import 'sensors/ears/ear_tilt.dart';
import 'sensors/proximity.dart';
import 'sensors/shake.dart';
import 'sensors/volume.dart';
import 'sensors/walking.dart';
import 'stored_triggers.dart';
import 'trigger.dart';

// Defines what triggers show in the UI
final Logger _logger = Logger("SensorList");

class TriggerDefinitionList {
  static final Iterable<TriggerDefinition> allTriggerDefinitions =
      List.unmodifiable([
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
        AccelerometerTriggerDefinition(),
        NoiseTriggerDefinition(),
        //MediaSessionTriggerDefinition(),
        GamepadTriggerDefinition(),
      ]);

  //Filter by unused sensors
  static Iterable<TriggerDefinition> get() => allTriggerDefinitions
      .toSet()
      .difference(
        TriggerList.instance.state
            .map((Trigger e) => e.triggerDefinition!)
            .toSet(),
      )
      .sorted();

  static Future<List<TriggerDefinition>> getSupported() async {
    Iterable<TriggerDefinition> unusedTriggerDefinitions = get();
    List<TriggerDefinition> supportedTriggerDefinitions = [];
    for (TriggerDefinition triggerDefinition in unusedTriggerDefinitions) {
      if (await triggerDefinition.isSupported().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          _logger.severe(
            "Timed our checking if ${Intl.withLocale('en', () => triggerDefinition.name())} is supported",
          );
          return false;
        },
      )) {
        supportedTriggerDefinitions.add(triggerDefinition);
      }
    }
    return supportedTriggerDefinitions;
  }
}
