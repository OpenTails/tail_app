import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/Backend/triggers/sensor_definition.dart';
import 'package:tail_app/Backend/triggers/sensor_definition_list.dart';
import 'package:tail_app/Backend/triggers/trigger.dart';

import '../../constants.dart';
import '../Bluetooth/known_devices.dart';
import '../wear_bridge.dart';

class TriggerList with ChangeNotifier {
  final Logger _logger = Logger('TriggerList');
  BuiltList<Trigger> _state = BuiltList();

  BuiltList<Trigger> get state => _state;

  static final TriggerList instance = TriggerList._internal();

  TriggerList._internal() {
    List<Trigger> results = [];
    try {
      results = Hive.box<Trigger>(triggerBox).values
          .map((trigger) {
            Trigger trigger2 = Trigger.trigDef(
              TriggerDefinitionList.allTriggerDefinitions.firstWhere(
                (element) => element.uuid == trigger.triggerDefUUID,
              ),
              trigger.uuid,
            );
            trigger2.actions = trigger.actions;
            return trigger2;
          })
          .toList(growable: true);
    } catch (e, s) {
      _logger.severe("Unable to load stored triggers: $e", e, s);
    }
    Hive.box<Trigger>(triggerBox).close();
    if (results.isEmpty) {
      TriggerDefinition triggerDefinition = TriggerDefinitionList
          .allTriggerDefinitions
          .where(
            (element) => element.uuid == 'ee9379e2-ec4f-40bb-8674-fd223a6edfda',
          )
          .first;
      Trigger trigger = Trigger.trigDef(
        triggerDefinition,
        '91e3d421-6a52-45ab-a23e-f38e4987a8f5',
      );
      _state = [trigger].build();
      store();
    } else {
      _state = results.build();
    }
    KnownDevices.instance
      ..removeListener(_disableAllTriggers)
      ..addListener(_disableAllTriggers);
  }

  Future<void> add(Trigger trigger) async {
    _state = _state.rebuild((p0) => p0.add(trigger));
    await store();
  }

  Future<void> remove(Trigger trigger) async {
    trigger.enabled = false;
    _state = _state.rebuild((p0) => p0.remove(trigger));
    await store();
  }

  Future<void> store() async {
    _logger.info("Storing triggers");
    LazyBox<Trigger> lazyBox = await Hive.openLazyBox<Trigger>(triggerBox);
    await lazyBox.clear();
    await lazyBox.addAll(_state);
    notifyListeners();
    updateWearData(reason: "Trigger Added/Removed");
  }

  void _disableAllTriggers() {
    if (KnownDevices.instance.connectedGear.isNotEmpty) {
      return;
    }
    // Disable all triggers on last device
    state.where((element) => element.enabled).forEach((element) {
      element.enabled = false;
    });
  }
}
