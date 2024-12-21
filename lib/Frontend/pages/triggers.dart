import 'package:built_collection/built_collection.dart';
import 'package:choice/choice.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:uuid/uuid.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Definitions/Action/base_action.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/action_registry.dart';
import '../../Backend/plausible_dio.dart';
import '../../Backend/sensors.dart';
import '../../constants.dart';
import '../Widgets/casual_mode_delay_widget.dart';
import '../Widgets/device_type_widget.dart';
import '../Widgets/tutorial_card.dart';
import '../go_router_config.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';
import 'action_selector.dart';

class Triggers extends ConsumerStatefulWidget {
  const Triggers({super.key});

  @override
  ConsumerState<Triggers> createState() => _TriggersState();
}

class _TriggersState extends ConsumerState<Triggers> {
  @override
  Widget build(BuildContext context) {
    final BuiltList<Trigger> triggersList = ref.watch(triggerListProvider);
    return Scaffold(
      floatingActionButton: Builder(
        builder: (context) {
          List<TriggerDefinition> triggerDefinitions = ref.watch(triggerDefinitionListProvider.notifier).get();
          return PromptedChoice<TriggerDefinition>.single(
            itemCount: triggerDefinitions.length,
            itemBuilder: (ChoiceController<TriggerDefinition> state, int index) {
              TriggerDefinition triggerDefinition = triggerDefinitions[index];
              return RadioListTile(
                value: triggerDefinition,
                groupValue: state.single,
                onChanged: (value) {
                  state.select(triggerDefinition);
                },
                secondary: triggerDefinition.icon,
                subtitle: ChoiceText(
                  triggerDefinition.description,
                  highlight: state.search?.value,
                ),
                title: ChoiceText(
                  triggerDefinition.name,
                  highlight: state.search?.value,
                ),
              );
            },
            promptDelegate: ChoicePrompt.delegateBottomSheet(useRootNavigator: true, enableDrag: true, maxHeightFactor: 0.8),
            modalHeaderBuilder: ChoiceModal.createHeader(
              automaticallyImplyLeading: true,
              actionsBuilder: [],
            ),
            modalFooterBuilder: ChoiceModal.createFooter(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                (choiceController) {
                  return FilledButton(
                    onPressed: choiceController.value.isNotEmpty ? () => choiceController.closeModal(confirmed: true) : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                        ),
                        Text(
                          triggersDefSelectSaveLabel(),
                          style: Theme.of(context).textTheme.labelLarge!.copyWith(
                                color: getTextColor(
                                  Theme.of(context).colorScheme.primary,
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
                setState(
                  () {
                    Trigger trigger = Trigger.trigDef(value, const Uuid().v4());
                    ref.watch(triggerListProvider.notifier).add(trigger);
                    plausible.event(name: "Add Trigger", props: {"Trigger Type": value.runtimeType.toString()});
                  },
                );
              }
            },
            anchorBuilder: (state, openModal) {
              return FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: Text(triggersAdd()),
                onPressed: openModal,
              );
            },
          );
        },
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            PageInfoCard(
              text: triggerInfoDescription(),
            ),
            ListView.builder(
              itemCount: triggersList.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (BuildContext context, int index) {
                Trigger trigger = triggersList[index];
                return ListTile(
                  onTap: () async {
                    TriggersEditRoute(uuid: triggersList[index].uuid).push(context).whenComplete(() => setState(() {}));
                  },
                  title: Text(trigger.triggerDefinition!.name),
                  subtitle: MultiValueListenableBuilder(
                    builder: (BuildContext context, List<dynamic> values, Widget? child) {
                      return AnimatedCrossFade(
                        firstChild: Text(trigger.triggerDefinition!.description),
                        secondChild: MultiValueListenableBuilder(
                          valueListenables: trigger.actions.map((e) => e.isActiveProgress).toList(),
                          builder: (context, values, child) {
                            return TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              tween: Tween<double>(
                                begin: 0,
                                end: values.map((e) => e as double).firstWhere(
                                  orElse: () => 0,
                                  (element) {
                                    return element > 0 && element <= 1;
                                  },
                                ),
                              ),
                              builder: (context, value, _) => LinearProgressIndicator(value: value),
                            );
                          },
                        ),
                        crossFadeState: !values.any((element) => element == true) ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                        duration: animationTransitionDuration,
                      );
                    },
                    valueListenables: trigger.actions.map((e) => e.isActive).toList(),
                  ),
                  leading: ListenableBuilder(
                    listenable: trigger,
                    builder: (BuildContext context, Widget? child) {
                      return Semantics(
                        label: 'A switch to toggle the trigger ${trigger.triggerDefinition?.name}',
                        child: Switch(
                          value: trigger.enabled,
                          onChanged: (bool value) async {
                            setState(
                              () {
                                trigger.storedEnable = !trigger.enabled;
                                ref.read(triggerListProvider.notifier).store();
                                plausible.event(name: "Enable Trigger", props: {"Trigger Type": ref.watch(triggerDefinitionListProvider).where((element) => element.uuid == trigger.triggerDefUUID).first.toString()});
                              },
                            );
                          },
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
  }
}

class TriggerEdit extends ConsumerStatefulWidget {
  final String uuid;

  const TriggerEdit({required this.uuid, super.key});

  @override
  ConsumerState<TriggerEdit> createState() => _TriggerEditState();
}

class _TriggerEditState extends ConsumerState<TriggerEdit> {
  Trigger? trigger;
  TriggerDefinition? triggerDefinition;

  @override
  void initState() {
    trigger = ref.read(triggerListProvider).firstWhereOrNull(
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
          return const Center(
            child: Text(''),
          );
        } else {
          return ListView(
            shrinkWrap: true,
            controller: scrollController,
            children: [
              ListTile(
                title: Text(triggerDefinition!.name),
                subtitle: Text(triggerDefinition!.description),
                leading: ListenableBuilder(
                  listenable: trigger!,
                  builder: (BuildContext context, Widget? child) {
                    return Semantics(
                      label: 'A switch to toggle the trigger ${triggerDefinition?.name}',
                      child: Switch(
                        value: trigger!.enabled,
                        onChanged: (bool value) {
                          setState(
                            () async {
                              trigger!.storedEnable = !trigger!.enabled;
                              ref.read(triggerListProvider.notifier).store();
                              plausible.event(name: "Enable Trigger", props: {"Trigger Type": ref.watch(triggerDefinitionListProvider).where((element) => element.uuid == trigger!.triggerDefUUID).first.toString()});
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              DeviceTypeWidget(
                selected: trigger!.deviceType,
                onSelectionChanged: (List<DeviceType> value) {
                  setState(
                    () async {
                      trigger?.deviceType = value.toList();
                      ref.watch(triggerListProvider.notifier).store();
                    },
                  );
                },
              ),
              if (triggerDefinition is RandomTriggerDefinition) ...[const CasualModeDelayWidget()],
              PageInfoCard(
                text: triggerInfoEditActionDescription(),
              ),
              ...trigger!.actions.map(
                (TriggerAction e) => ListTile(
                  title: Text(trigger!.triggerDefinition!.actionTypes.where((element) => e.uuid == element.uuid).first.translated),
                  subtitle: ValueListenableBuilder(
                    valueListenable: e.isActive,
                    builder: (BuildContext context, value, Widget? child) {
                      return AnimatedCrossFade(
                        duration: animationTransitionDuration,
                        secondChild: MultiValueListenableBuilder(
                          valueListenables: trigger!.actions.map((e) => e.isActiveProgress).toList(),
                          builder: (context, values, child) {
                            return TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              tween: Tween<double>(
                                begin: 0,
                                end: values.map((e) => e as double).firstWhere(
                                  orElse: () => 0,
                                  (element) {
                                    return element > 0 && element <= 1;
                                  },
                                ),
                              ),
                              builder: (context, value, _) => LinearProgressIndicator(value: value),
                            );
                          },
                        ),
                        firstChild: Builder(
                          builder: (context) {
                            String text = "";
                            Iterable<BaseStatefulDevice> knownDevices = ref.read(knownDevicesProvider).values;
                            for (String actionUUID in e.actions) {
                              BaseAction? baseAction = ref.watch(getActionFromUUIDProvider(actionUUID));
                              if (baseAction != null &&
                                  (knownDevices.isEmpty ||
                                      knownDevices
                                          .where(
                                            (element) => baseAction.deviceCategory.contains(element.baseDeviceDefinition.deviceType),
                                          )
                                          .isNotEmpty)) {
                                if (text.isNotEmpty) {
                                  text += ', ';
                                }
                                text += baseAction.name;
                              }
                            }
                            return Text(text.isNotEmpty ? text : triggerActionNotSet());
                          },
                        ),
                        crossFadeState: !value ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                      );
                    },
                  ),
                  trailing: IconButton(
                    tooltip: actionsSelectScreen(),
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      Object? result = await showDialog(
                        useRootNavigator: true,
                        barrierDismissible: true,
                        barrierColor: Theme.of(context).canvasColor,
                        context: context,
                        builder: (BuildContext context) {
                          return Dialog.fullscreen(
                            backgroundColor: Theme.of(context).canvasColor,
                            child: ActionSelector(
                              actionSelectorInfo: ActionSelectorInfo(
                                deviceType: trigger!.deviceType.toSet(),
                                selectedActions: e.actions
                                    .map(
                                      (e) => ref.read(getActionFromUUIDProvider(e)),
                                    )
                                    .nonNulls
                                    .toList(),
                              ),
                            ),
                          );
                        },
                      );
                      if (result is List<BaseAction>) {
                        setState(
                          () {
                            e.actions = result.map((element) => element.uuid).toList();
                            ref.watch(triggerListProvider.notifier).store();
                          },
                        );
                      } else if (result is bool) {
                        if (!result) {
                          setState(
                            () {
                              e.actions = [];
                              ref.watch(triggerListProvider.notifier).store();
                            },
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
              OverflowBar(
                children: [
                  TextButton(
                    onPressed: () async {
                      trigger!.enabled = false;
                      await ref.watch(triggerListProvider.notifier).remove(trigger!);
                      setState(
                        () {
                          Navigator.of(context).pop();
                        },
                      );
                    },
                    child: const Text("Delete Trigger"),
                  ),
                ],
              ),
            ],
          );
        }
      },
    );
  }
}
