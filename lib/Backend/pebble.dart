import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/Backend/Action/action_registry.dart';
import 'package:tail_app/Backend/Action/base_action.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Backend/favorite_actions.dart';
import 'package:universal_io/io.dart';

class PebbleManager {
  bool _didInit = false;

  final int pebbleDeviceListKey = 0;
  final int pebbleFavoriteActionListKey = 1;
  final Logger _logger = Logger("Pebble");
  static final instance = PebbleManager._internal();
  MethodChannel? _methodChannel;
  EventChannel? _eventChannel;
  final String companionUUID = "2f0f69dd-af4c-4bb3-a679-138ed0ff9242";

  PebbleManager._internal() {
    KnownDevices.instance.addListener(_listener);
    FavoriteActions.instance.addListener(_listener);
    _eventChannel?.receiveBroadcastStream().listen(_onDataReceived);
    init(companionUUID);
  }

  void _onDataReceived(dynamic event) {
    _logger.info("Received data from pebble: $event");
    if (event is Map<int, dynamic>) {
      //Do something here
    }
  }

  void _listener() {
    Map<int, dynamic> dataToSend = {};
    if (KnownDevices.instance.state.isEmpty) {
      return;
    }
    String deviceList = KnownDevices.instance.state.values
        .map((element) => element.storedDevice.name)
        .foldIndexed("", (index, previous, element) {
          return previous += "$element, $index ";
        });
    String favoriteActionsList = FavoriteActions.instance.state.fold("", (
      previous,
      element,
    ) {
      BaseAction? baseAction = ActionRegistry.getActionFromUUID(
        element.actionUUID,
      );
      if (baseAction == null) {
        return previous;
      }
      return previous += "${baseAction.name}, ${element.id} ";
    });
    if (deviceList.trim().isEmpty) {
      return;
    }
    dataToSend[pebbleDeviceListKey] = deviceList;
    dataToSend[pebbleFavoriteActionListKey] = favoriteActionsList;
    sendData(dataToSend);
  }

  bool get isSupported => Platform.isAndroid;

  Future<bool> isConnected() async {
    if (!isSupported || !_didInit) {
      return false;
    }
    return await _methodChannel
            ?.invokeMethod<bool>("isConnected")
            .timeout(
              Duration(seconds: 10),
              onTimeout: () {
                _logger.severe(
                  "Failed to get isConnected from pebble. Timed "
                  "out",
                );
                return false;
              },
            )
            .onError((error, stackTrace) {
              _logger.severe(
                "Failed to get isConnected from pebble",
                error,
                stackTrace,
              );
              return false;
            }) ??
        false;
  }

  Future<void> sendData(Map<int, dynamic> data) async {
    if (!isSupported) {
      return;
    }
    if (!_didInit) {
      throw Exception("Pebble companion uuid not set");
    }
    if (!await isConnected()) {
      return;
    }
    _logger.info("Sending data to pebble: $data");
    if (!isDataValid(data)) {
      _logger.severe(
        "Invalid data type found. Map values can only be String "
        "or Int. Data: $data",
      );
      return;
    }
    await _methodChannel
        ?.invokeMethod("sendData", data)
        .timeout(
          Duration(seconds: 10),
          onTimeout: () =>
              _logger.severe("Failed to send data to pebble. Timed out"),
        )
        .onError(
          (error, stackTrace) => _logger.severe(
            "Failed to send data to pebble",
            error,
            stackTrace,
          ),
        );
  }

  //Only String and int (32 bit) are supported
  bool isDataValid(Map<int, dynamic> map) {
    return map.values
        .where((element) => element is String || element is int)
        .isNotEmpty;
  }

  Future<void> init(String companionAppUUID) async {
    if (!isSupported) {
      return;
    }
    _methodChannel = MethodChannel("pebble");
    _eventChannel = EventChannel("pebble_streanm");
    _logger.info("Configuring pebble");
    await _methodChannel!
        .invokeMethod("init", companionAppUUID)
        .timeout(
          Duration(seconds: 10),
          onTimeout: () =>
              _logger.severe("Failed to send uuid to pebble. Timed out"),
        )
        .onError((error, stackTrace) {
          _didInit = false;
          _logger.severe("Failed to send uuid to pebble", error, stackTrace);
        })
        .whenComplete(() => _didInit = true);
  }
}
