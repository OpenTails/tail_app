import 'package:flutter/material.dart';

import '../../Backend/Definitions/Device/device_definition.dart';
import '../intn_defs.dart';

class DeviceTypeWidget extends StatelessWidget {
  const DeviceTypeWidget({super.key, required this.selected, required this.onSelectionChanged});

  final List<DeviceType> selected;
  final Function(Set<DeviceType> value) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(deviceType()),
      subtitle: SegmentedButton<DeviceType>(
        multiSelectionEnabled: true,
        selected: selected.toSet(),
        onSelectionChanged: onSelectionChanged,
        segments: DeviceType.values.map<ButtonSegment<DeviceType>>(
          (DeviceType value) {
            return ButtonSegment<DeviceType>(
              value: value,
              label: Text(value.name),
            );
          },
        ).toList(),
      ),
    );
  }
}
