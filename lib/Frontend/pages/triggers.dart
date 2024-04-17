import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Definitions/Action/base_action.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/sensors.dart';
import 'package:tail_app/Frontend/Widgets/trigger_select.dart';
import 'package:uuid/uuid.dart';

import '../../constants.dart';
import '../../main.dart';
import '../Widgets/device_type_widget.dart';
import '../intn_defs.dart';
import 'action_selector.dart';

class Triggers extends ConsumerStatefulWidget {
  const Triggers({super.key});

  @override
  ConsumerState<Triggers> createState() => _TriggersState();
}

class _TriggersState extends ConsumerState<Triggers> {
  @override
  Widget build(BuildContext context) {
    final List<Trigger> triggersList = ref.watch(triggerListProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        onPressed: () {
          showDialog<TriggerDefinition>(
            context: context,
            useRootNavigator: true,
            builder: (BuildContext context) {
              plausible.event(page: "/Triggers/AddTrigger");
              return const TriggerSelect();
            },
          ).then(
            (TriggerDefinition? value) {
              if (value != null) {
                // The user selected a Trigger Definition
                setState(
                  () {
                    Trigger trigger = Trigger.trigDef(value, const Uuid().v4());
                    ref.watch(triggerListProvider.notifier).add(trigger);
                    plausible.event(name: "Add Trigger", props: {"Trigger Type": value.runtimeType.toString()});
                  },
                );
              }
            },
          );
        },
        label: Text(triggersAdd()),
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
                return ListTile(
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
                );
              },
            )
          ],
        ),
      ),
    );
  }
}

class PageInfoCard extends StatelessWidget {
  final String text;

  const PageInfoCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    bool show = !SentryHive.box(settings).get(hideTutorialCards, defaultValue: hideTutorialCardsDefault);
    return show
        ? Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(text),
                ),
              ),
            ),
          )
        : Container();
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
  void initState() {
    super.initState();
    BackButtonInterceptor.add(myInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(myInterceptor);
    super.dispose();
  }

  bool myInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    Navigator.of(context).pop();
    return true;
  }

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
        PageInfoCard(
          text: triggerInfoEditActionDescription(),
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
                Object? result = await showDialog(
                  useRootNavigator: true,
                  barrierDismissible: true,
                  barrierColor: Theme.of(context).canvasColor,
                  context: context,
                  builder: (BuildContext context) {
                    return Dialog.fullscreen(backgroundColor: Theme.of(context).canvasColor, child: ActionSelector(deviceType: widget.trigger.deviceType.toSet()));
                  },
                );
                if (result is BaseAction) {
                  setState(
                    () {
                      e.action = result.uuid;
                      ref.watch(triggerListProvider.notifier).store();
                    },
                  );
                } else if (result is bool) {
                  if (!result) {
                    setState(
                      () {
                        e.action = null;
                        ref.watch(triggerListProvider.notifier).store();
                      },
                    );
                  }
                }
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
