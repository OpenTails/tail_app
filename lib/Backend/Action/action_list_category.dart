import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tail_app/Backend/Action/base_action.dart';

part 'action_list_category.freezed.dart';

@freezed
abstract class ActionListCategory with _$ActionListCategory {
  ActionListCategory._();

  factory ActionListCategory({
    required Function translated,
    required String name,
    required Set<BaseAction> actions,
    @Default(true) bool isAvailable,
  }) = _ActionListCategory;
}
