import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../../constants.dart';
import '../logging_wrappers.dart';

part 'trigger_action.g.dart';

@HiveType(typeId: 8)
class TriggerAction {
  Timer? _timer;
  Timer? _periodicTimer;
  @HiveField(1)
  final String uuid; //uuid matches triggerActionDef
  @HiveField(2)
  List<String> actions = [];
  ValueNotifier<bool> isActive = ValueNotifier(false);
  ValueNotifier<double> isActiveProgress = ValueNotifier(0);

  TriggerAction(this.uuid) {
    isActive.addListener(() {
      if (isActive.value) {
        isActiveProgress.value = 0.01;
        _timer = Timer(
          Duration(
            seconds: HiveProxy.getOrDefault(
              settings,
              triggerActionCooldown,
              defaultValue: triggerActionCooldownDefault,
            ),
          ),
          () {
            isActive.value = false;
            _periodicTimer?.cancel();
            _timer?.cancel();
            isActiveProgress.value = 0;
            _periodicTimer = null;
            _timer = null;
          },
        );
        _periodicTimer = Timer.periodic(const Duration(milliseconds: 500), (
          Timer timer,
        ) {
          timer.tick;
          double change = (timer.tick + 1) / 30;
          if (change > 1) {
            change = 1;
          }
          isActiveProgress.value = change;
        });
      }
    });
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TriggerAction &&
          runtimeType == other.runtimeType &&
          uuid == other.uuid;

  @override
  int get hashCode => uuid.hashCode;
}
