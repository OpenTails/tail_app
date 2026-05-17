import 'package:built_collection/built_collection.dart';
import 'package:choice/choice.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:uuid/uuid.dart';

import '../../Backend/Action/action_registry.dart';
import '../../Backend/Action/base_action.dart';
import '../../Backend/Bluetooth/known_devices.dart';
import '../../Backend/Device/stateful/connected_gear.dart';
import '../../Backend/analytics.dart';
import '../../Backend/triggers/sensor_definition.dart';
import '../../Backend/triggers/sensor_definition_action_definition.dart';
import '../../Backend/triggers/sensor_definition_list.dart';
import '../../Backend/triggers/stored_triggers.dart';
import '../../Backend/triggers/trigger.dart';
import '../../Backend/triggers/trigger_action.dart';
import '../../Backend/utilities/settings.dart';
import '../../constants.dart';
import '../Widgets/tutorial_card.dart';
import '../go_router_config.dart';
import '../theme_helpers.dart';
import '../translation_string_definitions.dart';
import 'action_selector.dart';

//TODO: break up into smaller widgets

class Triggers extends StatefulWidget {
  const Triggers({super.key});

  @override
  State<Triggers> createState() => _TriggersState();
}

class _TriggersState extends State<Triggers> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TriggerList.instance,
      builder: (context, child) {
        final BuiltList<Trigger> triggersList = TriggerList.instance.state;

        return Scaffold(
          floatingActionButton: FutureBuilder(
            future: TriggerDefinitionList.getSupported(),
            builder: (context, snapshot) {
              List<TriggerDefinition> triggerDefinitions = snapshot.data ?? [];
              return AnimatedSwitcher(
                duration: animationTransitionDuration,
                child: triggerDefinitions.isEmpty
                    ? Container()
                    : PromptedChoice<TriggerDefinition>.single(
                        itemCount: triggerDefinitions.length,
                        itemBuilder:
                            (
                              ChoiceController<TriggerDefinition> state,
                              int index,
                            ) {
                              TriggerDefinition triggerDefinition =
                                  triggerDefinitions[index];
                              return RadioListTile(
                                value: triggerDefinition,
                                groupValue: state.single,
                                onChanged: (value) {
                                  state.select(triggerDefinition);
                                },
                                secondary: triggerDefinition.icon,
                                subtitle: ChoiceText(
                                  convertToUwU(triggerDefinition.description()),
                                  highlight: state.search?.value,
                                ),
                                title: ChoiceText(
                                  convertToUwU(triggerDefinition.name()),
                                  highlight: state.search?.value,
                                ),
                              );
                            },
                        promptDelegate: ChoicePrompt.delegateBottomSheet(
                          useRootNavigator: true,
                          enableDrag: true,
                          maxHeightFactor: 0.8,
                        ),
                        modalHeaderBuilder: ChoiceModal.createHeader(
                          automaticallyImplyLeading: true,
                          actionsBuilder: [],
                        ),
                        modalFooterBuilder: ChoiceModal.createFooter(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            (choiceController) {
                              return FilledButton(
                                onPressed: choiceController.value.isNotEmpty
                                    ? () => choiceController.closeModal(
                                        confirmed: true,
                                      )
                                    : null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                    ),
                                    Text(
                                      convertToUwU(
                                        triggersDefSelectSaveLabel(),
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge!
                                          .copyWith(
                                            color: getTextColor(
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ],
                        ),
                        title: triggersSelectLabel(),
                        confirmation: true,
                        onChanged: (value) async {
                          if (value != null) {
                            setState(() {
                              Trigger trigger = Trigger.trigDef(
                                value,
                                const Uuid().v4(),
                              );
                              TriggerList.instance.add(trigger);
                              analyticsEvent(
                                name: "Add Trigger",
                                props: {
                                  "Trigger Type": Intl.withLocale(
                                    'en',
                                    () => value.name(),
                                  ),
                                },
                              );
                            });
                          }
                        },
                        anchorBuilder: (state, openModal) {
                          return FloatingActionButton.extended(
                            icon: const Icon(Icons.add),
                            label: Text(convertToUwU(triggersAdd())),
                            onPressed: openModal,
                          );
                        },
                      ),
              );
            },
          ),
          body: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                PageInfoCard(text: triggerInfoDescription()),
                ListView.builder(
                  itemCount: triggersList.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (BuildContext context, int index) {
                    Trigger trigger = triggersList[index];
                    return ListTile(
                      onTap: () async {
                        TriggersEditRoute(
                          uuid: triggersList[index].uuid,
                        ).push(context).whenComplete(() => setState(() {}));
                      },
                      title: Text(
                        convertToUwU(trigger.triggerDefinition!.name()),
                      ),
                      subtitle: AnimatedCrossFade(
                        firstChild: Text(
                          convertToUwU(
                            trigger.triggerDefinition!.description(),
                          ),
                        ),
                        secondChild: ListenableBuilder(
                          listenable: Listenable.merge(trigger.actions),
                          builder: (context, child) {
                            return TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              tween: Tween<double>(
                                begin: 0,
                                end: trigger.actions
                                    .map((e) => e.isActiveProgress)
                                    .firstWhere(orElse: () => 0, (element) {
                                      return element > 0 && element <= 1;
                                    }),
                              ),
                              builder: (context, value, _) =>
                                  LinearProgressIndicator(value: value),
                            );
                          },
                        ),
                        crossFadeState:
                            !trigger.actions
                                .where((e) => e.isActive)
                                .map((e) => e.isActiveProgress)
                                .any((element) => element > 0)
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        duration: animationTransitionDuration,
                      ),
                      leading: ListenableBuilder(
                        listenable: trigger,
                        builder: (BuildContext context, Widget? child) {
                          return Semantics(
                            label:
                                'A switch to toggle the trigger ${trigger.triggerDefinition?.name}',
                            child: FutureBuilder(
                              future: trigger.triggerDefinition!.isSupported(),
                              builder: (context, snapshot) => Switch(
                                value: trigger.enabled,
                                onChanged: snapshot.data == true
                                    ? (bool value) async {
                                        setState(() {
                                          trigger.enabled = !trigger.enabled;
                                          TriggerDefinition triggerDefinition =
                                              trigger.triggerDefinition!;
                                          analyticsEvent(
                                            name:
                                                "${value ? "Enable" : "Disable"} Trigger",
                                            props: {
                                              "Trigger Type": Intl.withLocale(
                                                'en',
                                                () => triggerDefinition.name(),
                                              ),
                                            },
                                          );
                                        });
                                      }
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TriggerEdit extends StatefulWidget {
  final String uuid;

  const TriggerEdit({required this.uuid, super.key});

  @override
  State<TriggerEdit> createState() => _TriggerEditState();
}

class _TriggerEditState extends State<TriggerEdit> {
  Trigger? trigger;
  TriggerDefinition? triggerDefinition;

  @override
  void initState() {
    trigger = TriggerList.instance.state.firstWhereOrNull(
      (element) => element.uuid == widget.uuid,
    );
    triggerDefinition = trigger?.triggerDefinition;
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      builder: (context, scrollController) {
        if (trigger == null) {
          return const Center(child: Text(''));
        } else {
          return ListenableBuilder(
            listenable: Listenable.merge([
              trigger!,
              ...trigger!.actions,
              if (isDeveloperEnabled) ...[trigger!.triggerDefinition!],
            ]),
            builder: (context, child) {
              return ListView(
                shrinkWrap: true,
                controller: scrollController,
                children: [
                  ListTile(
                    title: Text(convertToUwU(triggerDefinition!.name())),
                    subtitle: Text(
                      convertToUwU(triggerDefinition!.description()),
                    ),
                    leading: Semantics(
                      label:
                          'A switch to toggle the trigger ${triggerDefinition?.name}',
                      child: FutureBuilder(
                        future: trigger!.triggerDefinition!.isSupported(),
                        builder: (context, snapshot) => Switch(
                          value: trigger!.enabled,
                          onChanged: snapshot.data == true
                              ? (bool value) {
                                  setState(() {
                                    trigger!.enabled = !trigger!.enabled;
                                    TriggerDefinition triggerDefinition =
                                        trigger!.triggerDefinition!;
                                    analyticsEvent(
                                      name:
                                          "${value ? "Enable" : "Disable"} Trigger",
                                      props: {
                                        "Trigger Type": Intl.withLocale(
                                          'en',
                                          () => triggerDefinition.name(),
                                        ),
                                      },
                                    );
                                  });
                                }
                              : null,
                        ),
                      ),
                    ),
                  ),
                  if (triggerDefinition!.settingsWidget != null) ...[
                    triggerDefinition!.settingsWidget!,
                  ],
                  if (isDeveloperEnabled) ...[
                    ListTile(
                      title: Text("Debug"),
                      subtitle: Text(trigger!.triggerDefinition!.debug),
                    ),
                  ],
                  PageInfoCard(text: triggerInfoEditActionDescription()),
                  ...trigger!.actions.map((TriggerAction triggerAction) {
                    // Will fail for existing stored data if a
                    // TriggerDefinition action is deleted/UUID changed
                    TriggerActionDef triggerActionDef = trigger!
                        .triggerDefinition!
                        .triggerActionDefinitions
                        .where((element) => triggerAction.uuid == element.uuid)
                        .first;
                    return ListTile(
                      title: Text(convertToUwU(triggerActionDef.translated())),
                      subtitle: AnimatedCrossFade(
                        duration: animationTransitionDuration,
                        secondChild: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          tween: Tween<double>(
                            begin: 0,
                            end: triggerAction.isActiveProgress,
                          ),
                          builder: (context, value, _) =>
                              LinearProgressIndicator(value: value),
                        ),
                        firstChild: Builder(
                          builder: (context) {
                            return ListenableBuilder(
                              listenable: KnownDevices.instance,
                              builder: (context, child) {
                                String text = "";
                                Iterable<StatefulDevice> knownDevices =
                                    KnownDevices.instance.state.values;
                                for (String actionUUID
                                    in triggerAction.actions) {
                                  BaseAction? baseAction =
                                      ActionRegistry.getActionFromUUID(
                                        actionUUID,
                                      );
                                  if (baseAction != null &&
                                      (knownDevices.isEmpty ||
                                          knownDevices
                                              .where(
                                                (element) => baseAction
                                                    .deviceCategory
                                                    .contains(
                                                      element
                                                          .deviceDefinition
                                                          .deviceType,
                                                    ),
                                              )
                                              .isNotEmpty)) {
                                    if (text.isNotEmpty) {
                                      text += ', ';
                                    }
                                    text += baseAction.name;
                                  }
                                }
                                return Text(
                                  convertToUwU(
                                    text.isNotEmpty
                                        ? text
                                        : triggerActionNotSet(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        crossFadeState: !triggerAction.isActive
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                      ),
                      leading: isDeveloperEnabled
                          ? IconButton(
                              onPressed: () {
                                triggerDefinition!.sendCommands(
                                  triggerActionDef.name,
                                );
                              },
                              tooltip: "Run Action (Debug)",
                              icon: Icon(Icons.play_arrow),
                            )
                          : null,
                      trailing: IconButton(
                        tooltip: actionsSelectScreen(),
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          List<BaseAction>? result = await showDialog(
                            useRootNavigator: true,
                            barrierDismissible: true,
                            barrierColor: Theme.of(context).canvasColor,
                            context: context,
                            builder: (BuildContext context) {
                              return Dialog.fullscreen(
                                backgroundColor: Theme.of(context).canvasColor,
                                child: ActionSelector(
                                  actionSelectorInfo: ActionSelectorInfo(
                                    selectedActions: triggerAction.actions
                                        .map(
                                          (e) =>
                                              ActionRegistry.getActionFromUUID(
                                                e,
                                              ),
                                        )
                                        .nonNulls
                                        .toList(),
                                  ),
                                ),
                              );
                            },
                          );
                          if (result != null) {
                            setState(() {
                              triggerAction.actions = result
                                  .map((element) => element.uuid)
                                  .toList();
                              TriggerList.instance.store();
                            });
                          }
                        },
                      ),
                    );
                  }),
                  OverflowBar(
                    children: [
                      TextButton(
                        onPressed: () async {
                          trigger!.enabled = false;
                          await TriggerList.instance.remove(trigger!);
                          TriggerDefinition triggerDefinition =
                              trigger!.triggerDefinition!;
                          analyticsEvent(
                            name: "Delete Trigger",
                            props: {
                              "Trigger Type": Intl.withLocale(
                                'en',
                                () => triggerDefinition.name(),
                              ),
                            },
                          );
                          setState(() {
                            Navigator.of(context).pop();
                          });
                        },
                        child: Text(convertToUwU("Delete Trigger")),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        }
      },
    );
  }
}
