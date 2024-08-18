import 'package:flutter/material.dart';
import 'package:tail_app/Backend/logging_wrappers.dart';

import '../../constants.dart';
import '../translation_string_definitions.dart';

class CasualModeDelayWidget extends StatefulWidget {
  const CasualModeDelayWidget({super.key});

  @override
  State<CasualModeDelayWidget> createState() => _CasualModeDelayWidgetState();
}

class _CasualModeDelayWidgetState extends State<CasualModeDelayWidget> {
  int min = 0;
  int max = 0;

  @override
  void initState() {
    super.initState();
    min = HiveProxy.getOrDefault(settings, casualModeDelayMin, defaultValue: casualModeDelayMinDefault);
    max = HiveProxy.getOrDefault(settings, casualModeDelayMax, defaultValue: casualModeDelayMaxDefault);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(casualModeDelayTitle()),
      subtitle: RangeSlider(
        values: RangeValues(min.toDouble(), max.toDouble()),
        min: 15,
        max: 240,
        divisions: 240 - 15,
        labels: RangeLabels(min.toString(), max.toString()),
        onChanged: (value) {
          setState(() {
            min = value.start.toInt();
            max = value.end.toInt();
          });
          HiveProxy.put(settings, casualModeDelayMin, min);
          HiveProxy.put(settings, casualModeDelayMax, max);
        },
      ),
    );
  }
}
