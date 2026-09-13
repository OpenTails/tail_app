import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tail_app/Backend/Action/action_list_category.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../Backend/Action/action_registry.dart';
import '../../Backend/Action/base_action.dart';
import '../../constants.dart';
import '../Widgets/tutorial_card.dart';
import '../theme_helpers.dart';
import '../translation_string_definitions.dart';

part 'action_selector.freezed.dart';

@freezed
abstract class ActionSelectorInfo with _$ActionSelectorInfo {
  const factory ActionSelectorInfo({
    required List<BaseAction> selectedActions,
  }) = _ActionSelectorInfo;
}

class ActionSelector extends StatefulWidget {
  const ActionSelector({required this.actionSelectorInfo, super.key});

  final ActionSelectorInfo actionSelectorInfo;

  @override
  State<ActionSelector> createState() => _ActionSelectorState();
}

class _ActionSelectorState extends State<ActionSelector> {
  List<ActionListCategory> actionsCatMap = [];
  List<BaseAction> selected = [];

  @override
  void initState() {
    super.initState();
    actionsCatMap = GetActions.instance.getActionCategories().sorted((a, b) {
      int first = a.isAvailable ? 1 : -1;
      int second = b.isAvailable ? 1 : -1;
      return second.compareTo(first);
    });
    selected = widget.actionSelectorInfo.selectedActions.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      primary: true,
      appBar: AppBar(
        title: Text(convertToUwU(actionsSelectScreen())),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                selected = actionsCatMap
                    .map((e) => e.actions)
                    .flattened
                    .toList();
              });
            },
            icon: const Icon(Symbols.select_all),
            tooltip: triggersSelectAllLabel(),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selected.clear();
              });
            },
            icon: const Icon(Symbols.deselect),
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
        child: OverflowBar(
          alignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  context.pop(selected);
                });
              },
              icon: Icon(Symbols.save),
              label: Text(convertToUwU(triggersSelectSaveLabel())),
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
            itemCount: actionsCatMap.length,
            itemBuilder: (BuildContext context, int categoryIndex) {
              ActionListCategory actionListCategory =
                  actionsCatMap[categoryIndex];
              return Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: actionListCategory.isAvailable,
                  title: Text(
                    convertToUwU(actionListCategory.translated()),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  children: [
                    GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 125,
                          ),
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: actionListCategory.actions.length,
                      itemBuilder: (BuildContext context, int actionIndex) {
                        BaseAction baseAction = actionListCategory.actions
                            .toList()[actionIndex];
                        bool isSelected = selected.contains(baseAction);
                        return TweenAnimationBuilder(
                          builder: (context, value, child) {
                            Color? color = Color.lerp(
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).cardColor,
                              value,
                            );
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              elevation: 2,
                              color: color,
                              margin: const EdgeInsets.all(4),

                              child: cardChild(isSelected, baseAction, color!),
                            );
                          },
                          tween: isSelected
                              ? Tween<double>(begin: 1, end: 0)
                              : Tween<double>(begin: 0, end: 1),
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
            convertToUwU(baseAction.name),
            semanticsLabel: baseAction.name,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: getTextColor(color: color, context: context),
            ),
          ),
        ),
      ),
    );
  }
}
