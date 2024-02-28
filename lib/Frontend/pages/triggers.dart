import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/Definitions/Action/BaseAction.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';
import 'package:tail_app/Backend/Sensors.dart';

import '../../main.dart';
import '../Widgets/action_selector.dart';
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
              builder: (BuildContext context) {
                plausible.event(page: "/Triggers/AddTrigger");
                return AlertDialog(
                  title: Text(triggersSelectLabel()),
                  content: StatefulBuilder(
                    builder: (context, StateSetter setState) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: ref
                            .watch(triggerDefinitionListProvider)
                            .map((TriggerDefinition e) => ListTile(
                                  title: Text(e.name),
                                  leading: Radio<TriggerDefinition>(
                                    value: e,
                                    groupValue: triggerDefinition,
                                    onChanged: (TriggerDefinition? value) {
                                      setState(() {
                                        triggerDefinition = value;
                                      });
                                    },
                                  ),
                                  trailing: e.icon,
                                  subtitle: Text(e.description),
                                ))
                            .toList(),
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
              }).then(
            (TriggerDefinition? value) {
              if (value != null) {
                // The user selected a Trigger Definition
                setState(
                  () {
                    Trigger trigger = Trigger.trigDef(triggerDefinition!);
                    ref.read(triggerListProvider.notifier).add(trigger);
                    plausible.event(name: "Add Trigger", props: {"Type": triggerDefinition!.runtimeType.toString()});
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
                          return ListView(
                            shrinkWrap: true,
                            controller: scrollController,
                            children: [
                              ListTile(
                                title: Text(triggersList[index].triggerDefinition!.name),
                                subtitle: Text(triggersList[index].triggerDefinition!.description),
                                leading: ListenableBuilder(
                                  listenable: triggersList[index],
                                  builder: (BuildContext context, Widget? child) {
                                    return Switch(
                                      value: triggersList[index].enabled,
                                      onChanged: (bool value) {
                                        setState(
                                          () {
                                            triggersList[index].enabled = value;
                                            ref.read(triggerListProvider.notifier).store();
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              ...getTriggerOptions(triggersList[index])
                            ],
                          );
                        });
                  },
                );
              },
              title: Text(triggersList[index].triggerDefinition!.name),
              subtitle: Text(triggersList[index].triggerDefinition!.description),
              leading: ListenableBuilder(
                listenable: triggersList[index],
                builder: (BuildContext context, Widget? child) {
                  return Switch(
                    value: triggersList[index].enabled,
                    onChanged: (bool value) {
                      setState(
                        () {
                          triggersList[index].enabled = value;
                          ref.read(triggerListProvider.notifier).store();
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

  List<Widget> getTriggerOptions(Trigger trigger) {
    List<Widget> results = [];
    results.add(
      ListTile(
        title: Text(deviceType()),
        subtitle: SegmentedButton<DeviceType>(
          multiSelectionEnabled: true,
          selected: trigger.deviceType.toSet(),
          onSelectionChanged: (Set<DeviceType> value) {
            setState(() => trigger.deviceType = value.toList());
            ref.read(triggerListProvider.notifier).store();
          },
          segments: DeviceType.values.map<ButtonSegment<DeviceType>>(
            (DeviceType value) {
              return ButtonSegment<DeviceType>(
                value: value,
                label: Text(value.name),
              );
            },
          ).toList(),
        ),
      ),
    );
    results.addAll(
      trigger.actions.map(
        (TriggerAction e) => ListTile(
          title: Text(trigger.triggerDefinition!.actionTypes.where((element) => e.uuid == element.uuid).first.translated),
          subtitle: Text(ref.read(getActionFromUUIDProvider(e.action))?.name ?? triggerActionNotSet()),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              BaseAction? result = await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return Dialog.fullscreen(child: ActionSelector(deviceType: trigger.deviceType.toSet()));
                  });
              setState(() {
                e.action = result?.uuid;
                ref.read(triggerListProvider.notifier).store();
              });
            },
          ),
        ),
      ),
    );
    return results;
  }
}
