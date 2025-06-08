import 'package:flutter/material.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../translation_string_definitions.dart';

class SpeedWidget extends StatelessWidget {
  const SpeedWidget({required this.value, required this.onChanged, super.key});

  final Function(double value) onChanged;
  final double value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(convertToUwU(sequencesEditSpeed())),
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
