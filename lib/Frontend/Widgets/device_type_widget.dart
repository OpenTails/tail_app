import 'package:choice/choice.dart';
import 'package:flutter/material.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_app/Frontend/theme_helpers.dart';

import '../../Backend/Bluetooth/known_devices.dart';
import '../../Backend/Device/device_type_enum.dart';
import '../translation_string_definitions.dart';

class DeviceTypeWidget extends StatelessWidget {
  const DeviceTypeWidget({
    required this.selected,
    required this.onSelectionChanged,
    this.alwaysVisible = false,
    super.key,
  });

  final bool alwaysVisible;

  final List<DeviceType> selected;
  final Function(List<DeviceType> value) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
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
            itemCount: DeviceType.values.length,
            itemBuilder: (state, i) {
              DeviceType deviceType = DeviceType.values.toList()[i];
              return ChoiceChip(
                selectedColor: deviceType.color(),
                tooltip: deviceType.translatedName,
                selected: state.selected(deviceType),
                onSelected: state.onSelected(deviceType),
                label: deviceType.iconAssetPath().isEmpty
                    ? Text(convertToUwU(deviceType.translatedName))
                    : deviceType.icon(30, getTextColor(deviceType.color())),
                elevation: 1,
              );
            },
            listBuilder: ChoiceList.createWrapped(
              spacing: 10,
              alignment: WrapAlignment.center,
            ),
          ),
        );
      },
    );
  }
}
