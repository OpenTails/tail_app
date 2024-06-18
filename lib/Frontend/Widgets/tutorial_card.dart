import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../go_router_config.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';
import 'base_card.dart';

class PageInfoCard extends StatelessWidget {
  final String text;

  const PageInfoCard({required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    bool show = !HiveProxy.getOrDefault(settings, hideTutorialCards, defaultValue: hideTutorialCardsDefault);
    if (show) {
      return BaseCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(text),
          ),
        ),
      );
    } else {
      return Container();
    }
  }
}

class GearOutOfDateWarning extends ConsumerWidget {
  const GearOutOfDateWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<ValueNotifier<bool>> valueNotifiers = ref
        .watch(knownDevicesProvider)
        .values
        .map(
          (e) => e.mandatoryOtaRequired,
        )
        .toList();
    if (valueNotifiers.isNotEmpty) {
      return MultiValueListenableBuilder(
        valueListenables: valueNotifiers,
        builder: (context, values, child) {
          if (values.contains(true)) {
            Color color = Theme.of(context).colorScheme.primary;
            return BaseCard(
              color: color,
              child: InkWell(
                onTap: () async {
                  String? mac = ref
                      .read(knownDevicesProvider)
                      .values
                      .where(
                        (element) => element.mandatoryOtaRequired.value,
                      )
                      .firstOrNull
                      ?.baseStoredDevice
                      .btMACAddress;
                  if (mac != null) {
                    OtaUpdateRoute(device: mac).push(context);
                  }
                },
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      featureLimitedOtaRequiredLabel(),
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: getTextColor(color)),
                    ),
                  ),
                ),
              ),
            );
          } else {
            return Container();
          }
        },
      );
    } else {
      return Container();
    }
  }
}
