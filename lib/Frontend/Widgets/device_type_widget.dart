import 'package:choice/choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../Backend/Definitions/Device/device_definition.dart';
import '../translation_string_definitions.dart';

class DeviceTypeWidget extends ConsumerWidget {
  const DeviceTypeWidget({super.key, required this.selected, required this.onSelectionChanged});

  final List<DeviceType> selected;
  final Function(List<DeviceType> value) onSelectionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(deviceType()),
      subtitle: InlineChoice<DeviceType>.multiple(
        clearable: false,
        value: selected,
        onChanged: onSelectionChanged,
        itemCount: DeviceType.values.length,
        itemBuilder: (state, i) {
          DeviceType deviceType = DeviceType.values[i];
          return ChoiceChip(
            selectedColor: deviceType.color(ref: ref),
            selected: state.selected(deviceType),
            onSelected: state.onSelected(deviceType),
            label: Text(deviceType.name),
            elevation: 1,
          );
        },
        listBuilder: ChoiceList.createWrapped(
          spacing: 10,
          alignment: WrapAlignment.center,
        ),
      ),
    );
  }
}
