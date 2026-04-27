import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import '../../../Frontend/translation_string_definitions.dart';

part 'ear_speed_enum.g.dart';

@HiveType(typeId: 14)
enum EarSpeed {
  @HiveField(1)
  fast,
  @HiveField(2)
  slow,
}

extension EarSpeedExtension on EarSpeed {
  String get name {
    switch (this) {
      case EarSpeed.fast:
        return earSpeedFast();
      case EarSpeed.slow:
        return earSpeedSlow();
    }
  }

  Widget get icon {
    switch (this) {
      case EarSpeed.fast:
        return const Icon(Icons.fast_forward);
      case EarSpeed.slow:
        return const Icon(Icons.play_arrow);
    }
  }

  String get command {
    switch (this) {
      case EarSpeed.fast:
        return "SPEED FAST";
      case EarSpeed.slow:
        return "SPEED SLOW";
    }
  }
}
