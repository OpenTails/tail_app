import 'package:built_collection/built_collection.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:synchronized/synchronized.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/command_runner.dart';

import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/device_definition.dart';
import 'action_registry.dart';
import 'favorite_actions.dart';

const QuickActions quickActions = QuickActions();
Lock _shortcutsLock = Lock();
bool _didInitShortcuts = false;
Future<void> appShortcuts() async {
  _shortcutsLock.synchronized(() async {
    if (_didInitShortcuts) {
      return;
    }
    await quickActions.initialize((shortcutType) {
      BaseAction? action = ActionRegistry.getActionFromUUID(shortcutType);
      if (action != null) {
        Iterable<BaseStatefulDevice> knownDevices = KnownDevices.instance.connectedIdleGear;
        for (BaseStatefulDevice device in knownDevices) {
          runAction(device, action, triggeredBy: "App Shortcut");
        }
        analyticsEvent(name: "Use App Shortcut");
      }
      _didInitShortcuts = true;
    });
  });
}

Future<void> updateShortcuts(BuiltList<FavoriteAction> favoriteActions) async {
  appShortcuts();
  Iterable<BaseAction> allActions = favoriteActions.map((e) => ActionRegistry.getActionFromUUID(e.actionUUID)).nonNulls;

  quickActions.setShortcutItems(allActions.map((e) => ShortcutItem(type: e.uuid, localizedTitle: e.name)).toList());
}
