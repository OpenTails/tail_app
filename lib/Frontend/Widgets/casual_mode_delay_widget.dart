import 'package:flutter/material.dart';
import 'package:tail_app/Backend/triggers/sensor_definition.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../constants.dart';
import '../translation_string_definitions.dart';

class CasualModeDelayWidget extends StatefulWidget {
  const CasualModeDelayWidget({super.key, required this.triggerDefinition});

  final TriggerDefinition triggerDefinition;

  @override
  State<CasualModeDelayWidget> createState() => _CasualModeDelayWidgetState();
}

class _CasualModeDelayWidgetState extends State<CasualModeDelayWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    int min =
        widget.triggerDefinition.optionalSettings.containsKey(
          casualModeDelayMin,
        )
        ? widget.triggerDefinition.optionalSettings[casualModeDelayMin]
        : casualModeDelayMinDefault;
    int max =
        widget.triggerDefinition.optionalSettings.containsKey(
          casualModeDelayMax,
        )
        ? widget.triggerDefinition.optionalSettings[casualModeDelayMax]
        : casualModeDelayMaxDefault;
    return ListTile(
      title: Text(convertToUwU(casualModeDelayTitle())),
      subtitle: RangeSlider(
        values: RangeValues(min.toDouble(), max.toDouble()),
        min: 15,
        max: 240,
        divisions: 240 - 15,
        labels: RangeLabels(min.toString(), max.toString()),
        onChanged: (value) {
          setState(() {
            min = value.start.toInt().clamp(15, 240);
            max = value.end.toInt().clamp(15, 240);
          });
          widget.triggerDefinition.optionalSettings = {
            casualModeDelayMin: min,
            casualModeDelayMax: max,
          };
        },
      ),
    );
  }
}
