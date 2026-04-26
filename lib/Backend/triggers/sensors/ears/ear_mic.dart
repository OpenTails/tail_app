import 'dart:async';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';

import '../../../../Frontend/translation_string_definitions.dart';
import '../../../Bluetooth/bluetooth_message.dart';
import '../../../Bluetooth/known_devices.dart';
import '../../../Definitions/Device/device_type_enum.dart';
import '../../../version.dart';
import '../../sensor_definition.dart';
import '../../sensor_definition_action_definition.dart';

class EarMicTriggerDefinition extends TriggerDefinition {
  List<StreamSubscription<String>?> rxSubscriptions = [];

  EarMicTriggerDefinition() {
    super.name = triggerEarMicTitle;
    super.description = triggerEarMicDescription;
    super.icon = const Icon(Icons.mic);
    super.requiredPermission = null;
    super.uuid = "3bbd2306-ea53-44f5-a930-474ff23ec23d";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "Sound",
        translated: triggerEarMicSound,
        uuid: "839d8978-7b77-4ccb-b23f-28144bf95453",
      ),
    ];
  }

  @override
  Future<bool> isSupported() async {
    return KnownDevices.instance
        .getKnownGearForType(BuiltSet([DeviceType.ears]))
        .isNotEmpty;
  }

  @override
  Future<void> onDisable() async {
    KnownDevices.instance.removeListener(onDeviceConnected);
    KnownDevices.instance
        .getKnownGearForType(BuiltSet([DeviceType.ears]))
        .forEach((element) {
          element.deviceConnectionState.removeListener(onDeviceConnected);
        });
    for (var element in rxSubscriptions) {
      element?.cancel();
    }
    rxSubscriptions = [];
    KnownDevices.instance
        .getKnownGearForType(BuiltSet([DeviceType.ears]))
        .forEach((element) {
          String command = "";
          String responseMSG = "";
          if (element.fwVersion.value < Version(major: 5, minor: 4)) {
            command = "ENDLISTEN";
            responseMSG = "LISTEN OFF";
          } else {
            command = "STOPLISTEN";
            responseMSG = "OK";
          }
          element.commandQueue.addCommand(
            BluetoothMessage(
              message: command,
              priority: Priority.low,
              responseMSG: responseMSG,
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
        .getKnownGearForType(BuiltSet([DeviceType.ears]))
        .forEach((element) {
          String command = "";
          if (element.fwVersion.value < Version(major: 5, minor: 4)) {
            command = "LISTEN FULL";
          } else {
            command = "LISTENMODE";
          }
          element.commandQueue.addCommand(
            BluetoothMessage(message: command, priority: Priority.low),
          );
        });
    //add listeners on new device paired
    KnownDevices.instance.addListener(onDeviceConnected);
  }

  Future<void> onDeviceConnected() async {
    KnownDevices.instance.getKnownGearForType(BuiltSet([DeviceType.ears])).map((
      e,
    ) {
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
        .getConnectedGearForType(BuiltSet([DeviceType.ears]))
        .map((element) {
          String command = "";
          if (element.fwVersion.value < Version(major: 5, minor: 4)) {
            command = "LISTEN FULL";
          } else {
            command = "LISTENMODE";
          }
          element.commandQueue.addCommand(
            BluetoothMessage(message: command, priority: Priority.low),
          );
          return element.rxCharacteristicStream.listen((msg) {
            if (msg.contains("LISTEN_FULL BANG")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              sendCommands("Sound");
            }
          });
        })
        .toList();
  }
}
