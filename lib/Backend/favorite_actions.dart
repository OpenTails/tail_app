import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';

import '../constants.dart';
import 'Definitions/Action/base_action.dart';
import 'app_shortcuts.dart';
import 'logging_wrappers.dart';

part 'favorite_actions.freezed.dart';

part 'favorite_actions.g.dart';

final _favoriteActionsLogger = Logger('Favorites');

@HiveType(typeId: 13)
@freezed
abstract class FavoriteAction with _$FavoriteAction implements Comparable<FavoriteAction> {
  const FavoriteAction._();

  @Implements<Comparable<FavoriteAction>>()
  const factory FavoriteAction({@HiveField(1) required String actionUUID, @HiveField(2) required int id}) = _FavoriteAction;

  @override
  int compareTo(other) {
    id.compareTo(other.id);
    return 0;
  }
}

class FavoriteActions with ChangeNotifier {
  BuiltList<FavoriteAction> _state = BuiltList();
  BuiltList<FavoriteAction> get state => _state;

  static final FavoriteActions instance = FavoriteActions._internal();

  FavoriteActions._internal() {
    List<FavoriteAction> results = [];
    try {
      results = HiveProxy.getAll<FavoriteAction>(favoriteActionsBox).toList(growable: true);
    } catch (e, s) {
      _favoriteActionsLogger.severe("Unable to load favorites: $e", e, s);
    }
    _state = results.toBuiltList();
  }

  Future<void> add(BaseAction action) async {
    _state = _state.rebuild((p0) {
      p0
        ..add(FavoriteAction(actionUUID: action.uuid, id: _state.length + 1))
        ..sort();
    });
    await store();
  }

  Future<void> remove(BaseAction action) async {
    _state = _state.rebuild((p0) => p0.removeWhere((element) => element.actionUUID == action.uuid));
    await store();
  }

  bool contains(BaseAction action) {
    return _state.any((element) => element.actionUUID == action.uuid);
  }

  Future<void> store() async {
    _favoriteActionsLogger.info("Storing favorites");
    await HiveProxy.clear<FavoriteAction>(favoriteActionsBox);
    await HiveProxy.addAll<FavoriteAction>(favoriteActionsBox, _state);
    updateShortcuts(_state);
    // ignore: unused_result
    notifyListeners();
  }
}
