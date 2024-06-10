import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/wear_bridge.dart';

import '../constants.dart';
import 'Definitions/Action/base_action.dart';
import 'logging_wrappers.dart';
import 'app_shortcuts.dart';

part 'favorite_actions.g.dart';

final _favoriteActionsLogger = Logger('Favorites');

@HiveType(typeId: 13)
class FavoriteAction implements Comparable<FavoriteAction> {
  @HiveField(1)
  String actionUUID;
  @HiveField(2)
  int id;

  FavoriteAction({required this.actionUUID, required this.id});

  @override
  int compareTo(other) {
    id.compareTo(other.id);
    return 0;
  }
}

@Riverpod(keepAlive: true)
class FavoriteActions extends _$FavoriteActions {
  @override
  List<FavoriteAction> build() {
    List<FavoriteAction> results = [];
    try {
      results = HiveProxy.getAll<FavoriteAction>(favoriteActionsBox).toList(growable: true);
    } catch (e, s) {
      _favoriteActionsLogger.severe("Unable to load favorites: $e", e, s);
    }
    return results;
  }

  Future<void> add(BaseAction action) async {
    state.add(FavoriteAction(actionUUID: action.uuid, id: state.length + 1));
    state.sort();
    await store();
  }

  Future<void> remove(BaseAction action) async {
    state.removeWhere((element) => element.actionUUID == action.uuid);
    await store();
  }

  bool contains(BaseAction action) {
    return state.any((element) => element.actionUUID == action.uuid);
  }

  Future<void> store() async {
    _favoriteActionsLogger.info("Storing favorites");
    await HiveProxy.clear<FavoriteAction>(favoriteActionsBox);
    await HiveProxy.addAll<FavoriteAction>(favoriteActionsBox, state);
    updateShortcuts(state, ref);
    updateWearActions(state, ref);
  }
}
