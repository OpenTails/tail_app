import 'dart:async';
import 'dart:math';

import 'package:animate_do/animate_do.dart';
import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Frontend/Widgets/ear_speed_widget.dart';

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
    List<BaseStatefulDevice> knownDevicesFiltered = ref.watch(getAvailableGearProvider).toList();
    BuiltMap<ActionCategory, BuiltSet<BaseAction>> actionsCatMap = ref.watch(getAvailableActionsProvider);
    List<ActionCategory> catList = actionsCatMap.keys.toList();
    return AnimatedSwitcher(
      duration: animationTransitionDuration,
      child: actionsCatMap.isNotEmpty
          ? ListView(
              shrinkWrap: false,
              children: [
                //TODO: Remove for TAILCoNTROL update
                AnimatedSwitcher(
                  duration: animationTransitionDuration,
                  child: ref
                          .watch(getAvailableGearForTypeProvider(BuiltSet([DeviceType.ears])))
                          .where(
                            (p0) => p0.isTailCoNTROL.value == TailControlStatus.legacy,
                          )
                          .isNotEmpty
                      ? const EarSpeedWidget()
                      : null,
                ),
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
                      return ActionCard(actionIndex: index, knownDevices: knownDevicesFiltered, action: baseAction, largerCards: largerCards);
                    },
                  ),
                  crossFadeState: actionsCatMap.values.flattened.where((element) => ref.watch(favoriteActionsProvider.notifier).contains(element)).isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  duration: animationTransitionDuration,
                ),
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
                              return ActionCard(actionIndex: actionIndex, knownDevices: knownDevicesFiltered, action: actionsForCat[actionIndex], largerCards: largerCards);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            )
          : const Home(),
    );
  }
}

class ActionCard extends ConsumerStatefulWidget {
  final int actionIndex;
  final List<BaseStatefulDevice> knownDevices;
  final BaseAction action;
  final bool largerCards;

  const ActionCard({required this.actionIndex, required this.knownDevices, required this.action, required this.largerCards, super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ActionCardState();
}

class _ActionCardState extends ConsumerState<ActionCard> {
  @override
  Widget build(BuildContext context) {
    Color color = ref.watch(getColorForDeviceTypeProvider(widget.action.deviceCategory.toBuiltSet()));
    Color textColor = getTextColor(color);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: color,
      elevation: 1,
      child: InkWell(
        onLongPress: () async {
          if (HiveProxy.getOrDefault(settings, haptics, defaultValue: hapticsDefault)) {
            HapticFeedback.mediumImpact();
            setState(
              () {
                if (ref.read(favoriteActionsProvider.notifier).contains(widget.action)) {
                  ref.read(favoriteActionsProvider.notifier).remove(widget.action);
                } else {
                  ref.read(favoriteActionsProvider.notifier).add(widget.action);
                }
              },
            );
          }
        },
        onTap: () async {
          if (HiveProxy.getOrDefault(settings, haptics, defaultValue: hapticsDefault)) {
            HapticFeedback.selectionClick();
          }
          for (var device in ref.read(getByActionProvider(widget.action)).toList()..shuffle()) {
            if (HiveProxy.getOrDefault(settings, kitsuneModeToggle, defaultValue: kitsuneModeDefault)) {
              await Future.delayed(Duration(milliseconds: Random().nextInt(kitsuneDelayRange)));
            }
            ref.read(runActionProvider(widget.action, device));
          }
        },
        child: SizedBox.expand(
          child: Stack(
            children: [
              // Shows when an action is in progress
              AnimatedCrossFade(
                firstChild: Center(child: Container()),
                secondChild: const Center(child: CircularProgressIndicator()),
                crossFadeState: ref.watch(isGearMoveRunningProvider(widget.action.deviceCategory.toBuiltSet())) ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                alignment: Alignment.center,
                duration: animationTransitionDuration,
              ),
              Padding(
                // Indicator of which gear type this would be sent to
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: ref
                      .watch(getAvailableGearForTypeProvider(widget.action.deviceCategory.toBuiltSet()))
                      .where(
                        (baseStatefulDevice) {
                          //TODO: remove after tailcontrol migration period
                          if (widget.action.deviceCategory.contains(DeviceType.ears) && baseStatefulDevice.baseDeviceDefinition.deviceType == DeviceType.ears) {
                            if (baseStatefulDevice.isTailCoNTROL.value == TailControlStatus.tailControl) {
                              // skip legacy moves
                              if (widget.action is EarsMoveList) {
                                return false;
                              }
                              // skip unified moves for legacy firmware ears
                            } else if (baseStatefulDevice.isTailCoNTROL.value == TailControlStatus.legacy) {
                              if (widget.action is CommandAction) {
                                return false;
                              }
                            }
                          }
                          return true;
                        },
                      )
                      .map(
                        (e) => Card(
                          color: Color(e.baseStoredDevice.color),
                          elevation: 0,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              e.baseDeviceDefinition.deviceType.name.substring(0, 1),
                              textScaler: TextScaler.linear(widget.largerCards ? 2 : 1),
                              style: Theme.of(context).textTheme.labelLarge!.copyWith(color: getTextColor(Color(e.baseStoredDevice.color))),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(widget.largerCards ? 16 : 8),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: ref.watch(favoriteActionsProvider.notifier).contains(widget.action)
                      ? Transform.scale(
                          scale: widget.largerCards ? 1.8 : 0.8,
                          child: Icon(Icons.favorite, color: textColor),
                        )
                      : null,
                ),
              ),
              Center(
                child: Text(
                  widget.action.getName(ref.watch(getAvailableGearTypesProvider)),
                  semanticsLabel: widget.action.name,
                  overflow: TextOverflow.fade,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(color: textColor),
                  textScaler: TextScaler.linear(widget.largerCards ? 2 : 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
