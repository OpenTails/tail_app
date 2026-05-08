import 'package:tail_app/Backend/logging_wrappers.dart';
import 'package:tail_app/constants.dart';

bool get isDeveloperEnabled => HiveProxy.getOrDefault(
  settings,
  showDebugging,
  defaultValue: showDebuggingDefault,
);
