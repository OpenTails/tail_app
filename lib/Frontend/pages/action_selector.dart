import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Definitions/Action/base_action.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/action_registry.dart';
import '../../constants.dart';
import '../Widgets/tutorial_card.dart';
import '../go_router_config.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';

part 'action_selector.freezed.dart';

@freezed
class ActionSelectorInfo with _$ActionSelectorInfo {
  const factory ActionSelectorInfo({
    required Set<DeviceType> deviceType,
    required List<BaseAction> selectedActions,
  }) = _ActionSelectorInfo;
}

class ActionSelector extends ConsumerStatefulWidget {
  const ActionSelector({required this.actionSelectorInfo, super.key});

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  final ActionSelectorInfo actionSelectorInfo;

  @override
  ConsumerState<ActionSelector> createState() => _ActionSelectorState();
}

class _ActionSelectorState extends ConsumerState<ActionSelector> {
  BuiltMap<ActionCategory, BuiltSet<BaseAction>> actionsCatMap = BuiltMap();
  List<ActionCategory> catList = [];
  List<BaseAction> selected = [];
  Set<DeviceType> knownDeviceTypes = {};

  @override
  void initState() {
    super.initState();
    knownDeviceTypes = ref
        .read(knownDevicesProvider)
        .values
        .map(
          (e) => e.baseDeviceDefinition.deviceType,
        )
        .toSet();
    actionsCatMap = BuiltMap(
      ref.read(getAllActionsProvider).entries.sorted(
        (a, b) {
          int first = a.value
                  .map(
                    (e) => e.deviceCategory,
                  )
                  .flattened
                  .toSet()
                  .intersection(knownDeviceTypes)
                  .isNotEmpty
              ? 1
              : -1;
          int second = b.value
                  .map(
                    (e) => e.deviceCategory,
                  )
                  .flattened
                  .toSet()
                  .intersection(knownDeviceTypes)
                  .isNotEmpty
              ? 1
              : -1;
          return second.compareTo(first);
        },
      ),
    );
    selected = widget.actionSelectorInfo.selectedActions.toList();
    catList = actionsCatMap.keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      primary: true,
      appBar: AppBar(
        title: Text(actionsSelectScreen()),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                selected = actionsCatMap.values.flattened.toList();
              });
            },
            icon: const Icon(Icons.select_all),
            tooltip: triggersSelectAllLabel(),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selected.clear();
              });
            },
            icon: const Icon(Icons.deselect),
            tooltip: triggersSelectClearLabel(),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Theme.of(context).colorScheme.primary.withAlpha(128),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            tileMode: TileMode.clamp,
          ),
        ),
        child: ButtonBar(
          alignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              onPressed: () {
                setState(() {
                  if (selected.isEmpty) {
                    context.pop(true);
                  } else {
                    context.pop(selected);
                  }
                });
              },
              child: Row(
                children: [
                  Icon(
                    Icons.save,
                    color: getTextColor(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                  ),
                  Text(
                    triggersSelectSaveLabel(),
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          color: getTextColor(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        primary: true,
        children: [
          PageInfoCard(text: triggerActionSelectorTutorialLabel()),
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: catList.length,
            itemBuilder: (BuildContext context, int categoryIndex) {
              List<BaseAction> actionsForCat = actionsCatMap.values.toList()[categoryIndex].toList();
              bool hasConnectedDevice = actionsForCat.map((e) => e.deviceCategory).flattened.toSet().intersection(knownDeviceTypes).isNotEmpty;
              return Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: hasConnectedDevice,
                  title: Text(
                    catList[categoryIndex].friendly,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  children: [
                    GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 125),
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: actionsForCat.length,
                      itemBuilder: (BuildContext context, int actionIndex) {
                        BaseAction baseAction = actionsForCat[actionIndex];
                        bool isSelected = selected.contains(baseAction);
                        return TweenAnimationBuilder(
                          builder: (context, value, child) {
                            Color? color = Color.lerp(Theme.of(context).colorScheme.primary, Theme.of(context).cardColor, value);
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              elevation: 2,
                              color: color,
                              child: cardChild(isSelected, baseAction, color!),
                            );
                          },
                          tween: isSelected ? Tween<double>(begin: 1, end: 0) : Tween<double>(begin: 0, end: 1),
                          duration: animationTransitionDuration,
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  InkWell cardChild(bool isSelected, BaseAction baseAction, Color color) {
    return InkWell(
      onTap: () {
        if (isSelected) {
          setState(() {
            selected.remove(baseAction);
          });
        } else {
          setState(() {
            selected.add(baseAction);
          });
        }
      },
      child: SizedBox(
        height: 50,
        width: 50,
        child: Center(
          child: Text(
            baseAction.name,
            semanticsLabel: baseAction.name,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: getTextColor(color)),
          ),
        ),
      ),
    );
  }
}
