import 'dart:async';

import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    hide CharacteristicProperties;
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../../Bluetooth/known_devices.dart';
import '../permissions.dart';
import '../sensor_definition.dart';
import '../sensor_definition_action_definition.dart';

class TailProximityTriggerDefinition extends TriggerDefinition {
  StreamSubscription<List<ScanResult>>? btConnectStream;
  Timer? btnearbyCooldown;
  bool _didInitBLE = false;
  final Logger _logger = Logger("BleAdvertisingSensor");

  TailProximityTriggerDefinition() {
    super.name = triggerProximityTitle;
    super.description = triggerProximityDescription;
    super.icon = const Icon(Icons.bluetooth_connected);
    super.requiredPermission = TriggerPermissionHandle(
      android: {Permission.bluetoothScan, Permission.bluetoothAdvertise},
      ios: {Permission.bluetooth},
    );
    super.uuid = "5418e7a5-850b-482e-ba35-163564c848ab";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "Nearby Gear",
        translated: triggerProximityTitle,
        uuid: "e78a749b-8b78-47df-a5a1-1ed365292214",
        defaultActions: true,
      ),
    ];
  }

  @override
  Future<void> onDisable() async {
    btConnectStream?.cancel();
    btConnectStream = null;
  }

  @override
  Future<void> onEnable() async {
    if (btConnectStream != null) {
      return;
    }
    if (!_didInitBLE) {
      await BlePeripheral.initialize();
      await BlePeripheral.addService(
        BleService(
          uuid: "40bea134-8f5f-45e6-9f69-440a41d780cb",
          primary: true,
          characteristics: [
            BleCharacteristic(
              uuid: "08d56d71-f22e-4ba4-a49e-6b8bf8874dcd",
              properties: [
                CharacteristicProperties.read.index,
                CharacteristicProperties.notify.index,
              ],
              value: null,
              permissions: [AttributePermissions.readable.index],
            ),
          ],
        ),
      );

      /// set callback for advertising state
      BlePeripheral.setAdvertisingStatusUpdateCallback(
        advertisingStatusUpdateCallback,
      );
      _didInitBLE = true;
    }
    // Start advertising
    await BlePeripheral.startAdvertising(
      services: ["40bea134-8f5f-45e6-9f69-440a41d780cb"],
      localName: "TailCoApp",
    );
    /* TODO:
      https://pub.dev/packages/ble_peripheral
      - modify ble scan logic to support this new service
      - verify phones don't appear in the UI
      - verify advertising doesn't interfere with ble gear connection
     */

    btConnectStream = FlutterBluePlus.onScanResults.listen((event) {
      if (event
              .where(
                (element) => !KnownDevices.instance.state.keys.contains(
                  element.device.remoteId.str,
                ),
              )
              .isNotEmpty &&
          btnearbyCooldown != null &&
          btnearbyCooldown!.isActive) {
        sendCommands("Nearby Gear");

        btnearbyCooldown = Timer(const Duration(seconds: 30), () {});
      }
    });
  }

  void advertisingStatusUpdateCallback(bool advertising, String? error) {
    _logger.info("AdvertisingStatus: $advertising Error $error");
    if (error != null) {
      enabled = false;
    }
  }

  @override
  Future<bool> isSupported() async {
    // TODO: re-enable on release builds when finished
    return kDebugMode;
  }
}
