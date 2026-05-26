import 'dart:async';

import 'package:circular_buffer/circular_buffer.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

class BatteryStatus with ChangeNotifier {
  StreamSubscription? periodicStream;
  double _level = -1;

  double get level => _level;

  set level(double value) {
    if (_level == value) {
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
        notifyListeners();
      });
      averageHistory.add(level);
    }
    shortTermHistory.add(level);

    //consider gear at low battery even if gear has not reported low battery
    _isLow = level < 20;
    notifyListeners();
  }

  bool _isCharging = false;

  bool get isCharging => _isCharging;

  set isCharging(bool value) {
    _isCharging = value;
    notifyListeners();
  }

  bool _isLow = false;

  bool get isLow => _isLow;

  set isLow(bool value) {
    _isLow = value;
    notifyListeners();
  }

  CircularBuffer<double> averageHistory = CircularBuffer(60);
  List<double> shortTermHistory = [];

  void reset() {
    level = -1;
    isCharging = false;
    isLow = false;
    shortTermHistory = List.empty(growable: true);
    averageHistory.clear();
    periodicStream?.cancel();
    periodicStream = null;
  }
}
