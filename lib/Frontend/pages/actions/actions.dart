import 'package:animate_do/animate_do.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Backend/command_runner.dart';
import 'package:tail_app/Frontend/pages/actions/ear_speed_widget.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../../Backend/Action/action_registry.dart';
import '../../../Backend/Action/base_action.dart';
import '../../../Backend/Device/device_type_enum.dart';
import '../../../Backend/Device/stateful/connected_gear.dart';
import '../../../Backend/Device/tail_control_status_enum.dart';
import '../../../Backend/favorite_actions.dart';
import '../../../Backend/logging_wrappers.dart';
import '../../../constants.dart';
import '../../Widgets/tutorial_card.dart';
import '../../theme_helpers.dart';
import '../../translation_string_definitions.dart';
import '../home.dart';

class ActionPage extends StatelessWidget {
  const ActionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ActionPageBuilder();
  }
}

class ActionPageBuilder extends StatefulWidget {
  const ActionPageBuilder({super.key});

  @override
  State<ActionPageBuilder> createState() => _ActionPageBuilderState();
}

class _ActionPageBuilderState extends State<ActionPageBuilder> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GetActions.instance,
      builder: (context, child) {
        Map<String, Set<BaseAction>> actionsCatMap = GetActions.instance
            .getActions(onlyConnected: true);

        return AnimatedSwitcher(
          duration: animationTransitionDuration,
          child: actionsCatMap.isNotEmpty
              ? ActionsList(actionsCatMap: actionsCatMap)
              : const Home(),
        );
      },
    );
  }
}

class ActionsList extends StatelessWidget {
  const ActionsList({super.key, required this.actionsCatMap});

  final Map<String, Set<BaseAction>> actionsCatMap;

  @override
  Widget build(BuildContext context) {
    bool largerCards = HiveProxy.getOrDefault(
      settings,
      largerActionCardSize,
      defaultValue: largerActionCardSizeDefault,
    );
    List<String> catList = actionsCatMap.keys.toList();
    return ListenableBuilder(
      listenable: FavoriteActions.instance,
      builder: (context, child) {
        return ListView(
          shrinkWrap: false,
          children: [
            ShowEarSpeed(),
            FavoriteActionsButtons(
              largerCards: largerCards,
              actionsCatMap: actionsCatMap,
            ),
            ListView.builder(
              shrinkWrap: true,
              itemCount: catList.length,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (BuildContext context, int categoryIndex) {
                List<BaseAction> actionsForCat = actionsCatMap.values
                    .toList()[categoryIndex]
                    .toList();
                return FadeIn(
                  delay: Duration(milliseconds: 100 * categoryIndex),
                  child: ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    children: [
                      Center(
                        child: Text(
                          catList[categoryIndex],
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      GridView.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: largerCards ? 250 : 125,
                        ),
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: actionsForCat.length,
                        itemBuilder: (BuildContext context, int actionIndex) {
                          return ActionCard(
                            actionIndex: actionIndex,
                            action: actionsForCat[actionIndex],
                            largerCards: largerCards,
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class FavoriteActionsButtons extends StatelessWidget {
  const FavoriteActionsButtons({
    super.key,
    required this.largerCards,
    required this.actionsCatMap,
  });

  final bool largerCards;
  final Map<String, Set<BaseAction>> actionsCatMap;

  @override
  Widget build(BuildContext context) {
    Iterable<BaseAction> availableFavorites = actionsCatMap.values.flattened
        .where(
          (element) => FavoriteActions.instance.state.any(
            (favorite) => favorite.actionUUID == element.uuid,
          ),
        );
    return AnimatedCrossFade(
      firstChild: PageInfoCard(text: actionsFavoriteTip()),
      secondChild: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: largerCards ? 250 : 125,
        ),
        itemCount: availableFavorites.length,
        itemBuilder: (BuildContext context, int index) {
          BaseAction baseAction = availableFavorites.toList()[index];
          return ActionCard(
            actionIndex: index,
            action: baseAction,
            largerCards: largerCards,
          );
        },
      ),
      crossFadeState: availableFavorites.isEmpty
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      duration: animationTransitionDuration,
    );
  }
}

class ShowEarSpeed extends StatelessWidget {
  const ShowEarSpeed({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: animationTransitionDuration,
      child:
          KnownDevices.instance
              .getConnectedGearForType({DeviceType.ears})
              .where((p0) => p0.isTailCoNTROL.value == TailControlStatus.legacy)
              .isNotEmpty
          ? const EarSpeedWidget()
          : null,
    );
  }
}

class ActionCard extends StatefulWidget {
  final int actionIndex;
  final BaseAction action;
  final bool largerCards;

  const ActionCard({
    required this.actionIndex,
    required this.action,
    required this.largerCards,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _ActionCardState();
}

class _ActionCardState extends State<ActionCard> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: KnownDevices.instance,
      builder: (context, child) {
        Color color = getColor(widget.action.deviceCategory.toSet());
        Color textColor = getTextColor(color);
        return Card(
          clipBehavior: Clip.antiAlias,
          color: color,
          elevation: 1,
          child: InkWell(
            onLongPress: toggleActionFavorite,
            onTap: () => runActionOnAllSupportedGear(
              widget.action,
              triggeredBy: "Actions Page",
              useHaptics: true,
            ),
            child: SizedBox.expand(
              child: Stack(
                children: [
                  // Shows when an action is in progress
                  ListenableBuilder(
                    listenable: IsGearMoveRunning.instance,
                    builder: (context, child) {
                      return AnimatedCrossFade(
                        firstChild: Center(child: Container()),
                        secondChild: const Center(
                          child: CircularProgressIndicator(),
                        ),
                        crossFadeState:
                            IsGearMoveRunning.instance.getState(
                              widget.action.deviceCategory.toSet(),
                            )
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        alignment: Alignment.center,
                        duration: animationTransitionDuration,
                      );
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.all(widget.largerCards ? 16 : 8),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: FavoriteActions.instance.contains(widget.action)
                          ? Transform.scale(
                              scale: widget.largerCards ? 1.8 : 0.8,
                              child: Icon(Icons.favorite, color: textColor),
                            )
                          : null,
                    ),
                  ),
                  Center(
                    child: Text(
                      convertToUwU(widget.action.name),
                      semanticsLabel: widget.action.name,
                      overflow: TextOverflow.fade,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge!.copyWith(color: textColor),
                      textScaler: TextScaler.linear(widget.largerCards ? 2 : 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void toggleActionFavorite() async {
    if (HiveProxy.getOrDefault(
      settings,
      haptics,
      defaultValue: hapticsDefault,
    )) {
      HapticFeedback.mediumImpact();
    }

    setState(() {
      if (FavoriteActions.instance.contains(widget.action)) {
        FavoriteActions.instance.remove(widget.action);
      } else {
        FavoriteActions.instance.add(widget.action);
      }
    });
  }

  Color getColor(Set<DeviceType> deviceTypes) {
    final Iterable<StatefulDevice> connectedGear = KnownDevices.instance
        .getConnectedGearForType(deviceTypes);
    if (connectedGear.isEmpty) {
      return deviceTypes.first.color();
    }
    return Color(connectedGear.first.storedDevice.color);
  }
}
