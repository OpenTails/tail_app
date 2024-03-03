import 'package:flutter/material.dart';

import '../intnDefs.dart';

class SpeedWidget extends StatelessWidget {
  SpeedWidget({super.key, required this.value, required this.onChanged});

  Function(double value) onChanged;
  double value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: Text(sequencesEditSpeed()),
        subtitle: Slider(
          label: "${(value.toInt() * 20).toInt()}ms",
          value: value,
          min: 15,
          max: 127,
          divisions: 110,
          onChanged: onChanged,
        ));
  }
}
