import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Bluetooth/btMessage.dart';
import 'package:tail_app/Backend/Definitions/Action/BaseAction.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';
import 'package:tail_app/Frontend/intnDefs.dart';

part 'moveLists.g.dart';

@HiveType(typeId: 10)
enum EasingType {
  @HiveField(1)
  linear,
  @HiveField(2)
  cubic,
}

extension EasingTypeExtension on EasingType {
  Widget widget(BuildContext context) {
    switch (this) {
      case EasingType.linear:
        return SizedBox(
          width: 65,
          child: Sparkline(
            data: const [0, 1],
            lineColor: Theme.of(context).colorScheme.outline,
            lineWidth: 5,
          ),
        );
      case EasingType.cubic:
        return SizedBox(
          width: 65,
          child: Sparkline(
            data: const [0.271, 0.488, 0.657, 0.784, 0.875, 0.936, 0.973, 0.992, 0.999, 1, 1.001, 1.008, 1.027, 1.064, 1.125, 1.216, 1.343, 1.512, 1.729, 2],
            lineColor: Theme.of(context).colorScheme.outline,
            lineWidth: 5,
          ),
        );
    }
  }

  int get num {
    switch (this) {
      case EasingType.linear:
        return 0;
      case EasingType.cubic:
        return 130;
    }
  }
}

@HiveType(typeId: 9)
enum Speed {
  @HiveField(1)
  slow,
  @HiveField(2)
  fast,
}

extension SpeedExtension on Speed {
  String get name {
    switch (this) {
      case Speed.slow:
        return sequencesEditSpeedSlow();
      case Speed.fast:
        return sequencesEditSpeedFast();
    }
  }

  int get speed {
    switch (this) {
      case Speed.slow:
        return 50;
      case Speed.fast:
        return 10;
    }
  }
}

@HiveType(typeId: 11)
enum MoveType {
  @HiveField(1)
  move,
  @HiveField(2)
  delay,
  @HiveField(3)
  home,
}

extension MoveTypeExtension on MoveType {
  IconData get icon {
    switch (this) {
      case MoveType.move:
        return Icons.moving;
      case MoveType.delay:
        return Icons.timelapse;
      case MoveType.home:
        Icons.home;
    }
    return Icons.question_mark;
  }
}

@HiveType(typeId: 5)
class Move {
  //Range 0-180
  @HiveField(1)
  double leftServo = 0;

  //Range 0-180
  @HiveField(2)
  double rightServo = 0;
  @HiveField(3)
  Speed speed = Speed.fast;

  @HiveField(4)
  double time = 1;
  @HiveField(5, defaultValue: EasingType.linear)
  EasingType easingType = EasingType.linear;
  @HiveField(6, defaultValue: MoveType.move)
  MoveType moveType = MoveType.move;

  Move();

  @override
  String toString() {
    switch (moveType) {
      case MoveType.move:
        return '${sequencesEditLeftServo()} ${leftServo.round()} | ${sequencesEditRightServo()} ${rightServo.round()} | ${sequencesEditSpeed()} ${speed.name}';
      case MoveType.delay:
        return sequenceEditListDelayLabel(time.round());
      case MoveType.home:
        return sequencesEditHomeLabel();
    }
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Move && runtimeType == other.runtimeType && leftServo == other.leftServo && rightServo == other.rightServo && speed == other.speed && time == other.time && easingType == other.easingType && moveType == other.moveType;

  @override
  int get hashCode => leftServo.hashCode ^ rightServo.hashCode ^ speed.hashCode ^ time.hashCode ^ easingType.hashCode ^ moveType.hashCode;
}

@HiveType(typeId: 3)
class MoveList extends BaseAction {
  @HiveField(5)
  List<Move> moves = [];
  @HiveField(6)
  bool homeAtEnd = true;

  MoveList(super.name, super.deviceCategory, super.actionCategory, super.uuid) {
    super.actionCategory = ActionCategory.sequence;
  }
}

@Riverpod(keepAlive: true)
class MoveLists extends _$MoveLists {
  @override
  List<MoveList> build() {
    return SentryHive.box<MoveList>('sequences').values.toList();
  }

  void add(MoveList moveList) {
    List<MoveList> state2 = List.from(state);
    state2.add(moveList);
    state = state2;
  }

  void remove(MoveList moveList) {
    List<MoveList> state2 = List.from(state);
    state2.remove(moveList);
    state = state2;
  }

  Future<void> store() async {
    Flogger.i("Storing sequences");
    SentryHive.box<MoveList>('sequences')
      ..clear()
      ..addAll(state);
  }
}

Future<void> runAction(BaseAction action, BaseStatefulDevice device) async {
  if (action is CommandAction) {
    device.commandQueue.addCommand(BluetoothMessage.response(action.command, device, Priority.normal, action.response));
  } else if (action is MoveList) {
    await (MoveList moveList, BaseStatefulDevice device) async {
      Flogger.i("Starting MoveList ${moveList.name}.");
      // add final home move
      List<Move> newMoveList = List.from(moveList.moves); //prevent home move from being added to original MoveList
      if (moveList.homeAtEnd) {
        Move move = Move();
        move.moveType = MoveType.home;
        //newMoveList.add(move);
      }
      //TODO: Merge move commands into 1 large command
      for (Move element in newMoveList) {
        //run move command
        if (element.moveType == MoveType.delay) {
          BluetoothMessage message = BluetoothMessage.delay(element.time, device, Priority.normal);
          device.commandQueue.addCommand(message);
        } else {
          //Generate move command
          generateMoveCommand(element, device).forEach(
            (element) {
              device.commandQueue.addCommand(element);
            },
          );
        }
      }
    }(action, device);
  }
}

List<BluetoothMessage> generateMoveCommand(Move move, BaseStatefulDevice device) {
  List<BluetoothMessage> commands = [];
  if (move.moveType == MoveType.home) {
    if (device.baseDeviceDefinition.deviceType == DeviceType.ears) {
      commands.add(BluetoothMessage.response("EarHome", device, Priority.normal, "EARHOME END"));
    } else {
      commands.add(BluetoothMessage.response("TAILHM", device, Priority.normal, "END TAILHM"));
    }
  } else if (move.moveType == MoveType.move) {
    if (device.baseDeviceDefinition.deviceType == DeviceType.ears) {
      commands.add(BluetoothMessage.response("SPEED ${move.speed.name.toUpperCase()}", device, Priority.normal, "SPEED ${move.speed.name.toUpperCase()}"));
      commands.add(BluetoothMessage.response("DSSP ${move.leftServo.round().clamp(0, 128)} ${move.rightServo.round().clamp(0, 128)} 000 000", device, Priority.normal, "DSSP END"));
    } else {
      //cmd = "DSSP"; //TODO: Tail command
      commands.add(BluetoothMessage.response("DSSP E${move.easingType.num} F${move.easingType.num} A${move.leftServo.round().clamp(0, 128) ~/ 16} B${move.rightServo.round().clamp(0, 128) ~/ 16} L${move.speed.speed} M${move.speed.speed}", device, Priority.normal, "OK"));
    }
  }
  return commands;
}
