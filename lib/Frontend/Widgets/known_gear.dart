import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/logging_wrappers.dart';
import '../../Backend/plausible_dio.dart';
import '../../constants.dart';
import '../pages/shell.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';
import 'scan_for_new_device.dart';

class KnownGear extends ConsumerStatefulWidget {
  const KnownGear({super.key});

  @override
  ConsumerState<KnownGear> createState() => _KnownGearState();
}

class _KnownGearState extends ConsumerState<KnownGear> {
  @override
  Widget build(BuildContext context) {
    List<BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider).values.toList()..sort((a, b) => a.deviceConnectionState.value.index.compareTo(b.deviceConnectionState.value.index));
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        ...knownDevices.map((BaseStatefulDevice baseStatefulDevice) => KnownGearCard(baseStatefulDevice: baseStatefulDevice)),
        const ScanForNewGearButton(),
      ],
    );
  }
}

class ScanForNewGearButton extends ConsumerWidget {
  const ScanForNewGearButton({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TweenAnimationBuilder(
      tween: ref.watch(knownDevicesProvider).isEmpty ? Tween<double>(begin: 0, end: 1) : Tween<double>(begin: 1, end: 0),
      duration: animationTransitionDuration,
      builder: (context, value, child) {
        Color? color = Color.lerp(Theme.of(context).cardColor, Theme.of(context).colorScheme.primary, value);
        return Card(
          clipBehavior: Clip.antiAlias,
          color: color,
          child: InkWell(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 50 * MediaQuery.textScalerOf(context).scale(1),
                width: ref.watch(knownDevicesProvider).values.length > 1 ? 100 * MediaQuery.textScalerOf(context).scale(1) : 200 * MediaQuery.textScalerOf(context).scale(1),
                child: Center(
                  child: Text(
                    scanDevicesTitle(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(color: getTextColor(color!)),
                  ),
                ),
              ),
            ),
            onTap: () async {
              plausible.event(page: "Scan For New Gear");
              await showModalBottomSheet(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                enableDrag: true,
                isDismissible: true,
                builder: (BuildContext context) {
                  return DraggableScrollableSheet(
                    initialChildSize: 0.5,
                    expand: false,
                    builder: (BuildContext context, ScrollController scrollController) {
                      return Column(
                        children: [
                          ListTile(
                            title: Text(
                              scanDevicesTitle(),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Expanded(
                            child: ScanForNewDevice(
                              scrollController: scrollController,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class KnownGearCard extends ConsumerStatefulWidget {
  const KnownGearCard({required this.baseStatefulDevice, super.key});

  final BaseStatefulDevice baseStatefulDevice;

  @override
  ConsumerState<KnownGearCard> createState() => _KnownGearCardState();
}

class _KnownGearCardState extends ConsumerState<KnownGearCard> {
  @override
  Widget build(BuildContext context) {
    return FadeIn(
      child: ValueListenableBuilder(
        valueListenable: widget.baseStatefulDevice.deviceConnectionState,
        builder: (BuildContext context, ConnectivityState connectivityState, Widget? child) {
          return Flash(
            animate: connectivityState == ConnectivityState.connected,
            child: ValueListenableBuilder(
              valueListenable: widget.baseStatefulDevice.hasUpdate,
              builder: (BuildContext context, bool hasUpdate, Widget? child) {
                return Badge(
                  isLabelVisible: hasUpdate,
                  largeSize: 35,
                  backgroundColor: Theme.of(context).primaryColor,
                  label: const Icon(Icons.system_update),
                  child: child,
                );
              },
              child: TweenAnimationBuilder(
                tween: connectivityState == ConnectivityState.connected ? Tween<double>(begin: 0, end: 1) : Tween<double>(begin: 1, end: 0),
                duration: animationTransitionDuration,
                builder: (BuildContext context, double value, Widget? child) {
                  Color? cardColor = Color.lerp(Theme.of(context).cardColor, Color(widget.baseStatefulDevice.baseStoredDevice.color), value);
                  Color textColor = getTextColor(cardColor!);
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    color: cardColor,
                    child: InkWell(
                      onTap: () async {
                        unawaited(plausible.event(page: "Manage Gear"));
                        showModalBottomSheet(
                          context: context,
                          showDragHandle: true,
                          isScrollControlled: true,
                          enableDrag: true,
                          isDismissible: true,
                          builder: (BuildContext context) {
                            return DraggableScrollableSheet(
                              expand: false,
                              initialChildSize: 0.7,
                              builder: (BuildContext context, ScrollController scrollController) {
                                return ManageGear(
                                  ref: ref,
                                  device: widget.baseStatefulDevice,
                                  controller: scrollController,
                                );
                              },
                            );
                          },
                        ).then((value) {
                          setState(() {}); //force widget update
                          return;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SizedBox(
                          height: 50,
                          width: 100,
                          child: Stack(
                            children: [
                              Text(
                                widget.baseStatefulDevice.baseStoredDevice.name,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge!.copyWith(color: textColor),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: AnimatedCrossFade(
                                    firstChild: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ValueListenableBuilder(
                                          valueListenable: widget.baseStatefulDevice.batteryLevel,
                                          builder: (BuildContext context, batteryLevel, Widget? child) {
                                            return AnimatedSwitcher(
                                              duration: animationTransitionDuration,
                                              child: getBattery(batteryLevel, textColor),
                                            );
                                          },
                                        ),
                                        ValueListenableBuilder(
                                          valueListenable: widget.baseStatefulDevice.batteryCharging,
                                          builder: (BuildContext context, batteryCharging, Widget? child) {
                                            return AnimatedCrossFade(
                                              firstChild: Icon(Icons.power, color: textColor),
                                              secondChild: Container(),
                                              crossFadeState: batteryCharging ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                              duration: animationTransitionDuration,
                                            );
                                          },
                                        ),
                                        ValueListenableBuilder(
                                          valueListenable: widget.baseStatefulDevice.mandatoryOtaRequired,
                                          builder: (BuildContext context, otaRequired, Widget? child) {
                                            return AnimatedCrossFade(
                                              firstChild: Flash(child: Icon(Icons.warning, color: textColor)),
                                              secondChild: Container(),
                                              crossFadeState: otaRequired ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                              duration: animationTransitionDuration,
                                            );
                                          },
                                        ),
                                        widget.baseStatefulDevice.baseDeviceDefinition.unsupported ? Icon(Icons.warning, color: textColor) : Container(),
                                        ValueListenableBuilder(
                                          valueListenable: widget.baseStatefulDevice.rssi,
                                          builder: (BuildContext context, rssi, Widget? child) {
                                            return AnimatedSwitcher(
                                              duration: animationTransitionDuration,
                                              child: getSignal(rssi, textColor),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    secondChild: Icon(Icons.bluetooth_disabled, color: textColor),
                                    crossFadeState: connectivityState == ConnectivityState.connected ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                    duration: animationTransitionDuration,
                                  ),
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

  Widget getSignal(int rssi, Color color) {
    if (rssi == -1) {
      // Not Connected
      return Icon(Icons.signal_cellular_connected_no_internet_0_bar, color: color);
    } else if (rssi < -80) {
      return Icon(Icons.signal_cellular_alt_1_bar, color: color);
    } else if (rssi < -60) {
      return Icon(Icons.signal_cellular_alt_2_bar, color: color);
    } else {
      return Icon(Icons.signal_cellular_alt, color: color);
    }
  }

  Widget getBattery(double level, Color color) {
    if (HiveProxy.getOrDefault(settings, showAccurateBattery, defaultValue: showAccurateBatteryDefault)) {
      if (level < 0) {
        // battery level is unknown
        return Text(
          '?%',
          style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color),
        );
      }
      return Text(
        '${level.toInt()}%',
        style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color),
      );
    }
    if (level < 0) {
      return Icon(Icons.battery_unknown, color: color);
    }
    if (level < 12.5) {
      return Flash(infinite: true, child: Icon(Icons.battery_0_bar, color: color));
    } else if (level < 25) {
      return Flash(
        infinite: true,
        child: Icon(
          Icons.battery_1_bar,
          color: color,
        ),
      );
    } else if (level < 37.5) {
      return Icon(Icons.battery_2_bar, color: color);
    } else if (level < 50) {
      return Icon(Icons.battery_3_bar, color: color);
    } else if (level < 62.5) {
      return Icon(Icons.battery_4_bar, color: color);
    } else if (level < 75) {
      return Icon(Icons.battery_5_bar, color: color);
    } else if (level < 87.5) {
      return Icon(Icons.battery_6_bar, color: color);
    } else {
      return Icon(Icons.battery_full, color: color);
    }
  }
}
