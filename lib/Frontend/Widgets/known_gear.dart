import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Frontend/Widgets/scan_for_new_device.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/LoggingWrappers.dart';
import '../../constants.dart';
import '../../main.dart';
import '../pages/shell.dart';
import '../translation_string_definitions.dart';

class KnownGear extends ConsumerStatefulWidget {
  const KnownGear({super.key});

  @override
  ConsumerState<KnownGear> createState() => _KnownGearState();
}

class _KnownGearState extends ConsumerState<KnownGear> {
  @override
  Widget build(BuildContext context) {
    List<BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider).values.toList();
    knownDevices.sort((a, b) => a.deviceConnectionState.value.index.compareTo(b.deviceConnectionState.value.index));
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
        return Card(
          clipBehavior: Clip.antiAlias,
          color: Color.lerp(Theme.of(context).cardColor, Theme.of(context).primaryColor, value),
          child: child,
        );
      },
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
              ),
            ),
          ),
        ),
        onTap: () {
          plausible.event(page: "Scan For New Gear");
          showModalBottomSheet(
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
  }
}

class KnownGearCard extends ConsumerStatefulWidget {
  const KnownGearCard({super.key, required this.baseStatefulDevice});

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
        builder: (BuildContext context, ConnectivityState value, Widget? child) {
          return Flash(
            animate: value == ConnectivityState.connected,
            child: ValueListenableBuilder(
              valueListenable: widget.baseStatefulDevice.hasUpdate,
              builder: (BuildContext context, bool value, Widget? child) {
                return Badge(
                  isLabelVisible: value,
                  largeSize: 35,
                  backgroundColor: Theme.of(context).primaryColor,
                  label: const Icon(Icons.system_update),
                  child: child,
                );
              },
              child: TweenAnimationBuilder(
                tween: value == ConnectivityState.connected ? Tween<double>(begin: 0, end: 1) : Tween<double>(begin: 1, end: 0),
                duration: animationTransitionDuration,
                child: InkWell(
                  onTap: () {
                    plausible.event(page: "Manage Gear");
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
                                      builder: (BuildContext context, value, Widget? child) {
                                        return AnimatedSwitcher(
                                          duration: animationTransitionDuration,
                                          child: getBattery(value),
                                        );
                                      },
                                    ),
                                    ValueListenableBuilder(
                                      valueListenable: widget.baseStatefulDevice.batteryCharging,
                                      builder: (BuildContext context, value, Widget? child) {
                                        return AnimatedCrossFade(
                                          firstChild: const Icon(Icons.power),
                                          secondChild: Container(),
                                          crossFadeState: widget.baseStatefulDevice.deviceConnectionState.value == ConnectivityState.connected && value ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                          duration: animationTransitionDuration,
                                        );
                                      },
                                    ),
                                    ValueListenableBuilder(
                                      valueListenable: widget.baseStatefulDevice.mandatoryOtaRequired,
                                      builder: (BuildContext context, value, Widget? child) {
                                        return AnimatedCrossFade(
                                          firstChild: Flash(child: const Icon(Icons.warning)),
                                          secondChild: Container(),
                                          crossFadeState: value ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                          duration: animationTransitionDuration,
                                        );
                                      },
                                    ),
                                    widget.baseStatefulDevice.baseDeviceDefinition.unsupported ? const Icon(Icons.warning) : Container(),
                                    ValueListenableBuilder(
                                      valueListenable: widget.baseStatefulDevice.rssi,
                                      builder: (BuildContext context, value, Widget? child) {
                                        return AnimatedSwitcher(
                                          duration: animationTransitionDuration,
                                          child: getSignal(value),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                secondChild: const Icon(Icons.bluetooth_disabled),
                                crossFadeState: value == ConnectivityState.connected ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                duration: animationTransitionDuration,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                builder: (BuildContext context, double value, Widget? child) {
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    color: Color.lerp(Theme.of(context).cardColor, Color(widget.baseStatefulDevice.baseStoredDevice.color), value),
                    child: child,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget getSignal(int rssi) {
    if (rssi == -1) {
      // Not Connected
      return const Icon(Icons.signal_cellular_connected_no_internet_0_bar);
    } else if (rssi < -80) {
      return const Icon(Icons.signal_cellular_alt_1_bar);
    } else if (rssi < -60) {
      return const Icon(Icons.signal_cellular_alt_2_bar);
    } else {
      return const Icon(Icons.signal_cellular_alt);
    }
  }

  Widget getBattery(double level) {
    if (HiveProxy.getOrDefault(settings, showAccurateBattery, defaultValue: showAccurateBatteryDefault)) {
      if (level < 0) {
        // battery level is unknown
        return const Text('?%');
      }
      return Text('${level.toInt()}%');
    }
    if (level < 0) {
      return const Icon(Icons.battery_unknown);
    }
    if (level < 12.5) {
      return Flash(infinite: true, child: const Icon(Icons.battery_0_bar));
    } else if (level < 25) {
      return Flash(
        infinite: true,
        child: const Icon(Icons.battery_1_bar),
      );
    } else if (level < 37.5) {
      return const Icon(Icons.battery_2_bar);
    } else if (level < 50) {
      return const Icon(Icons.battery_3_bar);
    } else if (level < 62.5) {
      return const Icon(Icons.battery_4_bar);
    } else if (level < 75) {
      return const Icon(Icons.battery_5_bar);
    } else if (level < 87.5) {
      return const Icon(Icons.battery_6_bar);
    } else {
      return const Icon(Icons.battery_full);
    }
  }
}
