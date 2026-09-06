import 'package:flutter/material.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../Backend/move_lists_backend.dart';
import '../translation_string_definitions.dart';

class EasingTypesWidget extends StatelessWidget {
  const EasingTypesWidget({
    super.key,
    required this.onSelectionChanged,
    required this.value,
  });

  final Function(Set<EasingType> value) onSelectionChanged;
  final EasingType value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(convertToUwU(sequencesEditEasing())),
      subtitle: SegmentedButton<EasingType>(
        selected: <EasingType>{value},
        onSelectionChanged: onSelectionChanged,
        segments: EasingType.values.map<ButtonSegment<EasingType>>((
          EasingType value,
        ) {
          return ButtonSegment<EasingType>(
            value: value,
            tooltip: value.name,
            icon: value.widget(context),
          );
        }).toList(),
      ),
    );
  }
}
