import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_platform/cross_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_wear_os_connectivity/flutter_wear_os_connectivity.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/sensors.dart';

import 'Bluetooth/bluetooth_manager.dart';
import 'Definitions/Action/base_action.dart';
import 'Definitions/Device/device_definition.dart';
import 'favorite_actions.dart';
import 'move_lists.dart';

part 'wear_bridge.g.dart';

final Logger _wearLogger = Logger('Wear');
FlutterWearOsConnectivity _flutterWearOsConnectivity = FlutterWearOsConnectivity();
StreamSubscription<DataEvent>? _dataChangedStreamSubscription;
StreamSubscription<WearOSMessage>? _messagereceivedStreamSubscription;
StreamSubscription<CapabilityInfo>? capabilityChangedStreamSubscription;

@Riverpod(keepAlive: true)
Future<void> initWear(InitWearRef ref) async {
  try {
    if (!Platform.isAndroid || !await _flutterWearOsConnectivity.isSupported()) {
      return;
    }
    _flutterWearOsConnectivity.configureWearableAPI();
    _flutterWearOsConnectivity
        .getConnectedDevices()
        .asStream()
        .expand(
          (element) => element,
        )
        .listen((event) => _wearLogger.info("Connected Wear Device${event.name}, isNearby ${event.isNearby}"));

    _dataChangedStreamSubscription = _flutterWearOsConnectivity.dataChanged().expand((element) => element).listen(
      (dataEvent) {
        _wearLogger.info("dataChanged ${dataEvent.type}, ${dataEvent.dataItem.mapData}");
        if (!dataEvent.isDataValid || dataEvent.type != DataEventType.changed) {
          return;
        }
        Map<String, dynamic> mapData = dataEvent.dataItem.mapData;
        bool containsKey = mapData.containsKey("uuid");
        if (containsKey) {
          String uuid = mapData["uuid"];
          BaseAction? action = ref.read(getActionFromUUIDProvider(uuid));
          if (action != null) {
            Iterable<BaseStatefulDevice> knownDevices = ref
                .read(knownDevicesProvider)
                .values
                .where((element) => action.deviceCategory.contains(element.baseDeviceDefinition.deviceType))
                .where((element) => element.deviceConnectionState.value == ConnectivityState.connected)
                .where((element) => element.deviceState.value == DeviceState.standby);
            for (BaseStatefulDevice device in knownDevices) {
              runAction(action, device);
            }
          }
        }
      },
    );
    _messagereceivedStreamSubscription = _flutterWearOsConnectivity.messageReceived().listen(
          (message) => _wearLogger.info("messageReceived $message"),
        );
    capabilityChangedStreamSubscription = _flutterWearOsConnectivity.capabilityChanged(capabilityPathURI: Uri(scheme: "wear", host: "*", path: "/*")).listen((event) => _wearLogger.info(
          "capabilityChanged $event",
        ));
    updateWearActions(ref.read(favoriteActionsProvider), ref);
  } catch (e, s) {
    _wearLogger.severe("exception setting up Wear $e", e, s);
  }
}

Future<void> updateWearActions(List<FavoriteAction> favoriteActions, Ref ref) async {
  try {
    Iterable<BaseAction> allActions = favoriteActions.map(
      (e) => ref.read(getActionFromUUIDProvider(e.actionUUID)) as BaseAction,
    );
    final Map<String, String> favoriteMap = Map.fromEntries(allActions.map((e) => MapEntry(e.uuid, e.name)));
    final Map<String, String> map = Map.fromEntries(
      [
        MapEntry("actions", favoriteMap.values.join("_")),
        MapEntry("uuid", favoriteMap.keys.join("_")),
      ],
    );
    String msgJson = const JsonEncoder().convert(map);
    List<int> msgBytes = const Utf8Encoder().convert(msgJson);
    List<WearOsDevice> connectedDevices = await _flutterWearOsConnectivity.getConnectedDevices();
    for (WearOsDevice wearOsDevice in connectedDevices) {
      await _flutterWearOsConnectivity.sendMessage(Uint8List.fromList(msgBytes), deviceId: wearOsDevice.id, path: "/actions");
    }

    DataItem? dataItem = await _flutterWearOsConnectivity.syncData(path: "/actions", data: map, isUrgent: true);
    _wearLogger.info("Message Sent successfully? ${dataItem != null}");
  } catch (e, s) {
    _wearLogger.severe("Unable to send favorite actions to watch", e, s);
  }
}
