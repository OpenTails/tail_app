import 'package:choice/choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../translation_string_definitions.dart';

class DeviceTypeWidget extends ConsumerWidget {
  const DeviceTypeWidget({required this.selected, required this.onSelectionChanged, this.alwaysVisible = false, super.key});

  final bool alwaysVisible;

  final List<DeviceType> selected;
  final Function(List<DeviceType> value) onSelectionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(knownDevicesProvider).length <= 1 && !alwaysVisible) {
      //onSelectionChanged(DeviceType.values);
      return Container();
    }
    return ListTile(
      title: Text(convertToUwU(deviceType())),
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
            label: Text(convertToUwU(deviceType.name)),
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
