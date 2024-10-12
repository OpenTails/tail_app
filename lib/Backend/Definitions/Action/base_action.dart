import 'package:built_collection/built_collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../../move_lists.dart';
import '../Device/device_definition.dart';

part 'base_action.freezed.dart';
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
        return "EarGear";
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
  String name = "";
  @HiveField(2)
  List<DeviceType> deviceCategory = DeviceType.values;
  @HiveField(3)
  final ActionCategory actionCategory = ActionCategory.hidden;
  @HiveField(4)
  final String uuid = "";
  final Map<DeviceType, String> nameAlias = {};

  // Priority is Wings -> Ears -> Tail -> default
  String getName(BuiltSet<DeviceType> connectedDeviceTypes) {
    if (connectedDeviceTypes.contains(DeviceType.wings) && deviceCategory.contains(DeviceType.wings) && nameAlias.containsKey(DeviceType.wings)) {
      return nameAlias[DeviceType.wings]!;
    } else if (connectedDeviceTypes.contains(DeviceType.ears) && deviceCategory.contains(DeviceType.ears) && nameAlias.containsKey(DeviceType.ears)) {
      return nameAlias[DeviceType.ears]!;
    } else if ((connectedDeviceTypes.contains(DeviceType.tail) || connectedDeviceTypes.contains(DeviceType.miniTail)) && (deviceCategory.contains(DeviceType.tail) || deviceCategory.contains(DeviceType.miniTail)) && nameAlias.containsKey(DeviceType.tail)) {
      return nameAlias[DeviceType.tail]!;
    }
    return name;
  }
}

@unfreezed
class CommandAction extends BaseAction with _$CommandAction {
  CommandAction._();

  @Implements<BaseAction>()
  factory CommandAction({
    required String command,
    required String name,
    required final String uuid,
    required List<DeviceType> deviceCategory,
    required final ActionCategory actionCategory,
    final String? response,
    @Default({}) final Map<DeviceType, String> nameAlias,
  }) = _CommandAction;

  //TODO: Remove with TAILCoNTROL update
  factory CommandAction.hiddenEars(String command, String response) {
    return CommandAction(command: command, response: response, deviceCategory: [DeviceType.ears], actionCategory: ActionCategory.hidden, uuid: const Uuid().v4(), name: command);
  }
}

@HiveType(typeId: 12)
@unfreezed
class AudioAction extends BaseAction with _$AudioAction implements Comparable<AudioAction> {
  AudioAction._();

  @Implements<BaseAction>()
  factory AudioAction({
    @HiveField(5) required String file,
    @HiveField(1) required String name,
    @HiveField(4) required final String uuid,
    @HiveField(2) @Default(DeviceType.values) final List<DeviceType> deviceCategory,
    @HiveField(3) @Default(ActionCategory.audio) final ActionCategory actionCategory,
    @Default({}) final Map<DeviceType, String> nameAlias,
  }) = _AudioAction;

  @override
  int compareTo(AudioAction other) {
    return file.compareTo(other.file);
  }
}

@unfreezed
@HiveType(typeId: 3)
class MoveList extends BaseAction with _$MoveList {
  MoveList._();

  @Implements<BaseAction>()
  factory MoveList({
    @HiveField(1) required String name,
    @HiveField(4) required final String uuid,
    @HiveField(2) @Default(DeviceType.values) List<DeviceType> deviceCategory,
    @HiveField(3) @Default(ActionCategory.sequence) final ActionCategory actionCategory,
    @HiveField(5) @Default([]) List<Move> moves,
    @HiveField(6) @Default(1) double repeat,
  }) = _MoveList;
}

@freezed
class EarsMoveList extends BaseAction with _$EarsMoveList {
  EarsMoveList._();

  @Implements<BaseAction>()
  factory EarsMoveList({
    @HiveField(1) required String name,
    @HiveField(4) required final String uuid,
    required final List<Object> commandMoves,
    @HiveField(2) @Default([DeviceType.ears]) List<DeviceType> deviceCategory,
    @HiveField(3) @Default(ActionCategory.ears) final ActionCategory actionCategory,
    @Default({}) final Map<DeviceType, String> nameAlias,
  }) = _EarsMoveList;
}
