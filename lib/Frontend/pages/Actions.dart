import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:tail_app/Backend/ActionRegistry.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';
import 'package:tail_app/Backend/Definitions/Action/BaseAction.dart';
import 'package:tail_app/Backend/Settings.dart';

import '../../Backend/DeviceRegistry.dart';
import '../../Backend/btMessage.dart';

class ActionPage extends ConsumerWidget {
  const ActionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Map<ActionCategory, Set<BaseAction>> actionsCatMap = ref.watch(getAvailableActionsProvider);
    ref.watch(knownDevicesProvider);
    List<ActionCategory> catList = actionsCatMap.keys.toList();
    return Scaffold(
        body: ListView.builder(
      itemCount: catList.length,
      itemBuilder: (BuildContext context, int categoryIndex) {
        List<BaseAction> actionsForCat = actionsCatMap.values.toList()[categoryIndex].toList();
        return Column(children: [
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
                        BluetoothMessage message = BluetoothMessage(actionsForCat[actionIndex].command, device, Priority.normal);
                        device.commandQueue.addCommand(message);
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
                    ));
              })
        ]);
      },
    ));
  }
}
