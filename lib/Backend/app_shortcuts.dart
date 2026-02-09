import 'package:built_collection/built_collection.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/command_runner.dart';

import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/device_definition.dart';
import 'action_registry.dart';
import 'favorite_actions.dart';

part 'app_shortcuts.g.dart';

const QuickActions quickActions = QuickActions();

@Riverpod(keepAlive: true)
Future<void> appShortcuts(Ref ref) async {
  await Future.delayed(const Duration(seconds: 5));
  await quickActions.initialize((shortcutType) {
    BaseAction? action = ActionRegistry.getActionFromUUID(shortcutType);
    if (action != null) {
      Iterable<BaseStatefulDevice> knownDevices = KnownDevices.instance.connectedIdleGear;
      for (BaseStatefulDevice device in knownDevices) {
        runAction(device,action, triggeredBy: "App Shortcut");
      }
      analyticsEvent(name: "Use App Shortcut");
    }
  });
  await updateShortcuts(FavoriteActions.instance.state);
}

Future<void> updateShortcuts(BuiltList<FavoriteAction> favoriteActions) async {
  Iterable<BaseAction> allActions = favoriteActions.map((e) => ActionRegistry.getActionFromUUID(e.actionUUID)).nonNulls;

  quickActions.setShortcutItems(allActions.map((e) => ShortcutItem(type: e.uuid, localizedTitle: e.name)).toList());
}
