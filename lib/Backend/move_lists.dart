import 'package:built_collection/built_collection.dart';
import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../Frontend/translation_string_definitions.dart';
import '../constants.dart';
import 'Bluetooth/bluetooth_message.dart';
import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/device_definition.dart';
import 'audio.dart';
import 'logging_wrappers.dart';
import 'plausible_dio.dart';

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
        return Icons.home;
    }
  }
}

@HiveType(typeId: 5)
class Move {
  //Range 0-127
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

  Move.move({this.leftServo = 0, this.rightServo = 0, this.speed = 50, this.easingType = EasingType.linear, this.moveType = MoveType.move});

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

@Riverpod(keepAlive: true)
class MoveLists extends _$MoveLists {
  @override
  BuiltList<MoveList> build() {
    List<MoveList> results = [];
    try {
      results = HiveProxy.getAll<MoveList>(sequencesBox).toList(growable: true);
    } catch (e, s) {
      sequencesLogger.severe("Unable to load sequences: $e", e, s);
    }
    return results.toBuiltList();
  }

  Future<void> add(MoveList moveList) async {
    state = state.rebuild(
      (p0) => p0.add(moveList),
    );
    await store();
  }

  Future<void> replace(MoveList oldValue, MoveList newValue) async {
    state = state.rebuild(
      (p0) {
        int index = state.indexOf(oldValue);
        p0
          ..removeAt(index)
          ..insert(index, newValue);
      },
    );
    await store();
  }

  Future<void> remove(MoveList moveList) async {
    state = state.rebuild(
      (p0) => p0.remove(moveList),
    );
    await store();
  }

