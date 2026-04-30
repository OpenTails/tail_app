import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../Frontend/translation_string_definitions.dart';
import '../../../Bluetooth/bluetooth_message.dart';
import '../../../Bluetooth/known_devices.dart';
import '../../../Device/device_type_enum.dart';
import '../../sensor_definition.dart';
import '../../sensor_definition_action_definition.dart';
import '../../stored_triggers.dart';

class ClawTiltTriggerDefinition extends TriggerDefinition {
  List<StreamSubscription<String>?> rxSubscriptions = [];

  ClawTiltTriggerDefinition() {
    super.name = triggerClawTiltModeTitle;
    super.description = triggerClawTiltModeDescription;
    super.icon = const Icon(Icons.threed_rotation);
    super.requiredPermission = null;
    super.uuid = "664bd073-34cd-4c78-a7da-2b8b44fd9661";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "Extend",
        translated: triggerClawTiltModeExtend,
        uuid: "74728806-c72d-4b52-94c7-f475e80b826b",
      ),
      TriggerActionDef(
        name: "Retract",
        translated: triggerClawTiltModeRetract,
        uuid: "ca2149c2-86d2-46d7-89b9-508bfab7a29cb",
      ),
    ];
  }

  @override
  Future<bool> isSupported() async {
    return KnownDevices.instance.getKnownGearForType({
      DeviceType.claws,
    }).isNotEmpty;
  }

  @override
  Future<void> onDisable() async {
    KnownDevices.instance.removeListener(onDeviceConnected);
    KnownDevices.instance.getKnownGearForType({DeviceType.claws}).forEach((
      element,
    ) {
      element.deviceConnectionState.removeListener(onDeviceConnected);
    });
    for (var element in rxSubscriptions) {
      element?.cancel();
    }
    rxSubscriptions = [];
    KnownDevices.instance.getConnectedGearForType({DeviceType.claws}).forEach((
      element,
    ) {
      element.commandQueue.addCommand(
        BluetoothMessage(
          message: "STOPTILT",
          priority: Priority.low,
          responseMSG: "OK",
        ),
      );
    });
  }

  @override
  Future<void> onEnable() async {
    if (rxSubscriptions.isNotEmpty) {
      return;
    }
    KnownDevices.instance.getConnectedGearForType({DeviceType.claws}).forEach((
      element,
    ) {
      element.commandQueue.addCommand(
        BluetoothMessage(
          message: "TILTMODE",
          responseMSG: "OK",
          priority: Priority.low,
        ),
      );
    });
    // Disable clap trigger when this one enables
    TriggerList.instance.state
        .where(
          (element) =>
              element.triggerDefUUID == "50d65674-ed4f-4bf5-abd1-e5161faf2a5e",
        )
        .forEach((element) => element.enabled = false);
    //add listeners on new device paired
    KnownDevices.instance.addListener(onDeviceConnected);
  }

  Future<void> onDeviceConnected() async {
    KnownDevices.instance.getKnownGearForType({DeviceType.claws}).map((e) {
      e.deviceConnectionState.removeListener(onDeviceConnected);
      e.deviceConnectionState.addListener(onDeviceConnected);
    });
    listen();
  }

  Future<void> listen() async {
    //cancel old subscriptions
    if (rxSubscriptions.isNotEmpty) {
      for (var element in rxSubscriptions) {
        element?.cancel();
      }
    }
    //Store the current streams to keep them open
    rxSubscriptions = KnownDevices.instance
        .getConnectedGearForType({DeviceType.claws})
        .map((element) {
          element.commandQueue.addCommand(
            BluetoothMessage(
              message: "TILTMODE",
              responseMSG: "OK",
              priority: Priority.low,
            ),
          );
          //TODO: Wire up with the real commands
          return element.rxCharacteristicStream.listen((msg) {
            if (msg.contains("TILT UP")) {
              sendCommands("Extend");
            }
            if (msg.contains("TILT DOWN")) {
              sendCommands("Retract");
            }
          });
        })
        .toList();
  }
}
