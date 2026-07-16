import 'package:flutter/material.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../../Backend/logging_wrappers.dart';
import '../../../constants.dart';
import '../../translation_string_definitions.dart';

class RgbBrightness extends StatefulWidget {
  const RgbBrightness({super.key});

  @override
  State<RgbBrightness> createState() => _RgbBrightnessState();
}

class _RgbBrightnessState extends State<RgbBrightness> {
  double brightness = 100;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(convertToUwU(gearRgbBrightness())),
      subtitle: Slider(
        value: brightness,
        min: 1,
        max: 100,
        label: "${brightness.toInt()}%",
        divisions: 99,
        onChanged: (value) {
          setState(() {
            brightness = value;
          });
        },
        onChangeEnd: (value) {
          HiveProxy.put(settings, rgbBrightness, value.clamp(1, 100));
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    brightness = HiveProxy.getOrDefault(
      settings,
      rgbBrightness,
      defaultValue: rgbBrightnessDefault,
    );
  }
}
