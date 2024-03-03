import 'package:flutter/material.dart';

import '../../Backend/Definitions/Device/BaseDeviceDefinition.dart';
import '../intnDefs.dart';

class DeviceTypeWidget extends StatelessWidget {
  DeviceTypeWidget({Key? key, required this.selected, required this.onSelectionChanged}) : super(key: key);
  List<DeviceType> selected;
  Function(Set<DeviceType> value) onSelectionChanged;

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
