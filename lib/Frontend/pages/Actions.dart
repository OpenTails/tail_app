import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:sentry_hive/sentry_hive.dart';

import '../../Backend/ActionRegistry.dart';
import '../../Backend/Bluetooth/BluetoothManager.dart';
import '../../Backend/Definitions/Action/BaseAction.dart';
import '../../Backend/Definitions/Device/BaseDeviceDefinition.dart';
import '../../Backend/DeviceRegistry.dart';
import '../../Backend/moveLists.dart';
import 'Home.dart';

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
      return MultiValueListenableBuilder(
        valueListenables: knownDevices.values.map((e) => e.deviceConnectionState).toList(),
        builder: (BuildContext context, List<dynamic> values, Widget? child) {
          if (knownDevices.values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected).isNotEmpty) {
            Map<ActionCategory, Set<BaseAction>> actionsCatMap = ref.read(getAvailableActionsProvider);
            List<ActionCategory> catList = actionsCatMap.keys.toList();
            return ListView.builder(
              itemCount: catList.length,
              itemBuilder: (BuildContext context, int categoryIndex) {
                List<BaseAction> actionsForCat = actionsCatMap.values.toList()[categoryIndex].toList();
                return FadeIn(
                  delay: Duration(milliseconds: 100 * categoryIndex),
                  child: Column(
                    children: [
                      Text(
                        catList[categoryIndex].friendly,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 125),
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: actionsForCat.length,
                        itemBuilder: (BuildContext context, int actionIndex) {
                          return MultiValueListenableBuilder(
                            valueListenables: knownDevices.values
                                .where(
                                  (element) => actionsForCat[actionIndex].deviceCategory.contains(element.baseDeviceDefinition.deviceType),
                                )
                                .map((e) => e.deviceState)
                                .toList(),
                            builder: (BuildContext context, List<dynamic> values, Widget? child) {
                              return FadeIn(
                                delay: Duration(milliseconds: 100 * actionIndex),
                                child: Card(
                                  clipBehavior: Clip.antiAlias,
                                  color: Color(knownDevices.values.where((element) => actionsForCat[actionIndex].deviceCategory.contains(element.baseDeviceDefinition.deviceType)).first.baseStoredDevice.color),
                                  elevation: 1,
                                  child: InkWell(
                                    onTap: () async {
                                      if (SentryHive.box('settings').get('haptics', defaultValue: true)) {
                                        HapticFeedback.selectionClick();
                                      }
                                      for (var device in ref.read(getByActionProvider(actionsForCat[actionIndex]))) {
                                        runAction(actionsForCat[actionIndex], device);
                                      }
                                    },
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
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      )
                    ],
                  ),
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
