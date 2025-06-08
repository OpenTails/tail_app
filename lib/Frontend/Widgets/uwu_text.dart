import 'package:tail_app/Backend/logging_wrappers.dart';
import 'package:tail_app/constants.dart';

String convertToUwU(String input) {
  if (HiveProxy.getOrDefault(settings, uwuTextEnabled, defaultValue: uwuTextEnabledDefault)) {
    return input.replaceAll("r", "w").replaceAll("R", "W").replaceAll("l", "w").replaceAll("L", "W");
  }
  return input;
}
