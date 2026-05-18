import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sensor_definition_action_definition.freezed.dart';

@freezed
abstract class TriggerActionDef with _$TriggerActionDef {
  //Store in trigger def instance
  const factory TriggerActionDef({
    required String name,
    required Function translated,
    Widget? icon,
    required String uuid,
    @Default(false) final bool defaultActions,
  }) = _TriggerActionDef;
}
