import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tail_app/Frontend/pages/triggers/trigger_action_list_tile.dart';
import 'package:tail_app/Frontend/pages/triggers/triggers.dart';

import '../../../Backend/analytics.dart';
import '../../../Backend/triggers/sensor_definition.dart';
import '../../../Backend/triggers/stored_triggers.dart';
import '../../../Backend/triggers/trigger.dart';
import '../../../Backend/triggers/trigger_action.dart';
import '../../../Backend/utilities/developer_options_helpers.dart';
import '../../Widgets/tutorial_card.dart';
import '../../Widgets/uwu_text.dart';
import '../../translation_string_definitions.dart';

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
                    return TriggerActionListTile(
                      trigger: trigger!,
                      triggerAction: triggerAction,
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