  Future<void> store() async {
    sequencesLogger.info("Storing sequences");
    await HiveProxy.clear<MoveList>(sequencesBox);
    await HiveProxy.addAll<MoveList>(sequencesBox, state);
  }
}

Future<void> runAction(BaseAction action, BaseStatefulDevice device) async {
  //cursed handling of ears specifically
  if (action is EarsMoveList) {
    plausible.event(name: "Run Action", props: {"Action Name": action.name, "Action Type": action.actionCategory.name});
    if (action.commandMoves.isNotEmpty && device.baseDeviceDefinition.deviceType == DeviceType.ears) {
      EarSpeed earSpeed = HiveProxy.getOrDefault(settings, earMoveSpeed, defaultValue: earMoveSpeedDefault);
      BluetoothMessage speedMsg = BluetoothMessage(message: earSpeed.command, device: device, priority: Priority.normal, type: CommandType.move, responseMSG: earSpeed.command, timestamp: DateTime.now());
      device.commandQueue.addCommand(speedMsg);
      BluetoothMessage delayMessage = BluetoothMessage(delay: 1, device: device, priority: Priority.normal, type: CommandType.move, message: '', timestamp: DateTime.now());
      device.commandQueue.addCommand(delayMessage);
      for (int i = 0; i < action.commandMoves.length; i++) {
        Object element = action.commandMoves[i];
        if (element is Move) {
          if (element.moveType == MoveType.delay) {
            BluetoothMessage message = BluetoothMessage(delay: element.time, device: device, priority: Priority.normal, type: CommandType.move, message: '', timestamp: DateTime.now());
            device.commandQueue.addCommand(message);
          }
        } else if (element is CommandAction) {
          //Generate move command
          BluetoothMessage message = BluetoothMessage(message: element.command, device: device, priority: Priority.normal, type: CommandType.move, responseMSG: element.response, timestamp: DateTime.now());
          device.commandQueue.addCommand(message);
        }
      }
    }
  } else if (action is CommandAction) {
    device.commandQueue.addCommand(BluetoothMessage(message: action.command, device: device, priority: Priority.normal, responseMSG: action.response, type: CommandType.move, timestamp: DateTime.now()));
    plausible.event(name: "Run Action", props: {"Action Name": action.name, "Action Type": action.actionCategory.name});
  } else if (action is MoveList) {
    sequencesLogger.info("Starting MoveList ${action.name}.");
    plausible.event(name: "Run Sequence", props: {"Sequence Repeat": action.repeat.toInt().toString(), "Sequence Device Type": device.baseDeviceDefinition.deviceType.name, "Sequence Moves": action.moves.length.toString()});
    if (action.moves.isNotEmpty && action.moves.length <= 5 && device.baseDeviceDefinition.deviceType != DeviceType.ears) {
      int preset = 1; //TODO: store
      String cmd = "USERMOVE U${preset}P${action.moves.length}N${action.repeat.toInt() - 1}";
      String a = '';
      String b = '';
      String e = '';
      String f = '';
      String sl = '';
      String m = '';
      for (int i = 0; i < action.moves.length; i++) {
        Move move = action.moves[i];
        if (i == 0 && move.moveType == MoveType.delay) {
          continue; // Skip first move if it is a delay
        }
        if (move.moveType == MoveType.delay) {
          if (i > 0 && action.moves[i + 1].moveType == MoveType.move) {
            Move prevMove = action.moves[i + 1];
            e = '${e}E${prevMove.easingType.num}';
            f = '${f}F${prevMove.easingType.num}';
            a = '${a}A${prevMove.leftServo.round().clamp(0, 128) ~/ 16}';
            b = '${b}B${prevMove.rightServo.round().clamp(0, 128) ~/ 16}';
            sl = '${sl}S${move.speed.toInt()}';
            m = '${m}M${move.speed.toInt()}';
          }
        }
        e = '${e}E${move.easingType.num}';
        f = '${f}F${move.easingType.num}';
        a = '${a}A${move.leftServo.round().clamp(0, 128) ~/ 16}';
        b = '${b}B${move.rightServo.round().clamp(0, 128) ~/ 16}';
        sl = '${sl}L${move.speed.toInt()}';
        m = '${m}M${move.speed.toInt()}';
      }
      cmd = '$cmd $a $b $e $f $sl H1';
      device.commandQueue.addCommand(BluetoothMessage(message: cmd, device: device, priority: Priority.normal, type: CommandType.move, timestamp: DateTime.now()));
      device.commandQueue.addCommand(BluetoothMessage(message: "TAILU$preset", device: device, priority: Priority.normal, responseMSG: "TAILU$preset END", type: CommandType.move, timestamp: DateTime.now()));
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
          BluetoothMessage message = BluetoothMessage(delay: element.time, device: device, priority: Priority.normal, type: CommandType.move, message: '', timestamp: DateTime.now());
          device.commandQueue.addCommand(message);
        } else {
          //Generate move command
          generateMoveCommand(element, device, CommandType.move).forEach(
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

List<BluetoothMessage> generateMoveCommand(Move move, BaseStatefulDevice device, CommandType type, {bool noResponseMsg = false, Priority priority = Priority.normal}) {
  List<BluetoothMessage> commands = [];
  if (move.moveType == MoveType.home) {
    if (device.baseDeviceDefinition.deviceType == DeviceType.ears) {
      commands.add(BluetoothMessage(message: "EARHOME", device: device, priority: priority, responseMSG: noResponseMsg ? null : "EARHOME END", type: type, timestamp: DateTime.now()));
    } else {
      commands.add(BluetoothMessage(message: "TAILHM", device: device, priority: priority, responseMSG: noResponseMsg ? null : "END TAILHM", type: type, timestamp: DateTime.now()));
    }
  } else if (move.moveType == MoveType.move) {
    if (device.baseDeviceDefinition.deviceType == DeviceType.ears) {
      commands
        ..add(
          BluetoothMessage(
            message: move.speed > 60 ? EarSpeed.fast.command : EarSpeed.slow.command,
            device: device,
            priority: priority,
            responseMSG: noResponseMsg
                ? null
                : move.speed > 60
                    ? EarSpeed.fast.command
                    : EarSpeed.slow.command,
            type: type,
            timestamp: DateTime.now(),
          ),
        )
        ..add(BluetoothMessage(message: "DSSP ${move.leftServo.round().clamp(0, 128)} ${move.rightServo.round().clamp(0, 128)} 000 000", device: device, priority: priority, responseMSG: noResponseMsg ? null : "DSSP END", type: CommandType.move, timestamp: DateTime.now()));
    } else {
      commands.add(
        BluetoothMessage(
          message: "DSSP E${move.easingType.num} F${move.easingType.num} A${move.leftServo.round().clamp(0, 128) ~/ 16} B${move.rightServo.round().clamp(0, 128) ~/ 16} L${move.speed.toInt()} M${move.speed.toInt()}",
          device: device,
          priority: priority,
          responseMSG: noResponseMsg ? null : "OK",
          type: type,
          timestamp: DateTime.now(),
        ),
      );
    }
  }
  return commands;
}
