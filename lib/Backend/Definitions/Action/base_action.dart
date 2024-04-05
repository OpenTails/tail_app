import 'package:hive/hive.dart';
import 'package:tail_app/Frontend/intn_defs.dart';

import '../Device/device_definition.dart';

part 'base_action.g.dart';

@HiveType(typeId: 7)
enum ActionCategory {
  @HiveField(1)
  sequence,
  @HiveField(2)
  calm,
  @HiveField(3)
  fast,
  @HiveField(4)
  tense,
  @HiveField(5)
  glowtip,
  @HiveField(6)
  ears,
}

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
        return actionsCategoryEars();
      case ActionCategory.sequence:
        return sequencesPage();
    }
  }
}

@HiveType(typeId: 4)
class BaseAction {
  @HiveField(1)
  String name;
  @HiveField(2)
  List<DeviceType> deviceCategory;
  @HiveField(3)
  ActionCategory actionCategory;
  @HiveField(4)
  final String uuid;

  BaseAction(this.name, this.deviceCategory, this.actionCategory, this.uuid);

  @override
  String toString() {
    return 'BaseAction{name: $name, deviceCategory: $deviceCategory, actionCategory: $actionCategory}';
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is BaseAction && runtimeType == other.runtimeType && uuid == other.uuid;

  @override
  int get hashCode => uuid.hashCode;
}

class CommandAction extends BaseAction {
  final String command;
  final String? response;

  CommandAction(super.name, this.command, super.deviceCategory, super.actionCategory, this.response, super.uuid);
}
