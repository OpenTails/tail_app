import 'dart:math';

import 'package:animate_do/animate_do.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_listenable_builder/multi_listenable_builder.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Definitions/Action/base_action.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/action_registry.dart';
import '../../Backend/device_registry.dart';
import '../../Backend/favorite_actions.dart';
import '../../Backend/logging_wrappers.dart';
import '../../Backend/move_lists.dart';
import '../../constants.dart';
import '../Widgets/tutorial_card.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';
import 'home.dart';

class ActionPage extends ConsumerWidget {
  const ActionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ActionPageBuilder();
  }
}

class ActionPageBuilder extends ConsumerStatefulWidget {
  const ActionPageBuilder({
    super.key,
  });

  @override
  ConsumerState<ActionPageBuilder> createState() => _ActionPageBuilderState();
}

class _ActionPageBuilderState extends ConsumerState<ActionPageBuilder> {
  @override
  Widget build(BuildContext context) {
    bool largerCards = HiveProxy.getOrDefault(settings, largerActionCardSize, defaultValue: largerActionCardSizeDefault);
    Map<String, BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);

    return MultiValueListenableBuilder(
      valueListenables: knownDevices.isEmpty ? [ValueNotifier(ConnectivityState.disconnected)] : knownDevices.values.map((e) => e.deviceConnectionState).toList(),
      builder: (BuildContext context, List<dynamic> values, Widget? child) {
        Map<String, BaseStatefulDevice> knownDevicesFiltered = Map.fromEntries(knownDevices.entries.where(
          (element) => element.value.deviceConnectionState.value == ConnectivityState.connected,
        ));
        return MultiValueListenableBuilder(
          builder: (context, values, child) {
            Map<ActionCategory, Set<BaseAction>> actionsCatMap = ref.read(getAvailableActionsProvider);
            List<ActionCategory> catList = actionsCatMap.keys.toList();
            return AnimatedCrossFade(
              firstChild: const Home(),
              secondChild: MultiListenableBuilder(
                builder: (BuildContext context, Widget? child) {
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      AnimatedCrossFade(
                          firstChild: PageInfoCard(
                            text: actionsFavoriteTip(),
                          ),
                          secondChild: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: largerCards ? 250 : 125),
                            itemCount: actionsCatMap.values.flattened
                                .where(
                                  (element) => ref.watch(favoriteActionsProvider).any((favorite) => favorite.actionUUID == element.uuid),
                                )
                                .length,
                            itemBuilder: (BuildContext context, int index) {
                              BaseAction baseAction = actionsCatMap.values.flattened
                                  .where(
                                    (element) => ref.watch(favoriteActionsProvider).any((favorite) => favorite.actionUUID == element.uuid),
                                  )
                                  .toList()[index];
                              return getActionCard(index, knownDevicesFiltered, baseAction, largerCards);
                            },
                          ),
                          crossFadeState: actionsCatMap.values.flattened.where((element) => ref.read(favoriteActionsProvider.notifier).contains(element)).isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                          duration: animationTransitionDuration),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: catList.length,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (BuildContext context, int categoryIndex) {
                          List<BaseAction> actionsForCat = actionsCatMap.values.toList()[categoryIndex].toList();
                          return FadeIn(
                            delay: Duration(milliseconds: 100 * categoryIndex),
                            child: ListView(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              children: [
                                Center(
                                  child: Text(
                                    catList[categoryIndex].friendly,
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                GridView.builder(
                                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: largerCards ? 250 : 125),
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: actionsForCat.length,
                                  itemBuilder: (BuildContext context, int actionIndex) {
                                    return MultiValueListenableBuilder(
                                      valueListenables: knownDevicesFiltered.values
                                          .where(
                                            (element) => actionsForCat[actionIndex].deviceCategory.contains(element.baseDeviceDefinition.deviceType),
                                          )
                                          .map((e) => e.deviceState)
                                          .toList(),
                                      builder: (BuildContext context, List<dynamic> values, Widget? child) {
                                        return getActionCard(actionIndex, knownDevicesFiltered, actionsForCat[actionIndex], largerCards);
                                      },
                                    );
                                  },
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
                notifiers: knownDevicesFiltered.isNotEmpty ? knownDevicesFiltered.values.map((e) => e.baseStoredDevice).toList() : [ChangeNotifier()],
              ),
              crossFadeState: actionsCatMap.isNotEmpty ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: animationTransitionDuration,
            );
          },
          valueListenables: knownDevicesFiltered.isEmpty ? [ValueNotifier(false)] : knownDevicesFiltered.values.map((e) => e.hasGlowtip).toList(),
        );
      },
    );
  }

  Widget getActionCard(int actionIndex, Map<String, BaseStatefulDevice> knownDevices, BaseAction action, bool largerCards) {
    Color color = Color(knownDevices.values.where((element) => action.deviceCategory.contains(element.baseDeviceDefinition.deviceType)).first.baseStoredDevice.color);
    Color textColor = getTextColor(color);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: color,
      elevation: 1,
      child: InkWell(
        onLongPress: () {
          if (HiveProxy.getOrDefault(settings, haptics, defaultValue: hapticsDefault)) {
            HapticFeedback.mediumImpact();
            setState(
              () {
                if (ref.read(favoriteActionsProvider.notifier).contains(action)) {
                  ref.read(favoriteActionsProvider.notifier).remove(action);
                } else {
                  ref.read(favoriteActionsProvider.notifier).add(action);
                }
              },
            );
          }
        },
        onTap: () async {
          if (HiveProxy.getOrDefault(settings, haptics, defaultValue: hapticsDefault)) {
            HapticFeedback.selectionClick();
          }
          for (var device in ref.read(getByActionProvider(action)).toList()..shuffle()) {
            if (HiveProxy.getOrDefault(settings, kitsuneModeToggle, defaultValue: kitsuneModeDefault)) {
              await Future.delayed(Duration(milliseconds: Random().nextInt(kitsuneDelayRange)));
            }
            runAction(action, device);
          }
        },
        child: SizedBox.expand(
          child: Stack(
            children: [
              // Shows when an action is in progress
              AnimatedCrossFade(
                firstChild: Container(),
                secondChild: const Center(child: CircularProgressIndicator()),
                crossFadeState: knownDevices.values.where((element) => action.deviceCategory.contains(element.baseDeviceDefinition.deviceType)).where((element) => element.deviceState.value == DeviceState.runAction).isNotEmpty ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                alignment: Alignment.center,
                duration: animationTransitionDuration,
              ),
              Padding(
                // Indicator of which gear type this would be sent to
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: knownDevices.values
                      .where((element) => action.deviceCategory.contains(element.baseDeviceDefinition.deviceType))
                      .map(
                        (e) => Text(
                          e.baseDeviceDefinition.deviceType.name.substring(0, 1),
                          textScaler: TextScaler.linear(largerCards ? 2 : 1),
                          style: Theme.of(context).textTheme.labelLarge!.copyWith(color: textColor),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(largerCards ? 16 : 8),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: ref.read(favoriteActionsProvider.notifier).contains(action)
                      ? Transform.scale(
                          scale: largerCards ? 1.8 : 0.8,
                          child: Icon(Icons.favorite, color: textColor),
                        )
                      : null,
                ),
              ),
              Center(
                child: Text(
                  action.getName(knownDevices.values.map((e) => e.baseDeviceDefinition.deviceType).toSet()),
                  semanticsLabel: action.name,
                  overflow: TextOverflow.fade,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(color: textColor),
                  textScaler: TextScaler.linear(largerCards ? 2 : 1),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
