import 'package:hive_ce/hive.dart';

import '../../../Frontend/translation_string_definitions.dart';

@HiveType(typeId: 7)
enum ActionCategory {
  @HiveField(1)
  sequence,
  @HiveField(5)
  glowtip,
  @HiveField(7)
  hidden, // used as a sub-action for legacy ear moves
  @HiveField(8)
  audio,
  @HiveField(9)
  rgb,
}

extension ActionCategoryExtension on ActionCategory {
  String get friendly {
    switch (this) {
      case ActionCategory.glowtip:
        return actionsCategoryGlowtip();
      case ActionCategory.rgb:
        return actionsCategoryRGB();
      case ActionCategory.sequence:
        return sequencesPage();
      case ActionCategory.hidden:
        return "";
      case ActionCategory.audio:
        return audioActionCategory();
    }
  }
}
