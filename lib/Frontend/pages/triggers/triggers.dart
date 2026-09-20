import 'package:built_collection/built_collection.dart';
import 'package:choice/choice.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:uuid/uuid.dart';

import '../../../Backend/analytics.dart';
import '../../../Backend/triggers/sensor_definition.dart';
import '../../../Backend/triggers/sensor_definition_list.dart';
import '../../../Backend/triggers/stored_triggers.dart';
import '../../../Backend/triggers/trigger.dart';
import '../../../constants.dart';
import '../../Widgets/tutorial_card.dart';
import '../../go_router_config.dart';
import '../../translation_string_definitions.dart';

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
                    : FloatingActionButton(
                        tooltip: convertToUwU(triggersAdd()),
                        onPressed: () => AddTriggerDialogRoute().push(context),
                        child: Icon(Symbols.add),
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
