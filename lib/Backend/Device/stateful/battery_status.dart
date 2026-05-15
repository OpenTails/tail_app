import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';

class BatteryStatus with ChangeNotifier {
  Stopwatch stopWatch = Stopwatch();
  double _level = -1;

  double get level => _level;

  set level(double value) {
    if (_level == value) {
      return;
    }

    _level = value;

    // battery graph
    if (value > 0 && !stopWatch.isRunning) {
      stopWatch.start();
    }
    history.add(FlSpot(stopWatch.elapsed.inSeconds.toDouble(), level));

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

  List<FlSpot> history = [];

  void reset() {
    level = -1;
    isCharging = false;
    isLow = false;
    history = List.empty(growable: true);
    stopWatch.reset();
  }
}
