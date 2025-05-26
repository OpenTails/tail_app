import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/device_definition.dart';
import 'action_registry.dart';
import 'device_registry.dart';
import 'favorite_actions.dart';
import 'move_lists.dart';

part 'app_shortcuts.g.dart';

const QuickActions quickActions = QuickActions();

@Riverpod(keepAlive: true)
Future<void> appShortcuts(Ref ref) async {
  if (kIsWeb) {
    return;
  }
  await Future.delayed(const Duration(seconds: 5));
  quickActions.initialize((shortcutType) {
    BaseAction? action = ref.read(getActionFromUUIDProvider(shortcutType));
    if (action != null) {
      Iterable<BaseStatefulDevice> knownDevices = ref.read(getAvailableIdleGearProvider);
      for (BaseStatefulDevice device in knownDevices) {
        ref.read(runActionProvider(action, device));
      }
    }
  });
  updateShortcuts(ref.read(favoriteActionsProvider), ref);
}

Future<void> updateShortcuts(BuiltList<FavoriteAction> favoriteActions, Ref ref) async {
  if (kIsWeb){
    return;
  }
  Iterable<BaseAction> allActions = favoriteActions
      .map(
        (e) => ref.read(getActionFromUUIDProvider(e.actionUUID)),
      )
      .nonNulls;

  quickActions.setShortcutItems(
    allActions
        .map(
          (e) => ShortcutItem(type: e.uuid, localizedTitle: e.name),
        )
        .toList(),
  );
}
