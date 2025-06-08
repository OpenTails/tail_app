import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../translation_string_definitions.dart';

class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({required this.defaultColor, super.key});

  final int defaultColor;

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color color;

  @override
  void initState() {
    color = Color(widget.defaultColor);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        convertToUwU(colorPickerTitle()),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(color.toARGB32());
          },
          child: Text(
            convertToUwU(ok()),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            convertToUwU(cancel()),
          ),
        ),
      ],
      content: Wrap(
        children: [
          ColorPicker(
            color: color,
            padding: EdgeInsets.zero,
            onColorChanged: (Color color) => setState(() => this.color = color),
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.both: false,
              ColorPickerType.primary: true,
              ColorPickerType.accent: true,
              ColorPickerType.wheel: true,
            },
          ),
        ],
      ),
    );
  }
}
