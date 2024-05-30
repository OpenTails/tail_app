import 'package:choice/choice.dart';
import 'package:flutter/material.dart';

import '../../Backend/Definitions/Device/device_definition.dart';
import '../translation_string_definitions.dart';

class DeviceTypeWidget extends StatelessWidget {
  const DeviceTypeWidget({super.key, required this.selected, required this.onSelectionChanged});

  final List<DeviceType> selected;
  final Function(Set<DeviceType> value) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(deviceType()),
      subtitle: InlineChoice<DeviceType>.multiple(
        clearable: true,
        value: selected,
        itemCount: DeviceType.values.length,
        itemBuilder: (state, i) {
          DeviceType deviceType = DeviceType.values[i];
          return ChoiceChip(
            selected: state.selected(deviceType),
            onSelected: state.onSelected(deviceType),
            label: Text(deviceType.name),
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
