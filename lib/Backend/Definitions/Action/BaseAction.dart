import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tail_app/Frontend/intnDefs.dart';

import '../Device/BaseDeviceDefinition.dart';

part 'BaseAction.g.dart';

enum ActionCategory { sequence, calm, fast, tense, glowtip, ears }

extension ActionCategoryExtension on ActionCategory {
  String get friendly {
    switch (this) {
      case ActionCategory.calm:
        return actionsCategoryCalm();
      case ActionCategory.fast:
        return actionsCategoryFast();
      case ActionCategory.tense:
        return actionsCategoryTense();
      case ActionCategory.glowtip:
        return actionsCategoryGlowtip();
      case ActionCategory.ears:
        return actionsCategoryGlowtip();
      case ActionCategory.sequence:
        return sequencesPage();
    }
  }
}

@JsonSerializable(explicitToJson: true)
class BaseAction {
  String name;
  Set<DeviceType> deviceCategory;
  ActionCategory actionCategory;

  BaseAction(this.name, this.deviceCategory, this.actionCategory);

  factory BaseAction.fromJson(Map<String, dynamic> json) => _$BaseActionFromJson(json);

  Map<String, dynamic> toJson() => _$BaseActionToJson(this);

  @override
  String toString() {
    return 'BaseAction{name: $name, deviceCategory: $deviceCategory, actionCategory: $actionCategory}';
  }
}

@JsonSerializable(explicitToJson: true)
class CommandAction extends BaseAction {
  final String command;
  final String? response;

  CommandAction(super.name, this.command, super.deviceCategory, super.actionCategory, this.response);

  factory CommandAction.fromJson(Map<String, dynamic> json) => _$CommandActionFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CommandActionToJson(this);
}
