import 'package:hive/hive.dart';
import 'package:tail_app/Frontend/translation_string_definitions.dart';
import 'package:uuid/uuid.dart';

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
  @HiveField(7)
  hidden,
  @HiveField(8)
  audio
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
      case ActionCategory.hidden:
        return "";
      case ActionCategory.audio:
        return audioActionCategory();
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

  final Map<DeviceType, String> nameAlias;

  BaseAction({required this.name, required this.deviceCategory, required this.actionCategory, required this.uuid, this.nameAlias = const {}});

  @override
  String toString() {
    return 'BaseAction{name: $name, deviceCategory: $deviceCategory, actionCategory: $actionCategory}';
  }

  // Priority is Wings -> Ears -> Tail -> default
  String getName(Set<DeviceType> connectedDeviceTypes) {
    if (connectedDeviceTypes.contains(DeviceType.wings) && deviceCategory.contains(DeviceType.wings) && nameAlias.containsKey(DeviceType.wings)) {
      return nameAlias[DeviceType.wings]!;
    } else if (connectedDeviceTypes.contains(DeviceType.ears) && deviceCategory.contains(DeviceType.ears) && nameAlias.containsKey(DeviceType.ears)) {
      return nameAlias[DeviceType.ears]!;
    } else if (connectedDeviceTypes.contains(DeviceType.tail) && deviceCategory.contains(DeviceType.tail) && nameAlias.containsKey(DeviceType.tail)) {
      return nameAlias[DeviceType.tail]!;
    }
    return name;
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is BaseAction && runtimeType == other.runtimeType && uuid == other.uuid;

  @override
  int get hashCode => uuid.hashCode;
}

class CommandAction extends BaseAction {
  final String command;
  final String? response;

  CommandAction({required this.command, this.response, required super.name, required super.deviceCategory, required super.actionCategory, required super.uuid, super.nameAlias});

  factory CommandAction.hiddenEars(String command, String response) {
    return CommandAction(command: command, response: response, deviceCategory: [DeviceType.ears], actionCategory: ActionCategory.hidden, uuid: const Uuid().v4(), name: command);
  }
}

@HiveType(typeId: 12)
class AudioAction extends BaseAction {
  @HiveField(5)
  String file;

  AudioAction({required super.name, super.deviceCategory = DeviceType.values, super.actionCategory = ActionCategory.audio, required super.uuid, required this.file});
}
