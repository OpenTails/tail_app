import 'package:built_collection/built_collection.dart';
import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../Frontend/translation_string_definitions.dart';
import '../constants.dart';
import 'Definitions/Action/base_action.dart';
import 'logging_wrappers.dart';

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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Move &&
          runtimeType == other.runtimeType &&
          leftServo == other.leftServo &&
          rightServo == other.rightServo &&
          speed == other.speed &&
          time == other.time &&
          easingType == other.easingType &&
          moveType == other.moveType;

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

