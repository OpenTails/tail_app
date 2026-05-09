import 'package:flutter/material.dart';
import 'package:tail_app/Backend/triggers/sensor_definition.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../constants.dart';
import '../translation_string_definitions.dart';

class NoiseThresholdWidget extends StatefulWidget {
  const NoiseThresholdWidget({super.key, required this.triggerDefinition});

  final TriggerDefinition triggerDefinition;

  @override
  State<NoiseThresholdWidget> createState() => _NoiseThresholdWidgetState();
}

class _NoiseThresholdWidgetState extends State<NoiseThresholdWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double threshold =
        widget.triggerDefinition.optionalSettings.containsKey(noiseThreshold)
        ? widget.triggerDefinition.optionalSettings[noiseThreshold]
        : noiseThresholdDefault;
    return ListTile(
      title: Text(convertToUwU(triggerPhoneMicThresholdSliderLabel())),
      subtitle: Slider(
        value: threshold,
        min: 0,
        max: 240,
        divisions: 240 - 15,
        label: "$threshold Db",
        onChanged: (value) {
          setState(() {
            threshold = value.clamp(15, 240);
          });
          widget.triggerDefinition.optionalSettings = {
            noiseThreshold: threshold,
          };
        },
      ),
    );
  }
}
