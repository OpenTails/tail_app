import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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
    KnownDevices.instance
      ..removeListener(_disableAllTriggers)
      ..addListener(_disableAllTriggers);
    this
      ..removeListener(updateSentryContext)
      ..addListener(updateSentryContext);
    reload();
  }

  @visibleForTesting
  Future<void> reload() async {
    final ISentrySpan? span = Sentry.getSpan()?.startChild(
      'StoredTriggers.reload',
    );
    List<Trigger> results = [];
    try {
      Box<Trigger> box = await Hive.openBox<Trigger>(triggerBox);
      results = box.values
          .map((trigger) {
            trigger.triggerDefinition = TriggerDefinitionList
                .allTriggerDefinitions
                .firstWhereOrNull(
                  (element) => element.uuid == trigger.triggerDefUUID,
                );
            return trigger;
          })
          .where((trigger) => trigger.triggerDefinition != null)
          .toList(growable: true);
    } catch (e, s) {
      _logger.severe("Unable to load stored triggers: $e", e, s);
      await Hive.deleteBoxFromDisk(triggerBox);
    }
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
      //store();
    } else {
      _state = results.build();
    }
    notifyListeners();
    updateWearData(reason: "Triggers loaded");
    span?.finish();
  }

  Future<void> add(Trigger trigger) async {
    final ISentrySpan? span = Sentry.getSpan()?.startChild(
      'StoredTriggers.add',
    );
    _state = _state.rebuild((p0) => p0.add(trigger));
    await store();
    span?.finish();
  }

  Future<void> remove(Trigger trigger) async {
    final ISentrySpan? span = Sentry.getSpan()?.startChild(
      'StoredTriggers.remove',
    );
    trigger.enabled = false;
    _state = _state.rebuild((p0) => p0.remove(trigger));
    await store();
    span?.finish();
  }

  Future<void> store() async {
    final ISentrySpan? span = Sentry.getSpan()?.startChild(
      'StoredTriggers.store',
    );
    _logger.info("Storing triggers");
    Box<Trigger> box = await Hive.openBox<Trigger>(triggerBox);
    await box.clear();
    await box.addAll(_state);
    notifyListeners();
    updateWearData(reason: "Trigger Added/Removed");
    span?.finish();
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

  void updateSentryContext() {
    Sentry.configureScope(
      (scope) => scope.setContexts('Sensors', {
        "Enabled": state
            .map((trigger) => trigger.triggerDefinition)
            .nonNulls
            .where((triggerDefinition) => triggerDefinition.enabled)
            .map(
              (triggerDefinition) =>
                  Intl.withLocale('en', () => triggerDefinition.name()),
            )
            .toString(),
        "Configured": state
            .map((trigger) => trigger.triggerDefinition)
            .nonNulls
            .map(
              (triggerDefinition) =>
                  Intl.withLocale('en', () => triggerDefinition.name()),
            )
            .toString(),
      }),
    );
  }
}
