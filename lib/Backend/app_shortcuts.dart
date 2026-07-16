import 'package:quick_actions/quick_actions.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:synchronized/synchronized.dart';
import 'package:tail_app/Backend/Device/command/command_runner.dart';
import 'package:tail_app/Backend/analytics.dart';

import '../Frontend/utils.dart';
import 'Action/action_registry.dart';
import 'Action/base_action.dart';
import 'favorite_actions.dart';

const QuickActions quickActions = QuickActions();
Lock _shortcutsLock = Lock();
bool _didInitShortcuts = false;

Future<void> appShortcuts() async {
  if (!isMobile) {
    return;
  }
  final ISentrySpan? span = Sentry.getSpan()?.startChild('AppShortcuts.init');
  _shortcutsLock.synchronized(() async {
    if (_didInitShortcuts) {
      return;
    }
    await quickActions.initialize((shortcutType) {
      BaseAction? action = ActionRegistry.getActionFromUUID(shortcutType);
      if (action != null) {
        runActionOnAllSupportedGear(action, triggeredBy: "App Shortcut");
        analyticsEvent(name: "Use App Shortcut");
      }
      _didInitShortcuts = true;
    });
  });
  span?.finish();
}

Future<void> updateShortcuts(Iterable<FavoriteAction> favoriteActions) async {
  if (!isMobile) {
    return;
  }
  final ISentrySpan? span = Sentry.getSpan()?.startChild('AppShortcuts.update');
  await appShortcuts();
  Iterable<BaseAction> allActions = favoriteActions
      .map((e) => ActionRegistry.getActionFromUUID(e.actionUUID))
      .nonNulls;

  await quickActions.setShortcutItems(
    allActions
        .map((e) => ShortcutItem(type: e.uuid, localizedTitle: e.name))
        .toList(),
  );
  span?.finish();
}
