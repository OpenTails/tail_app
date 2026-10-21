import 'dart:async';

import 'package:circular_buffer/circular_buffer.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

class BatteryStatus with ChangeNotifier {
  StreamSubscription? periodicStream;
  Timer? _batteryIdleAfterMoveTimer;

  double _level = -1;

  double get level => _level;

  /// Returns the battery level averaged to the last minute. (Not rolling)
  /// returns the true battery level for the first minute
  ///
  /// Certain gear can have a battery level drop during a move. This will hopefully level out those battery level drops
  double get averagedCurrentLevel {
    if (averageHistory.isNotEmpty) {
      return averageHistory.last;
    } else {
      return level;
    }
  }

  set level(double value) {
    if (_level == value) {
      return;
    }
    if (_batteryIdleAfterMoveTimer?.isActive == true) {
      return;
    }
    _level = value;

    // battery graph
    if (value > 0 && periodicStream == null) {
      periodicStream = Stream.periodic(Duration(minutes: 1)).listen((event) {
        if (shortTermHistory.isEmpty) {
          return;
        }
        averageHistory.add(shortTermHistory.average);
        shortTermHistory.clear();

        // may clear low battery state from gear
        _isLow = averagedCurrentLevel < 20;
        notifyListeners();
      });
      averageHistory.add(level);
    }
    shortTermHistory.add(level);

    notifyListeners();
  }

  bool _isCharging = false;

  bool get isCharging => _isCharging;

  set isCharging(bool value) {
    _isCharging = value;
    notifyListeners();
  }

  bool _isLow = false;

  /// if battery level is < 20% or gear reports "LOWBATT"
  bool get isLow => _isLow;

  set isLow(bool value) {
    _isLow = value;
    notifyListeners();
  }

  CircularBuffer<double> averageHistory = CircularBuffer(60);
  List<double> shortTermHistory = [];

  /// Delay logging BATT levels for 8 seconds to let the battery level reading settle.
  void startBatteryMoveCooldown() {
    if (_batteryIdleAfterMoveTimer != null ||
        _batteryIdleAfterMoveTimer!.isActive) {
      _batteryIdleAfterMoveTimer?.cancel();
      _batteryIdleAfterMoveTimer = null;
    }

    _batteryIdleAfterMoveTimer = Timer(Duration(seconds: 8), () {
      _batteryIdleAfterMoveTimer = null;
    });
  }

  void reset() {
    level = -1;
    isCharging = false;
    isLow = false;
    shortTermHistory = List.empty(growable: true);
    averageHistory.clear();
    periodicStream?.cancel();
    periodicStream = null;
    _batteryIdleAfterMoveTimer?.cancel();
    _batteryIdleAfterMoveTimer = null;
  }
}
