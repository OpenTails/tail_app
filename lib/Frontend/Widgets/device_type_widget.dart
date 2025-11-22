import 'package:choice/choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../Backend/Bluetooth/known_devices.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../translation_string_definitions.dart';

class DeviceTypeWidget extends ConsumerWidget {
  const DeviceTypeWidget({required this.selected, required this.onSelectionChanged, this.alwaysVisible = false, super.key});

  final bool alwaysVisible;

  final List<DeviceType> selected;
  final Function(List<DeviceType> value) onSelectionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: KnownDevices.instance,
      builder: (BuildContext context, Widget? child) {
        if (KnownDevices.instance.state.length <= 1 && !alwaysVisible) {
          //onSelectionChanged(DeviceType.values);
          return Container();
        }
        return ListTile(
          title: Text(convertToUwU(deviceType())),
          subtitle: InlineChoice<DeviceType>.multiple(
            clearable: false,
            value: selected,
            onChanged: onSelectionChanged,
            itemCount: DeviceType.values.where((element) => !element.isHidden()).length,
            itemBuilder: (state, i) {
              DeviceType deviceType = DeviceType.values.where((element) => !element.isHidden()).toList()[i];
              return ChoiceChip(
                selectedColor: deviceType.color(),
                selected: state.selected(deviceType),
                onSelected: state.onSelected(deviceType),
                label: Text(convertToUwU(deviceType.translatedName)),
                elevation: 1,
              );
            },
            listBuilder: ChoiceList.createWrapped(spacing: 10, alignment: WrapAlignment.center),
          ),
        );
      },
    );
  }
}
