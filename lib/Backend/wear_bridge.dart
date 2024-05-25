import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_wear_os_connectivity/flutter_wear_os_connectivity.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/sensors.dart';

import 'Bluetooth/bluetooth_manager.dart';
import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/device_definition.dart';
import 'action_registry.dart';
import 'move_lists.dart';

part 'wear_bridge.g.dart';

final Logger _wearLogger = Logger('Wear');
FlutterWearOsConnectivity _flutterWearOsConnectivity = FlutterWearOsConnectivity();

@Riverpod(keepAlive: true)
Future<void> initWear(InitWearRef ref) async {
  _flutterWearOsConnectivity.configureWearableAPI();
  _flutterWearOsConnectivity
      .getConnectedDevices()
      .asStream()
      .expand(
        (element) => element,
      )
      .listen((event) => _wearLogger.info("Connected Wear Device$event"));
  _flutterWearOsConnectivity.dataChanged(pathURI: Uri(scheme: "wear", host: "*", path: "/triggerMove")).expand((element) => element).listen(
    (dataEvent) {
      _wearLogger.info("Data Changed $dataEvent");
      if (!dataEvent.isDataValid || dataEvent.type != DataEventType.changed) {
        return;
      }
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
  try {
    Iterable<BaseAction> allActions = favoriteActions.map(
      (e) => ref.read(getActionFromUUIDProvider(e.actionUUID)) as BaseAction,
    );
    Map<String, String> favoriteMap = Map.fromEntries(allActions.map((e) => MapEntry(e.uuid, e.name)));
    Map<String, String> map = Map.fromEntries(
      [
        MapEntry("actions", favoriteMap.values.join("_")),
        MapEntry("uuid", favoriteMap.keys.join("_")),
      ],
    );
    DataItem? _dataItem = await _flutterWearOsConnectivity.syncData(path: "/actions", data: map, isUrgent: false);
  } catch (e, s) {
    _wearLogger.severe("Unable to send favorite actions to watch", e, s);
  }
}
