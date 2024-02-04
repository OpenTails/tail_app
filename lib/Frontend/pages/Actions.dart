import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';
import 'package:tail_app/Frontend/pages/Home.dart';

import '../../Backend/ActionRegistry.dart';
import '../../Backend/Bluetooth/BluetoothManager.dart';
import '../../Backend/Definitions/Action/BaseAction.dart';
import '../../Backend/DeviceRegistry.dart';
import '../../Backend/Settings.dart';
import '../../Backend/moveLists.dart';

class ActionPage extends ConsumerWidget {
  const ActionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ActionPageBuilder();
  }
}

class ActionPageBuilder extends ConsumerWidget {
  const ActionPageBuilder({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<BleStatus> btStatus = ref.watch(btStatusProvider);
    Map<String, BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);
    if (btStatus.valueOrNull != null && btStatus.valueOrNull == BleStatus.ready && knownDevices.isNotEmpty) {
      Map<ActionCategory, Set<BaseAction>> actionsCatMap = ref.watch(getAvailableActionsProvider);
      List<ActionCategory> catList = actionsCatMap.keys.toList();
      return MultiValueListenableBuilder(
        valueListenables: knownDevices.values.map((e) => e.deviceConnectionState).toList(),
        builder: (BuildContext context, List<dynamic> values, Widget? child) {
          if (knownDevices.values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected).isNotEmpty) {
            return ListView.builder(
              itemCount: catList.length,
              itemBuilder: (BuildContext context, int categoryIndex) {
                List<BaseAction> actionsForCat = actionsCatMap.values.toList()[categoryIndex].toList();
                return Column(
                  children: [
                    Center(
                      child: Text(
                        catList[categoryIndex].friendly,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 125),
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: actionsForCat.length,
                      itemBuilder: (BuildContext context, int actionIndex) {
                        return InkWell(
                          onTap: () async {
                            if (ref.read(preferencesProvider).haptics) {
                              await Haptics.vibrate(HapticsType.selection);
                            }
                            for (var device in ref.read(getByActionProvider(actionsForCat[actionIndex]))) {
                              runAction(actionsForCat[actionIndex], device);
                            }
                          },
                          child: MultiValueListenableBuilder(
                            valueListenables: knownDevices.values
                                .where(
                                  (element) => actionsForCat[actionIndex].deviceCategory.contains(element.baseDeviceDefinition.deviceType),
                                )
                                .map((e) => e.deviceState)
                                .toList(),
                            builder: (BuildContext context, List<dynamic> values, Widget? child) {
                              return Card(
                                color: knownDevices.values.where((element) => actionsForCat[actionIndex].deviceCategory.contains(element.baseDeviceDefinition.deviceType)).first.baseDeviceDefinition.deviceType.color.harmonizeWith(Theme.of(context).colorScheme.background),
                                elevation: 1,
                                child: SizedBox.expand(
                                  child: Stack(
                                    children: [
                                      if (knownDevices.values
                                          .where((element) => actionsForCat[actionIndex].deviceCategory.contains(element.baseDeviceDefinition.deviceType))
                                          .where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected)
                                          .where((element) => element.deviceState.value == DeviceState.runAction)
                                          .isNotEmpty) ...[
                                        const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      ],
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                          children: knownDevices.values
                                              .where((element) => actionsForCat[actionIndex].deviceCategory.contains(element.baseDeviceDefinition.deviceType))
                                              .map(
                                                (e) => Text(e.baseDeviceDefinition.deviceType.name.substring(0, 1)),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                      Center(
                                        child: Text(
                                          actionsForCat[actionIndex].name,
                                          semanticsLabel: actionsForCat[actionIndex].name,
                                          overflow: TextOverflow.fade,
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    )
                  ],
                );
              },
            );
          } else {
            return const Home();
          }
        },
      );
    } else {
      return const Home();
    }
  }
}
