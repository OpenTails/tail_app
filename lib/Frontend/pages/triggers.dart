import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:tail_app/Backend/Definitions/Action/BaseAction.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';
import 'package:tail_app/Backend/Sensors.dart';
import 'package:uuid/uuid.dart';

import '../../constants.dart';
import '../../main.dart';
import '../Widgets/action_selector.dart';
import '../Widgets/device_type_widget.dart';
import '../intnDefs.dart';

class Triggers extends ConsumerStatefulWidget {
  const Triggers({super.key});

  @override
  _TriggersState createState() => _TriggersState();
}

class _TriggersState extends ConsumerState<Triggers> {
  @override
  Widget build(BuildContext context) {
    final List<Trigger> triggersList = ref.watch(triggerListProvider);
    TriggerDefinition? triggerDefinition;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        onPressed: () {
          showDialog<TriggerDefinition>(
            context: context,
            useRootNavigator: false,
            builder: (BuildContext context) {
              plausible.event(page: "/Triggers/AddTrigger");
              return AlertDialog(
                title: Text(triggersSelectLabel()),
                content: StatefulBuilder(
                  builder: (context, StateSetter setState) {
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: ref
                            .watch(triggerDefinitionListProvider)
                            .map((TriggerDefinition e) => ListTile(
                                  title: Text(e.name),
                                  leading: Radio<TriggerDefinition>(
                                    value: e,
                                    groupValue: triggerDefinition,
                                    onChanged: (TriggerDefinition? value) {
                                      setState(
                                        () {
                                          triggerDefinition = value;
                                        },
                                      );
                                    },
                                  ),
                                  trailing: e.icon,
                                  subtitle: Text(e.description),
                                ))
                            .toList(),
                      ),
                    );
                  },
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text(cancel()),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, triggerDefinition);
                    },
                    child: Text(ok()),
                  ),
                ],
              );
            },
          ).then(
            (TriggerDefinition? value) {
              if (value != null) {
                // The user selected a Trigger Definition
                setState(
                  () {
                    Trigger trigger = Trigger.trigDef(triggerDefinition!, const Uuid().v4());
                    ref.watch(triggerListProvider.notifier).add(trigger);
                    plausible.event(name: "Add Trigger", props: {"Trigger Type": triggerDefinition!.runtimeType.toString()});
                  },
                );
              }
            },
          );
        },
        label: Text(triggersAdd()),
      ),
      body: ListView.builder(
        itemCount: triggersList.length,
        primary: true,
        itemBuilder: (BuildContext context, int index) {
          return FadeIn(
            delay: Duration(milliseconds: 100 * index),
            child: ListTile(
              onTap: () {
                showModalBottomSheet(
                  isDismissible: true,
                  isScrollControlled: true,
                  showDragHandle: true,
                  enableDrag: true,
                  useRootNavigator: true,
                  context: context,
                  builder: (BuildContext context) {
                    return DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.5,
                      builder: (BuildContext context, ScrollController scrollController) {
                        return TriggerEdit(trigger: triggersList[index], scrollController: scrollController);
                      },
                    );
                  },
                ).whenComplete(() => setState(() {}));
              },
              title: Text(triggersList[index].triggerDefinition!.name),
              subtitle: MultiValueListenableBuilder(
                  builder: (BuildContext context, List<dynamic> values, Widget? child) {
                    return AnimatedCrossFade(
                      firstChild: Text(triggersList[index].triggerDefinition!.description),
                      secondChild: const LinearProgressIndicator(),
                      crossFadeState: !values.any((element) => element == true) ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                      duration: animationTransitionDuration,
                    );
                  },
                  valueListenables: triggersList[index].actions.map((e) => e.isActive).toList()),
              leading: ListenableBuilder(
                listenable: triggersList[index],
                builder: (BuildContext context, Widget? child) {
                  return Switch(
                    value: triggersList[index].enabled,
                    onChanged: (bool value) {
                      setState(
                        () {
                          triggersList[index].enabled = value;
                          ref.watch(triggerListProvider.notifier).store();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class TriggerEdit extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final Trigger trigger;

  const TriggerEdit({super.key, required this.trigger, required this.scrollController});

  @override
  ConsumerState<TriggerEdit> createState() => _TriggerEditState();
}

class _TriggerEditState extends ConsumerState<TriggerEdit> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      controller: widget.scrollController,
      children: [
        ListTile(
          title: Text(widget.trigger.triggerDefinition!.name),
          subtitle: Text(widget.trigger.triggerDefinition!.description),
          leading: ListenableBuilder(
            listenable: widget.trigger,
            builder: (BuildContext context, Widget? child) {
              return Switch(
                value: widget.trigger.enabled,
                onChanged: (bool value) {
                  setState(
                    () {
                      widget.trigger.enabled = value;
                      plausible.event(name: "Enable Trigger", props: {"Trigger Type": ref.watch(triggerDefinitionListProvider).where((element) => element.uuid == widget.trigger.triggerDefUUID).first.toString()});
                    },
                  );
                },
              );
            },
          ),
        ),
        DeviceTypeWidget(
          selected: widget.trigger.deviceType,
          onSelectionChanged: (Set<DeviceType> value) {
            setState(
              () {
                widget.trigger.deviceType = value.toList();
                ref.watch(triggerListProvider.notifier).store();
              },
            );
          },
        ),
        ...widget.trigger.actions.map(
          (TriggerAction e) => ListTile(
            title: Text(widget.trigger.triggerDefinition!.actionTypes.where((element) => e.uuid == element.uuid).first.translated),
            subtitle: ValueListenableBuilder(
              valueListenable: e.isActive,
              builder: (BuildContext context, value, Widget? child) {
                return AnimatedCrossFade(
                  duration: animationTransitionDuration,
                  secondChild: const LinearProgressIndicator(),
                  firstChild: Text(ref.watch(getActionFromUUIDProvider(e.action))?.name ?? triggerActionNotSet()),
                  crossFadeState: !value ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                );
              },
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                BaseAction? result = await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return Dialog.fullscreen(child: ActionSelector(deviceType: widget.trigger.deviceType.toSet()));
                  },
                );
                setState(
                  () {
                    e.action = result?.uuid;
                    ref.watch(triggerListProvider.notifier).store();
                  },
                );
              },
            ),
          ),
        ),
        ButtonBar(
          children: [
            TextButton(
              onPressed: () {
                setState(
                  () {
                    ref.watch(triggerListProvider).remove(widget.trigger);
                    ref.watch(triggerListProvider.notifier).store();
                    Navigator.of(context).pop();
                  },
                );
              },
              child: const Text("Delete Trigger"),
            ),
          ],
        )
      ],
    );
  }
}
