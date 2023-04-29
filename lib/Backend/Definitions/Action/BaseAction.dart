import 'package:flutter/cupertino.dart';

import '../Device/BaseDeviceDefinition.dart';

enum ActionCategory { other, calm, fast, tense, user, glowtip }

extension ActionCategoryExtension on ActionCategory {
  String get friendly {
    switch (this) {
      case ActionCategory.calm:
        return "Calm and Relaxed";
      case ActionCategory.fast:
        return "Fast and Excited";
      case ActionCategory.tense:
        return "Frustrated and Tense";
      case ActionCategory.user:
        return "User Defined";
      case ActionCategory.glowtip:
        return "GlowTip";
      default:
        "";
    }
    return "";
  }
}

@immutable
class BaseAction {
  final String name;
  final String command;
  final DeviceType deviceCategory;
  final ActionCategory actionCategory;

  const BaseAction(
      this.name, this.command, this.deviceCategory, this.actionCategory);
}
