import 'dart:async';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';

import '../../../../Frontend/translation_string_definitions.dart';
import '../../../Bluetooth/bluetooth_message.dart';
import '../../../Bluetooth/known_devices.dart';
import '../../../Definitions/Device/device_type_enum.dart';
import '../../sensor_definition.dart';
import '../../sensor_definition_action_definition.dart';
import '../../stored_triggers.dart';

class ClawClapTriggerDefinition extends TriggerDefinition {
  List<StreamSubscription<String>?> rxSubscriptions = [];

  ClawClapTriggerDefinition() {
    super.name = triggerClawClapModeTitle;
    super.description = triggerClawClapModeDescription;
    super.icon = const Icon(Icons.waving_hand_sharp);
    super.requiredPermission = null;
    super.uuid = "50d65674-ed4f-4bf5-abd1-e5161faf2a5e";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "Clap",
        translated: triggerClawClapMode,
        uuid: "6b88bc2a-dea2-435c-88be-7c16df687225",
      ),
    ];
  }

  @override
  Future<bool> isSupported() async {
    return KnownDevices.instance
        .getKnownGearForType(BuiltSet([DeviceType.claws]))
        .isNotEmpty;
  }

  @override
  Future<void> onDisable() async {
    KnownDevices.instance.removeListener(onDeviceConnected);
    KnownDevices.instance
        .getKnownGearForType(BuiltSet([DeviceType.claws]))
        .forEach((element) {
          element.deviceConnectionState.removeListener(onDeviceConnected);
        });
    for (var element in rxSubscriptions) {
      element?.cancel();
    }
    rxSubscriptions = [];
    KnownDevices.instance
        .getConnectedGearForType(BuiltSet([DeviceType.claws]))
        .forEach((element) {
          element.commandQueue.addCommand(
            BluetoothMessage(
              message: "STOPCLAP",
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
    KnownDevices.instance
        .getConnectedGearForType(BuiltSet([DeviceType.claws]))
        .forEach((element) {
          element.commandQueue.addCommand(
            BluetoothMessage(
              message: "CLAPMODE",
              responseMSG: "OK",
              priority: Priority.low,
            ),
          );
        });

    // Disable claw tilt trigger when this one enables
    TriggerList.instance.state
        .where(
          (element) =>
              element.triggerDefUUID == "664bd073-34cd-4c78-a7da-2b8b44fd9661",
        )
        .forEach((element) => element.enabled = false);

    //add listeners on new device paired
    KnownDevices.instance.addListener(onDeviceConnected);
  }

  Future<void> onDeviceConnected() async {
    KnownDevices.instance.getKnownGearForType(BuiltSet([DeviceType.claws])).map(
      (e) {
        e.deviceConnectionState.removeListener(onDeviceConnected);
        e.deviceConnectionState.addListener(onDeviceConnected);
      },
    );
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
        .getConnectedGearForType(BuiltSet([DeviceType.claws]))
        .map((element) {
          element.commandQueue.addCommand(
            BluetoothMessage(
              message: "CLAPMODE",
              responseMSG: "OK",
              priority: Priority.low,
            ),
          );
          return element.rxCharacteristicStream.listen((msg) {
            if (msg.contains("DOUBLE CLAP")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              sendCommands("Clap");
            }
          });
        })
        .toList();
  }
}
