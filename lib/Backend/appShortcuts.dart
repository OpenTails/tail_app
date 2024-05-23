import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Definitions/Action/base_action.dart';
import 'package:tail_app/Backend/action_registry.dart';
import 'package:tail_app/Backend/move_lists.dart';
import 'package:tail_app/Backend/sensors.dart';

import 'Definitions/Device/device_definition.dart';

part 'appShortcuts.g.dart';

const QuickActions quickActions = QuickActions();

@Riverpod(keepAlive: true)
Future<void> appShortcuts(AppShortcutsRef ref) async {
  quickActions.initialize((shortcutType) {
    BaseAction? action = ref.read(getActionFromUUIDProvider(shortcutType));
    if (action != null) {
      Iterable<BaseStatefulDevice> knownDevices =
          ref.read(knownDevicesProvider).values.where((element) => action.deviceCategory.contains(element.baseDeviceDefinition.deviceType)).where((element) => element.deviceConnectionState.value == ConnectivityState.connected).where((element) => element.deviceState.value == DeviceState.standby);
      for (BaseStatefulDevice device in knownDevices) {
        runAction(action, device);
      }
    }
  });
  updateShortcuts(ref);
}

Future<void> updateShortcuts(Ref ref) async {
  Iterable<BaseAction> allActions = ref.read(favoriteActionsProvider).map(
        (e) => ref.read(getActionFromUUIDProvider(e.actionUUID)) as BaseAction,
      );

  quickActions.setShortcutItems(allActions
      .map(
        (e) => ShortcutItem(type: e.uuid, localizedTitle: e.name),
      )
      .toList());
}
