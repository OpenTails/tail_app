import 'package:flutter/material.dart';

import '../intn_defs.dart';

class SpeedWidget extends StatelessWidget {
  const SpeedWidget({super.key, required this.value, required this.onChanged});

  final Function(double value) onChanged;
  final double value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(sequencesEditSpeed()),
      subtitle: Directionality(
        textDirection: TextDirection.rtl,
        child: Slider(
          label: "${(value.toInt() * 20).toInt()}ms",
          value: value,
          min: 15,
          max: 127,
          divisions: 110,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
