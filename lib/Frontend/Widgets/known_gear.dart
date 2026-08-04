import 'package:animate_do/animate_do.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Bluetooth/known_devices.dart';
import '../../Backend/Bluetooth/bluetooth_issues_check.dart';
import '../../Backend/Device/stateful/connected_gear.dart';
import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../go_router_config.dart';
import '../theme_helpers.dart';
import '../translation_string_definitions.dart';

class KnownGear extends StatefulWidget {
  const KnownGear({super.key, this.hideScanButton = false});

  final bool hideScanButton;

  @override
  State<KnownGear> createState() => _KnownGearState();
}

class _KnownGearState extends State<KnownGear> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BluetoothIssues.instance,
      builder: (context, child) {
        return ListenableBuilder(
          listenable: KnownDevices.instance,
          builder: (BuildContext context, Widget? child) {
            return ValueListenableBuilder(
              valueListenable: isBluetoothEnabled,
              builder: (context, value, child) {
                bool arePermissionsGranted =
                    BluetoothIssues.instance.status ==
                    BluetoothPermissionStatus.granted;

                bool isReady =
                    arePermissionsGranted && isBluetoothEnabled.value;

                if (isReady) {
                  return Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ...KnownDevices.instance.state.values.map(
                        (StatefulDevice statefulDevice) =>
                            KnownGearCard(statefulDevice: statefulDevice),
                      ),
                      if (!widget.hideScanButton) ...[
                        const ScanForNewGearButton(),
                      ],
                    ],
                  );
                } else {
                  return Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width,
                      maxHeight:
                          100 * MediaQuery.textScalerOf(context).scale(1),
                    ),
                    child: Builder(
                      builder: (context) {
                        if (!arePermissionsGranted) {
                          return MissingRequirementsCard(
                            onTap: () async =>
                                BluetoothIssues.instance.requestPermissions(),
                            text: onboardingBluetoothDescription,
                          );
                        } else if (!isBluetoothEnabled.value) {
                          return MissingRequirementsCard(
                            onTap: () async =>
                                await AppSettings.openAppSettings(
                                  type: AppSettingsType.bluetooth,
                                ),
                            text: onboardingBluetoothEnableButtonLabel,
                          );
                        }
                        return Container();
                      },
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

class MissingRequirementsCard extends StatelessWidget {
  const MissingRequirementsCard({
    super.key,
    required this.onTap,
    required this.text,
  });

  final Function onTap;
  final Function text;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: ColorScheme.of(context).error,
      child: InkWell(
        onTap: () => onTap(),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            height: 50 * MediaQuery.textScalerOf(context).scale(1),
            width: 200 * MediaQuery.textScalerOf(context).scale(1),
            child: Center(
              child: Text(
                convertToUwU(text()),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  color: ColorScheme.of(context).onError,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScanForNewGearButton extends StatelessWidget {
  const ScanForNewGearButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: KnownDevices.instance,
      builder: (BuildContext context, Widget? child) {
        return TweenAnimationBuilder(
          tween: KnownDevices.instance.state.isEmpty
              ? Tween<double>(begin: 0, end: 1)
              : Tween<double>(begin: 1, end: 0),
          duration: animationTransitionDuration,
          builder: (context, value, child) {
            Color? color = Color.lerp(
              Theme.of(context).cardColor,
              ColorScheme.of(context).primary,
              value,
            );
            return Card(
              clipBehavior: Clip.antiAlias,
              color: color,
              child: InkWell(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    height: 50 * MediaQuery.textScalerOf(context).scale(1),
                    width: KnownDevices.instance.state.values.length > 1
                        ? 100 * MediaQuery.textScalerOf(context).scale(1)
                        : 200 * MediaQuery.textScalerOf(context).scale(1),
                    child: Center(
                      child: Text(
                        convertToUwU(scanDevicesTitle()),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          color: Color.lerp(
                            ColorScheme.of(context).onSurface,
                            ColorScheme.of(context).onPrimary,
                            value,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                onTap: () async {
                  const ScanForGearRoute().push(context);
                },
              ),
            );
          },
        );
      },
    );
  }
}

class KnownGearCard extends StatefulWidget {
  const KnownGearCard({required this.statefulDevice, super.key});

  final StatefulDevice statefulDevice;

  @override
  State<KnownGearCard> createState() => _KnownGearCardState();
}

class _KnownGearCardState extends State<KnownGearCard> {
  @override
  Widget build(BuildContext context) {
    return FadeIn(
      child: ValueListenableBuilder(
        valueListenable: widget.statefulDevice.deviceConnectionState,
        builder: (BuildContext context, ConnectivityState connectivityState, Widget? child) {
          return Flash(
            animate: connectivityState == ConnectivityState.connected,
            child: ListenableBuilder(
              listenable: Listenable.merge([
                widget.statefulDevice.firmwareStatus,
              ]),
              builder: (BuildContext context, Widget? child) {
                return Badge(
                  isLabelVisible:
                      widget.statefulDevice.firmwareStatus.hasUpdate,
                  largeSize: 35,
                  backgroundColor: ColorScheme.of(context).error,
                  label: Icon(
                    Symbols.system_update,
                    color: ColorScheme.of(context).onError,
                  ),
                  child: Badge(
                    isLabelVisible:
                        widget
                            .statefulDevice
                            .firmwareStatus
                            .mandatoryOtaRequired ||
                        widget.statefulDevice.deviceDefinition.unsupported,
                    largeSize: 35,
                    alignment: AlignmentGeometry.topStart,
                    backgroundColor: ColorScheme.of(context).error,
                    label: Icon(
                      Symbols.warning,
                      color: ColorScheme.of(context).onError,
                    ),
                    child: child,
                  ),
                );
              },
              child: TweenAnimationBuilder(
                tween: connectivityState == ConnectivityState.connected
                    ? Tween<double>(begin: 0, end: 1)
                    : Tween<double>(begin: 1, end: 0),
                duration: animationTransitionDuration,
                builder: (BuildContext context, double value, Widget? child) {
                  Color? cardColor = Color.lerp(
                    Theme.of(context).cardColor,
                    Color(widget.statefulDevice.storedDevice.color),
                    value,
                  );
                  Color textColor = getTextColor(
                    color: cardColor!,
                    context: context,
                  );
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    color: cardColor,
                    margin: const EdgeInsets.all(4),

                    child: InkWell(
                      onTap: () async {
                        ManageGearRoute(
                          btMac:
                              widget.statefulDevice.storedDevice.btMACAddress,
                        ).push(context).then((value) {
                          setState(() {}); //force widget update
                          return;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SizedBox(
                          height: 50,
                          width: 100,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Text(
                                  convertToUwU(
                                    widget.statefulDevice.storedDevice.name,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge!
                                      .copyWith(color: textColor),
                                ),
                              ),
                              Expanded(
                                child: AnimatedCrossFade(
                                  firstChild: ListenableBuilder(
                                    listenable: widget.statefulDevice.battery,
                                    builder: (context, child) => Stack(
                                      alignment: AlignmentGeometry.center,
                                      children: [
                                        Flash(
                                          animate: widget
                                              .statefulDevice
                                              .battery
                                              .isLow,
                                          infinite: true,
                                          child: LinearProgressIndicator(
                                            minHeight: 16,
                                            color: textColor,
                                            backgroundColor: textColor
                                                .withAlpha(100),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            value:
                                                widget
                                                        .statefulDevice
                                                        .battery
                                                        .averagedCurrentLevel >
                                                    -1
                                                ? widget
                                                          .statefulDevice
                                                          .battery
                                                          .averagedCurrentLevel /
                                                      100
                                                : null,
                                          ),
                                        ),
                                        Icon(
                                          widget
                                                  .statefulDevice
                                                  .battery
                                                  .isCharging
                                              ? Symbols
                                                    .battery_android_bolt_rounded
                                              : Symbols.battery_android_0,
                                          color: getTextColor(
                                            color: textColor,
                                            context: context,
                                            invert: false,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  secondChild: Icon(
                                    Symbols.bluetooth_disabled,
                                    color: textColor,
                                  ),
                                  crossFadeState:
                                      connectivityState ==
                                          ConnectivityState.connected
                                      ? CrossFadeState.showFirst
                                      : CrossFadeState.showSecond,
                                  duration: animationTransitionDuration,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget getBattery(double level, Color color) {
    if (HiveProxy.getOrDefault(
      settings,
      showAccurateBattery,
      defaultValue: showAccurateBatteryDefault,
    )) {
      if (level < 0) {
        // battery level is unknown
        return Text('?%');
      }
      return Text(
        '${level.toInt()}%',
        style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color),
      );
    }
    if (level < 0) {
      return Icon(Symbols.battery_unknown, color: color);
    }
    if (level < 12.5) {
      return Flash(
        infinite: true,
        child: Icon(Symbols.battery_0_bar, color: color),
      );
    } else if (level < 25) {
      return Flash(
        infinite: true,
        child: Icon(Symbols.battery_1_bar, color: color),
      );
    } else if (level < 37.5) {
      return Icon(Symbols.battery_2_bar, color: color);
    } else if (level < 50) {
      return Icon(Symbols.battery_3_bar, color: color);
    } else if (level < 62.5) {
      return Icon(Symbols.battery_4_bar, color: color);
    } else if (level < 75) {
      return Icon(Symbols.battery_5_bar, color: color);
    } else if (level < 87.5) {
      return Icon(Symbols.battery_6_bar, color: color);
    } else {
      return Icon(Symbols.battery_full, color: color);
    }
  }
}
