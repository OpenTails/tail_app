import 'package:tail_app/Backend/logging_wrappers.dart';
import 'package:tail_app/constants.dart';
import 'package:owoify_dart/owoify_dart.dart';

String convertToUwU(String input) {
  if (HiveProxy.getOrDefault(settings, uwuTextEnabled, defaultValue: uwuTextEnabledDefault)) {
    return Owoifier.owoify(input, level: OwoifyLevel.Uvu);
  }
  return input;
}
