import 'package:flutter/material.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';

import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../translation_string_definitions.dart';

EarSpeed earSpeed = EarSpeed.fast;

class EarSpeedWidget extends StatefulWidget {
  const EarSpeedWidget({super.key});

  @override
  State<EarSpeedWidget> createState() => _EarSpeedWidgetState();
}

class _EarSpeedWidgetState extends State<EarSpeedWidget> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(earSpeedTitle()),
      subtitle: SegmentedButton<EarSpeed>(
        selected: <EarSpeed>{earSpeed},
        onSelectionChanged: (Set<EarSpeed> value) {
          setState(
            () {
              earSpeed = value.first;
              HiveProxy.put(settings, earMoveSpeed, earSpeed);
            },
          );
        },
        segments: EarSpeed.values.map<ButtonSegment<EarSpeed>>(
          (EarSpeed value) {
            return ButtonSegment<EarSpeed>(
              value: value,
              label: Text(value.name),
              icon: value.icon,
              tooltip: value.name,
            );
          },
        ).toList(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    earSpeed = HiveProxy.getOrDefault(settings, earMoveSpeed, defaultValue: earMoveSpeedDefault);
  }
}
