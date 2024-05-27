import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tail_app/constants.dart';

import '../../Backend/Definitions/Action/base_action.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/action_registry.dart';
import '../intn_defs.dart';

class ActionSelectorInfo {
  final Set<DeviceType> deviceType;
  final List<BaseAction> selectedActions;

  ActionSelectorInfo({required this.deviceType, required this.selectedActions});
}

class ActionSelector extends ConsumerStatefulWidget {
  const ActionSelector({super.key, required this.actionSelectorInfo});

  final ActionSelectorInfo actionSelectorInfo;

  @override
  ConsumerState<ActionSelector> createState() => _ActionSelectorState();
}

class _ActionSelectorState extends ConsumerState<ActionSelector> {
  Map<ActionCategory, Set<BaseAction>> actionsCatMap = {};
  List<ActionCategory> catList = [];
  List<BaseAction> selected = [];

  @override
  void initState() {
    super.initState();
    actionsCatMap = ref.read(getAllActionsProvider(widget.actionSelectorInfo.deviceType));
    catList = actionsCatMap.keys.toList();
    selected = widget.actionSelectorInfo.selectedActions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      primary: true,
      appBar: AppBar(
        title: Text(actionsSelectScreen()),
        actions: [
          IconButton(
            onPressed: () => context.pop(selected),
            icon: const Icon(Icons.save),
            tooltip: triggersSelectSaveLabel(),
          ),
          IconButton(
            onPressed: () => context.pop(true),
            icon: const Icon(Icons.clear),
            tooltip: triggersSelectClearLabel(),
          )
        ],
      ),
      body: ListView.builder(
        primary: true,
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
                    BaseAction baseAction = actionsForCat[actionIndex];
                    bool isSelected = selected.contains(baseAction);
                    return TweenAnimationBuilder(
                      builder: (context, value, child) => Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 2,
                        color: Color.lerp(Theme.of(context).cardColor, Theme.of(context).primaryColor, value),
                        child: child,
                      ),
                      tween: isSelected ? Tween<double>(begin: 0, end: 1) : Tween<double>(begin: 1, end: 0),
                      duration: animationTransitionDuration,
                      child: cardChild(isSelected, baseAction),
                    );
                  })
            ],
          );
        },
      ),
    );
  }

  InkWell cardChild(bool isSelected, BaseAction baseAction) {
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
          child: Text(baseAction.name, semanticsLabel: baseAction.name, overflow: TextOverflow.fade, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
