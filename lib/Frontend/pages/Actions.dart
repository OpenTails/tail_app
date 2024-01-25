import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:tail_app/Frontend/intnDefs.dart';

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
    return const Scaffold(body: ActionPageBuilder());
  }
}

class ActionPageBuilder extends ConsumerWidget {
  const ActionPageBuilder({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(knownDevicesProvider).isNotEmpty && ref.watch(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected).isNotEmpty) {
      Map<ActionCategory, Set<BaseAction>> actionsCatMap = ref.watch(getAvailableActionsProvider);
      List<ActionCategory> catList = actionsCatMap.keys.toList();
      return MultiValueListenableBuilder(
        valueListenables: ref.watch(knownDevicesProvider).values.map((e) => e.deviceConnectionState).toList(),
        builder: (BuildContext context, List<dynamic> values, Widget? child) {
          return ListView.builder(
            itemCount: catList.length,
            itemBuilder: (BuildContext context, int categoryIndex) {
              List<BaseAction> actionsForCat = actionsCatMap.values.toList()[categoryIndex].toList();
              return Column(
                children: [
                  Center(
                    child: Text(
                      catList[categoryIndex].friendly,
                      style: Theme.of(context).textTheme.titleMedium,
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
                        child: Card(
                          elevation: 2,
                          child: SizedBox(
                            height: 50,
                            width: 50,
                            child: Center(
                              child: Text(actionsForCat[actionIndex].name, semanticsLabel: actionsForCat[actionIndex].name),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                ],
              );
            },
          );
        },
      );
    } else {
      return Center(
        child: Text(actionsNoGear()),
      );
    }
  }
}
