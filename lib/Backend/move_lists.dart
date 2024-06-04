import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_message.dart';
import 'package:tail_app/Backend/Definitions/Action/base_action.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/audio.dart';
import 'package:tail_app/Frontend/translation_string_definitions.dart';

import '../main.dart';
import 'LoggingWrappers.dart';

part 'move_lists.g.dart';

final sequencesLogger = Logger('Sequences');

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

enum Speed {
  slow,
  fast,
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

  //Range 0-127
  @HiveField(2)
  double rightServo = 0;

  //Range 0-127
  @HiveField(3)
  double speed = 50;

  @HiveField(4)
  //Range 0-127
  double time = 1;
  @HiveField(5, defaultValue: EasingType.linear)
  EasingType easingType = EasingType.linear;
  @HiveField(6, defaultValue: MoveType.move)
  MoveType moveType = MoveType.move;

  Move();

  Move.move(this.leftServo, this.rightServo, this.speed, this.easingType);

  Move.delay(this.time) {
    moveType = MoveType.delay;
  }

  Move.home() {
    moveType = MoveType.home;
  }

  @override
  String toString() {
    switch (moveType) {
      case MoveType.move:
        return '${sequencesEditLeftServo()} ${leftServo.round().clamp(0, 128) ~/ 16} | ${sequencesEditRightServo()} ${rightServo.round().clamp(0, 128) ~/ 16} | ${sequencesEditSpeed()} ${speed.toInt() * 20}ms';
      case MoveType.delay:
        return sequenceEditListDelayLabel(time.toInt() * 20);
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
  double repeat = 1;

  MoveList({required super.name, required super.deviceCategory, super.actionCategory = ActionCategory.sequence, required super.uuid, this.moves = const []}) {
    if (moves.isEmpty) {
      moves = [];
    }
  }
}

class EarsMoveList extends MoveList {
  List<Object> commandMoves = [];

  EarsMoveList({required super.name, super.deviceCategory = const [DeviceType.ears], required super.uuid, super.actionCategory = ActionCategory.ears, required this.commandMoves});
}

@Riverpod(keepAlive: true)
class MoveLists extends _$MoveLists {
  @override
  List<MoveList> build() {
    List<MoveList> results = [];
    try {
      results = HiveProxy.getAll<MoveList>('sequences').toList(growable: true);
    } catch (e, s) {
      sequencesLogger.severe("Unable to load sequences: $e", e, s);
    }
    return results;
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
    sequencesLogger.info("Storing sequences");
    HiveProxy.clear<MoveList>('sequences');
    HiveProxy.addAll<MoveList>('sequences', state);
  }
}

Future<void> runAction(BaseAction action, BaseStatefulDevice device) async {
  //cursed handling of ears specifically
  if (action is EarsMoveList) {
    plausible.event(name: "Run Action", props: {"Action Name": action.name, "Action Type": action.actionCategory.name});
    if (action.commandMoves.isNotEmpty && device.baseDeviceDefinition.deviceType == DeviceType.ears) {
      for (int i = 0; i < action.commandMoves.length; i++) {
        Object element = action.commandMoves[i];
        if (element is Move) {
          if (element.moveType == MoveType.delay) {
            BluetoothMessage message = BluetoothMessage.delay(delay: element.time, device: device, priority: Priority.normal, type: Type.move);
            device.commandQueue.addCommand(message);
          }
        } else if (element is CommandAction) {
          //Generate move command
          BluetoothMessage message = BluetoothMessage(message: element.command, device: device, priority: Priority.normal, type: Type.move, responseMSG: element.response);
          device.commandQueue.addCommand(message);
        }
      }
    }
  } else if (action is CommandAction) {
    device.commandQueue.addCommand(BluetoothMessage(message: action.command, device: device, priority: Priority.normal, responseMSG: action.response, type: Type.move));
    plausible.event(name: "Run Action", props: {"Action Name": action.name, "Action Type": action.actionCategory.name});
  } else if (action is MoveList) {
    sequencesLogger.info("Starting MoveList ${action.name}.");
    plausible.event(name: "Run Sequence", props: {"Sequence Repeat": action.repeat.toInt().toString(), "Sequence Device Type": device.baseDeviceDefinition.deviceType.name, "Sequence Moves": action.moves.length.toString()});
    if (action.moves.isNotEmpty && action.moves.length <= 5 && device.baseDeviceDefinition.deviceType != DeviceType.ears) {
      int preset = 1; //TODO: store
      String cmd = "USERMOVE U${preset}P${action.moves.length}N${action.repeat.toInt()}H1";
      for (int i = 0; i < action.moves.length; i++) {
        Move move = action.moves[i];
        if (i == 0 && move.moveType == MoveType.delay) {
          continue; // Skip first move if it is a delay
        }
        if (move.moveType == MoveType.delay) {
          if (i > 0 && action.moves[i + 1].moveType == MoveType.move) {
            Move prevMove = action.moves[i + 1];
            cmd = "$cmd E${prevMove.easingType.num}F${prevMove.easingType.num}A${prevMove.leftServo.round().clamp(0, 128) ~/ 16}B${prevMove.rightServo.round().clamp(0, 128) ~/ 16}S${move.time.toInt()}";
          }
        }
        cmd = "$cmd E${move.easingType.num}F${move.easingType.num}A${move.leftServo.round().clamp(0, 128) ~/ 16}B${move.rightServo.round().clamp(0, 128) ~/ 16}L${move.speed.toInt()}";
      }
      device.commandQueue.addCommand(BluetoothMessage(message: cmd, device: device, priority: Priority.normal, type: Type.move));
      device.commandQueue.addCommand(BluetoothMessage(message: "TAILU$preset", device: device, priority: Priority.normal, responseMSG: "TAILU$preset END", type: Type.move));
    } else {
      List<Move> newMoveList = List.from(action.moves); //prevent home move from being added to original MoveList
      if (action.repeat.toInt() > 1) {
        for (int i = 1; i < action.repeat; i++) {
          newMoveList.addAll(action.moves);
        }
      }
      newMoveList.add(Move.home()); // add final home move
      for (Move element in newMoveList) {
        //run move command
        if (element.moveType == MoveType.delay) {
          BluetoothMessage message = BluetoothMessage.delay(delay: element.time, device: device, priority: Priority.normal, type: Type.move);
          device.commandQueue.addCommand(message);
        } else {
          //Generate move command
          generateMoveCommand(element, device, Type.move).forEach(
            (element) {
              device.commandQueue.addCommand(element);
            },
          );
        }
      }
    }
  } else if (action is AudioAction) {
    String file = action.file;

    playSound(file);
  }
}

List<BluetoothMessage> generateMoveCommand(Move move, BaseStatefulDevice device, Type type) {
  List<BluetoothMessage> commands = [];
  if (move.moveType == MoveType.home) {
    if (device.baseDeviceDefinition.deviceType == DeviceType.ears) {
      commands.add(BluetoothMessage(message: "EARHOME", device: device, priority: Priority.normal, responseMSG: "EARHOME END", type: type));
    } else {
      commands.add(BluetoothMessage(message: "TAILHM", device: device, priority: Priority.normal, responseMSG: "END TAILHM", type: type));
    }
  } else if (move.moveType == MoveType.move) {
    if (device.baseDeviceDefinition.deviceType == DeviceType.ears) {
      commands.add(BluetoothMessage(message: "SPEED ${move.speed > 60 ? Speed.fast.name.toUpperCase() : Speed.slow.name.toUpperCase()}", device: device, priority: Priority.normal, responseMSG: "SPEED ${move.speed > 60 ? Speed.fast.name.toUpperCase() : Speed.slow.name.toUpperCase()}", type: type));
      commands.add(BluetoothMessage(message: "DSSP ${move.leftServo.round().clamp(0, 128)} ${move.rightServo.round().clamp(0, 128)} 000 000", device: device, priority: Priority.normal, responseMSG: "DSSP END", type: Type.move));
    } else {
      commands.add(BluetoothMessage(
          message: "DSSP E${move.easingType.num} F${move.easingType.num} A${move.leftServo.round().clamp(0, 128) ~/ 16} B${move.rightServo.round().clamp(0, 128) ~/ 16} L${move.speed.toInt()} M${move.speed.toInt()}", device: device, priority: Priority.normal, responseMSG: "OK", type: type));
    }
  }
  return commands;
}
