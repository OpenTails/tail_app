import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_wear_os_connectivity/flutter_wear_os_connectivity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/sensors.dart';

import 'Bluetooth/bluetooth_manager.dart';
import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/device_definition.dart';
import 'action_registry.dart';
import 'move_lists.dart';

part 'wear_bridge.g.dart';

FlutterWearOsConnectivity _flutterWearOsConnectivity = FlutterWearOsConnectivity();

@Riverpod(keepAlive: true)
Future<void> initWear(InitWearRef ref) async {
  _flutterWearOsConnectivity.configureWearableAPI();
  //List<WearOsDevice> _connectedDevices = await _flutterWearOsConnectivity.getConnectedDevices();
  _flutterWearOsConnectivity.dataChanged(pathURI: Uri(scheme: "wear", host: "*", path: "/triggerMove")).expand((element) => element).listen(
    (dataEvent) {
      Map<String, dynamic> mapData = dataEvent.dataItem.mapData;
      bool containsKey = mapData.containsKey("uuid");
      if (containsKey) {
        String uuid = mapData["uuid"];
        BaseAction? action = ref.read(getActionFromUUIDProvider(uuid));
        if (action != null) {
          Iterable<BaseStatefulDevice> knownDevices =
              ref.read(knownDevicesProvider).values.where((element) => action.deviceCategory.contains(element.baseDeviceDefinition.deviceType)).where((element) => element.deviceConnectionState.value == ConnectivityState.connected).where((element) => element.deviceState.value == DeviceState.standby);
          for (BaseStatefulDevice device in knownDevices) {
            runAction(action, device);
          }
        }
      }
    },
  );
  updateWearActions(ref.read(favoriteActionsProvider), ref);
}

Future<void> updateWearActions(List<FavoriteAction> favoriteActions, Ref ref) async {
  Iterable<BaseAction> allActions = favoriteActions.map(
    (e) => ref.read(getActionFromUUIDProvider(e.actionUUID)) as BaseAction,
  );
  Map<String, String> favoriteMap = Map.fromEntries(allActions.map((e) => MapEntry(e.uuid, e.name)));
  DataItem? _dataItem = await _flutterWearOsConnectivity.syncData(
      path: "/actions",
      data: Map.fromEntries(
        [
          MapEntry("actions", favoriteMap.values.toList()),
          MapEntry("uuid", favoriteMap.keys.toList()),
        ],
      ),
      isUrgent: false);
}
