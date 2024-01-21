import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';
import 'package:tail_app/Backend/btMessage.dart';

import '../main.dart';

part 'moveLists.g.dart';

enum EasingType { linear, quadratic, cubic, quartic }

enum MoveTimeType { sleep, linear }

enum Speed { slow, fast }

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
        return 'Left ${leftServo.round()} | Right ${rightServo.round()} | Speed ${speed.name}';
      case MoveType.delay:
        return 'Delay next move for $time seconds';
      case MoveType.home:
        return 'Home Gear';
    }
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Move && runtimeType == other.runtimeType && leftServo == other.leftServo && rightServo == other.rightServo && speed == other.speed && time == other.time && easingType == other.easingType && moveType == other.moveType;

  @override
  int get hashCode => leftServo.hashCode ^ rightServo.hashCode ^ speed.hashCode ^ time.hashCode ^ easingType.hashCode ^ moveType.hashCode;
}

@JsonSerializable(explicitToJson: true)
class MoveList {
  List<Move> moves = [];
  String name = "New List";
  bool homeAtEnd = true;

  factory MoveList.fromJson(Map<String, dynamic> json) => _$MoveListFromJson(json);

  Map<String, dynamic> toJson() => _$MoveListToJson(this);

  MoveList();
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

  void add(MoveList moveList) => state.add(moveList);

  void remove(MoveList moveList) => state.remove(moveList);

  Future<void> store() async {
    Flogger.i("Storing sequences");
    await prefs.setStringList(
        "sequences",
        state.map((e) {
          return jsonEncode(e.toJson());
        }).toList());
  }
}

Future<void> runMove(MoveList moveList, BaseStatefulDevice device) async {
  Flogger.i("Starting MoveList ${moveList.name}.");
  // add final home move
  List<Move> newMoveList = List.from(moveList.moves); //prevent home move from being added to original MoveList
  if (moveList.homeAtEnd) {
    Move move = Move();
    move.moveType = MoveType.home;
    newMoveList.add(move);
  }
  //TODO: Merge move commands into 1 large command
  for (Move element in newMoveList) {
    //run move command
    if (element.moveType == MoveType.delay) {
      BluetoothMessage message = BluetoothMessage.delay(element.time, device, Priority.normal);
      device.commandQueue.addCommand(message);
    } else {
      //Generate move command
      String command = generateMoveCommand(element, device.baseDeviceDefinition.deviceType);
      BluetoothMessage message = BluetoothMessage(command, device, Priority.normal);
      device.commandQueue.addCommand(message);
    }
  }
}

String generateMoveCommand(Move move, DeviceType deviceType) {
  String cmd = "";
  if (move.moveType == MoveType.home) {
    if (deviceType == DeviceType.ears) {
      cmd = "EARHOME";
    } else {
      cmd = "TAILHM";
    }
  } else if (move.moveType == MoveType.move) {
    if (deviceType == DeviceType.ears) {
      cmd = "SPEED ${move.speed.name.toUpperCase()}\nDSSP ${move.leftServo.round().clamp(0, 128)} ${move.rightServo.round().clamp(0, 128)} 000 000";
    } else {
      cmd = "DSSP";
    }
  }
  return cmd;
}
