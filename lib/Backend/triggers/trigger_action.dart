import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../../constants.dart';
import '../logging_wrappers.dart';

part 'trigger_action.g.dart';

@HiveType(typeId: 8)
class TriggerAction with ChangeNotifier {
  Timer? _timer;
  Timer? _periodicTimer;
  @HiveField(1)
  final String uuid; //uuid matches triggerActionDef
  @HiveField(2)
  List<String> actions = [];
  bool _isActive = false;
  int _duration = 0;
  final int _progressUpdateInterval = 250;

  bool get isActive => _isActive;

  set isActive(bool value) {
    if (_isActive == value) {
      return;
    }
    _isActive = value;
    if (value) {
      _startTimers();
    } else {
      _triggerTimerFinished();
    }
    notifyListeners();
  }

  double isActiveProgress = 0;

  TriggerAction(this.uuid);

  void _startTimers() {
    _duration = HiveProxy.getOrDefault(
      settings,
      triggerActionCooldown,
      defaultValue: triggerActionCooldownDefault,
    );
    if (isActive) {
      isActiveProgress = 0.01;
      _timer = Timer(
        Duration(seconds: _duration),
        () => _triggerTimerFinished(),
      );
      _periodicTimer = Timer.periodic(
        Duration(milliseconds: _progressUpdateInterval),
        _updateProgressBar,
      );
    }
  }

  void _updateProgressBar(Timer timer) {
    double change =
        (timer.tick + 1) / (_duration / (_progressUpdateInterval * 0.001));
    if (change > 1) {
      change = 1;
    }
    isActiveProgress = change;
    notifyListeners();
  }

  void _triggerTimerFinished() {
    _periodicTimer?.cancel();
    _timer?.cancel();
    isActiveProgress = 0;
    _periodicTimer = null;
    _timer = null;
    isActive = false;
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
