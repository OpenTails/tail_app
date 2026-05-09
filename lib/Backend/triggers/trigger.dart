import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:tail_app/Backend/triggers/sensor_definition.dart';
import 'package:tail_app/Backend/triggers/sensor_definition_action_definition.dart';
import 'package:tail_app/Backend/triggers/stored_triggers.dart';
import 'package:tail_app/Backend/triggers/trigger_action.dart';

import '../Action/action_category.dart';
import '../Action/action_registry.dart';

part 'trigger.g.dart';

@HiveType(typeId: 2)
class Trigger extends ChangeNotifier {
  // The sensor definition is stored as a UUID to avoid storing the entire
  // definition class.
  @HiveField(1)
  late final String triggerDefUUID;
  TriggerDefinition? _triggerDefinition;

  TriggerDefinition? get triggerDefinition => _triggerDefinition;

  set triggerDefinition(TriggerDefinition? value) {
    _triggerDefinition = value;
    triggerDefinition
      ?..removeListener(triggerDefListener)
      ..addListener(triggerDefListener);
    triggerDefinition?.optionalSettings = optionalSettings;
  }

  bool _enabled = false;
  @HiveField(4)
  final String uuid;

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (_enabled) {
      triggerDefinition?.triggerActions = actions;
    } else {
      triggerDefinition?.triggerActions = [];
    }
    triggerDefinition?.enabled = value;
  }

  void triggerDefListener() {
    if (triggerDefinition == null) {
      return;
    }
    if (optionalSettings != triggerDefinition!.optionalSettings) {
      optionalSettings = triggerDefinition!.optionalSettings;
      TriggerList.instance.store();
    }
    if (triggerDefinition?.enabled != _enabled && _enabled) {
      enabled = false;
      notifyListeners();
    }
    if (triggerDefinition?.enabled != _enabled && !_enabled) {
      enabled = true;
      notifyListeners();
    }
  }

  @HiveField(3)
  List<TriggerAction> _actions = [];
  @HiveField(5, defaultValue: {})
  Map<String, dynamic> optionalSettings = {};

  List<TriggerAction> get actions => _actions;

  set actions(List<TriggerAction> value) {
    _actions = value;
    if (_enabled) {
      triggerDefinition?.triggerActions = actions;
    }
  }

  Trigger(this.triggerDefUUID, this.uuid) {
    // called by hive when loading object
  }

  Trigger.trigDef(this._triggerDefinition, this.uuid) {
    triggerDefUUID = triggerDefinition!.uuid;
    triggerDefinition
      ?..removeListener(triggerDefListener)
      ..addListener(triggerDefListener);

    actions.addAll(
      triggerDefinition!.triggerActionDefinitions.map(
        (e) => TriggerAction(e.uuid),
      ),
    );

    // Add default triggers
    actions
        .where(
          (TriggerAction triggerAction) => triggerDefinition!
              .triggerActionDefinitions
              .where(
                (TriggerActionDef triggerActionDef) =>
                    triggerActionDef.defaultActions,
              )
              .map((TriggerActionDef triggerActionDef) => triggerActionDef.uuid)
              .contains(triggerAction.uuid),
        )
        .forEach((triggerAction) {
          // Add slow moves
          triggerAction.actions.addAll([
            "c53e980e-899e-4148-a13e-f57a8f9707f4", //Slow 1
            "eb1bdfe7-d374-4e97-943a-13e89f27ddcd", //Slow 2
            "6937b9af-3ff7-43fb-ae62-a403e5dfaf95", //Slow 3
            "769dbe84-3a6e-440d-8b20-234983d36cb6", //Flick Left
            "23144b42-6d3c-4822-8510-ec03c63c7808", //Flick Right
            "fdaff205-0a51-46a0-a5fc-4ea283dce079", //Hewo
          ]);
          // Add glowtip moves
          triggerAction.actions.addAll(
            ActionRegistry.allCommands
                .where(
                  (element) => element.actionCategory == ActionCategory.glowtip,
                )
                .map((e) => e.uuid),
          );
        });
  }
}
