import 'package:freezed_annotation/freezed_annotation.dart';

import '../Device/BaseDeviceDefinition.dart';

part 'BaseAction.g.dart';

enum ActionCategory { other, calm, fast, tense, glowtip, ears }

extension ActionCategoryExtension on ActionCategory {
  String get friendly {
    switch (this) {
      case ActionCategory.calm:
        return "Calm and Relaxed";
      case ActionCategory.fast:
        return "Fast and Excited";
      case ActionCategory.tense:
        return "Frustrated and Tense";
      case ActionCategory.glowtip:
        return "GlowTip";
      case ActionCategory.ears:
        return "Ears";
      default:
        "";
    }
    return "";
  }
}

@JsonSerializable(explicitToJson: true)
class BaseAction {
  final String name;
  final String command;
  final DeviceType deviceCategory;
  final ActionCategory actionCategory;

  const BaseAction(this.name, this.command, this.deviceCategory, this.actionCategory);

  factory BaseAction.fromJson(Map<String, dynamic> json) => _$BaseActionFromJson(json);

  Map<String, dynamic> toJson() => _$BaseActionToJson(this);

  @override
  String toString() {
    return 'BaseAction{name: $name, command: $command, deviceCategory: $deviceCategory, actionCategory: $actionCategory}';
  }
}
