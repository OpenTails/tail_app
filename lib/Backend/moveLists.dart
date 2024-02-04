import 'dart:convert';

import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/Bluetooth/btMessage.dart';
import 'package:tail_app/Backend/Definitions/Action/BaseAction.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';
import 'package:tail_app/Frontend/intnDefs.dart';

import '../main.dart';

part 'moveLists.g.dart';

enum EasingType { linear, cubic }

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

  int get index {
    switch (this) {
      case EasingType.linear:
        return 0;
      case EasingType.cubic:
        return 2;
    }
  }
}

enum MoveTimeType { sleep, linear }

enum Speed { slow, fast }

extension SpeedExtension on Speed {
  String get name {
    switch (this) {
      case Speed.slow:
        return sequencesEditSpeedSlow();
      case Speed.fast:
        return sequencesEditSpeedFast();
    }
  }
}

enum MoveType { move, delay, home }

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

@JsonSerializable(explicitToJson: true)
class Move {
  //Range 0-180
  double leftServo = 0;

  //Range 0-180
  double rightServo = 0;
  Speed speed = Speed.fast;
  double time = 1;
  EasingType easingType = EasingType.linear;
  MoveType moveType = MoveType.move;

  factory Move.fromJson(Map<String, dynamic> json) => _$MoveFromJson(json);

  Map<String, dynamic> toJson() => _$MoveToJson(this);

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

@JsonSerializable(explicitToJson: true)
class MoveList extends BaseAction {
  List<Move> moves = [];
  bool homeAtEnd = true;

  factory MoveList.fromJson(Map<String, dynamic> json) => _$MoveListFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$MoveListToJson(this);

  MoveList(super.name, super.deviceCategory, super.actionCategory) {
    super.actionCategory = ActionCategory.sequence;
  }
}

@Riverpod(keepAlive: true)
class MoveLists extends _$MoveLists {
  @override
  List<MoveList> build() {
    List<String>? stringList = prefs.getStringList("sequences");
    if (stringList != null) {
      return stringList.map((e) => MoveList.fromJson(jsonDecode(e))).toList();
    }
    return [];
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
    await prefs.setStringList(
        "sequences",
        state.map(
          (e) {
            return const JsonEncoder.withIndent("    ").convert(e.toJson());
          },
        ).toList());
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
    }
  }
  return commands;
}
