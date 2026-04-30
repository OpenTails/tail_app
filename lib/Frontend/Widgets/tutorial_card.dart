import 'package:flutter/material.dart';
import 'package:tail_app/Backend/Device/stateful/firmware_status.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../Backend/Bluetooth/known_devices.dart';
import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../go_router_config.dart';
import '../theme_helpers.dart';
import '../translation_string_definitions.dart';
import 'base_card.dart';

class PageInfoCard extends StatelessWidget {
  final String text;

  const PageInfoCard({required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    bool show = !HiveProxy.getOrDefault(
      settings,
      hideTutorialCards,
      defaultValue: hideTutorialCardsDefault,
    );
    if (show) {
      return BaseCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(convertToUwU(text)),
          ),
        ),
      );
    } else {
      return Container();
    }
  }
}

class GearOutOfDateWarning extends StatelessWidget {
  const GearOutOfDateWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: KnownDevices.instance,
      builder: (BuildContext context, Widget? child) {
        List<FirmwareStatus> valueNotifiers = KnownDevices.instance.state.values
            .map((e) => e.firmwareStatus)
            .toList();
        if (valueNotifiers.isNotEmpty) {
          return ListenableBuilder(
            listenable: Listenable.merge(valueNotifiers),
            builder: (context, child) {
              if (valueNotifiers
                  .map((e) => e.mandatoryOtaRequired)
                  .contains(true)) {
                Color color = Theme.of(context).colorScheme.primary;
                return BaseCard(
                  color: color,
                  child: InkWell(
                    onTap: () async {
                      String? mac = KnownDevices.instance.state.values
                          .where(
                            (element) =>
                                element.firmwareStatus.mandatoryOtaRequired,
                          )
                          .firstOrNull
                          ?.storedDevice
                          .btMACAddress;
                      if (mac != null) {
                        OtaUpdateRoute(device: mac).push(context);
                      }
                    },
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          convertToUwU(featureLimitedOtaRequiredLabel()),
                          style: Theme.of(context).textTheme.labelLarge!
                              .copyWith(color: getTextColor(color)),
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
      },
    );
  }
}
