import 'package:animate_do/animate_do.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tail_app/Backend/Action/action_list_category.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Backend/Device/command/command_runner.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_app/Frontend/pages/actions/action_group.dart';
import 'package:tail_app/Frontend/pages/actions/ear_speed_widget.dart';
import 'package:tail_app/Frontend/pages/actions/rgb_brightness_widget.dart';

import '../../../Backend/Action/action_registry.dart';
import '../../../Backend/Action/base_action.dart';
import '../../../Backend/Device/device_type_enum.dart';
import '../../../Backend/Device/stateful/connected_gear.dart';
import '../../../Backend/favorite_actions.dart';
import '../../../Backend/logging_wrappers.dart';
import '../../../constants.dart';
import '../../Widgets/tutorial_card.dart';
import '../../go_router_config.dart';
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
      listenable: Listenable.merge([
        GetActions.instance,
        Hive.box(settings).listenable(keys: [actionsSortOrder]),
      ]),
      builder: (context, child) {
        Set<ActionListCategory> actionsList = GetActions.instance
            .getActionCategories(onlyConnected: true);
        List<String> sortOrder = HiveProxy.getOrDefault(
          settings,
          actionsSortOrder,
          defaultValue: actionsSortOrderDefault,
        );

        return AnimatedSwitcher(
          duration: animationTransitionDuration,
          child: actionsList.isNotEmpty
              ? ActionsList(
                  actionsList: GetActions.instance.sortActionListCategories(
                    actionListCategories: actionsList.toList(),
                    sortOrder: sortOrder,
                  ),
                )
              : const Home(),
        );
      },
    );
  }
}

class ActionsList extends StatefulWidget {
  const ActionsList({super.key, required this.actionsList});

  final List<ActionListCategory> actionsList;

  @override
  State<ActionsList> createState() => _ActionsListState();
}

class _ActionsListState extends State<ActionsList> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        FavoriteActions.instance,
        Hive.box(settings).listenable(keys: [largerActionCardSize]),
      ]),
      builder: (context, child) {
        bool largerCards = HiveProxy.getOrDefault(
          settings,
          largerActionCardSize,
          defaultValue: largerActionCardSizeDefault,
        );
        return ListView(
          shrinkWrap: false,
          children: [
            ExpansionTile(
              title: Text(convertToUwU(settingsPage())),
              children: [
                ShowEarSpeed(),
                ShowRGBBrightness(),
                ListTile(
                  title: Text(convertToUwU(settingsLargerCardsToggleTitle())),
                  leading: const Icon(Symbols.format_size),
                  subtitle: Text(
                    convertToUwU(settingsLargerCardsToggleSubTitle()),
                  ),
                  trailing: Switch(
                    value: HiveProxy.getOrDefault(
                      settings,
                      largerActionCardSize,
                      defaultValue: largerActionCardSizeDefault,
                    ),
                    onChanged: (bool value) async {
                      setState(() {
                        HiveProxy.put(settings, largerActionCardSize, value);
                      });
                    },
                  ),
                ),
                ListTile(
                  title: Text(convertToUwU(settingsHapticsToggleTitle())),
                  leading: const Icon(Symbols.vibration),
                  subtitle: Text(convertToUwU(settingsHapticsToggleSubTitle())),
                  trailing: Switch(
                    value: HiveProxy.getOrDefault(
                      settings,
                      haptics,
                      defaultValue: hapticsDefault,
                    ),
                    onChanged: (bool value) async {
                      setState(() {
                        HiveProxy.put(settings, haptics, value);
                      });
                    },
                  ),
                ),
                ListTile(
                  title: Text(convertToUwU(settingsKitsuneToggleTitle())),
                  leading: const Icon(Symbols.more_time),
                  subtitle: Text(convertToUwU(settingsKitsuneToggleSubTitle())),
                  trailing: Switch(
                    value: HiveProxy.getOrDefault(
                      settings,
                      kitsuneModeToggle,
                      defaultValue: kitsuneModeDefault,
                    ),
                    onChanged: (bool value) async {
                      setState(() {
                        HiveProxy.put(settings, kitsuneModeToggle, value);
                      });
                    },
                  ),
                ),
                Wrap(
                  children: [
                    FilledButton(
                      onPressed: () =>
                          ActionsReorderDialogRoute().push(context),
                      child: Text(convertToUwU(actionsReorderButtonTitle())),
                    ),
                  ],
                ),
              ],
            ),
            FavoriteActionsButtons(largerCards: largerCards),
            ListView.builder(
              shrinkWrap: true,
              itemCount: widget.actionsList.length,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (BuildContext context, int categoryIndex) {
                return FadeIn(
                  delay: Duration(milliseconds: 100 * categoryIndex),
                  child: ActionGroup(
                    actionListCategory: widget.actionsList[categoryIndex],
                    largerCards: largerCards,
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
  const FavoriteActionsButtons({super.key, required this.largerCards});

  final bool largerCards;

  @override
  Widget build(BuildContext context) {
    Iterable<BaseAction> availableFavorites = GetActions.instance
        .getFavoriteActions();
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
          return ActionCard(action: baseAction, largerCards: largerCards);
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
              .where((device) => !device.bluetoothUartService!.isTailcontrol)
              .isNotEmpty
          ? const EarSpeedWidget()
          : null,
    );
  }
}

class ShowRGBBrightness extends StatelessWidget {
  const ShowRGBBrightness({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: animationTransitionDuration,
      child: KnownDevices.instance.isRgbGearConnected
          ? const RgbBrightness()
          : null,
    );
  }
}

class ActionCard extends StatefulWidget {
  final BaseAction action;
  final bool largerCards;

  const ActionCard({
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
        Color textColor = getTextColor(color: color, context: context);
        return Card(
          clipBehavior: Clip.antiAlias,
          color: color,
          elevation: 1,
          margin: const EdgeInsets.all(4),
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
                              child: Icon(Symbols.favorite, color: textColor),
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
