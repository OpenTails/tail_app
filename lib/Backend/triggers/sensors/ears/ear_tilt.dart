import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../Frontend/translation_string_definitions.dart';
import '../../../Bluetooth/bluetooth_message.dart';
import '../../../Bluetooth/known_devices.dart';
import '../../../Device/device_type_enum.dart';
import '../../../utilities/version.dart';
import '../../sensor_definition.dart';
import '../../sensor_definition_action_definition.dart';

class EarTiltTriggerDefinition extends TriggerDefinition {
  List<StreamSubscription<String>?> rxSubscriptions = [];

  EarTiltTriggerDefinition() {
    super.name = triggerEarTiltTitle;
    super.description = triggerEarTiltDescription;
    super.icon = const Icon(Icons.threed_rotation);
    super.requiredPermission = null;
    super.uuid = "93d72792-145e-4b56-92b9-3279a5e7d839";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "Left",
        translated: triggerEarTiltLeft,
        uuid: "0137efd7-5a6f-4ac3-8956-cd75e11e6fd4",
      ),
      TriggerActionDef(
        name: "Right",
        translated: triggerEarTiltRight,
        uuid: "21d233cc-aeaf-4096-a997-7070e38a8801",
      ),
      TriggerActionDef(
        name: "Forward",
        translated: triggerEarTiltForward,
        uuid: "7e32987a-588c-4969-a589-d95f94262da7",
      ),
      TriggerActionDef(
        name: "Backward",
        translated: triggerEarTiltBackward,
        uuid: "a4ad813e-a867-4c73-8e73-c4a294829667",
      ),
    ];
  }

  @override
  Future<bool> isSupported() async {
    return KnownDevices.instance.getKnownGearForType({
      DeviceType.ears,
    }).isNotEmpty;
  }

  @override
  Future<void> onDisable() async {
    KnownDevices.instance.removeListener(onDeviceConnected);
    KnownDevices.instance.getKnownGearForType({DeviceType.ears}).forEach((
      element,
    ) {
      element.deviceConnectionState.removeListener(onDeviceConnected);
    });
    for (var element in rxSubscriptions) {
      element?.cancel();
    }
    rxSubscriptions = [];
    KnownDevices.instance.getConnectedGearForType({DeviceType.ears}).forEach((
      element,
    ) {
      String command = "";
      if (element.firmwareStatus.firmwareVersion <
          Version(major: 5, minor: 4)) {
        command = "ENDTILTMODE";
      } else {
        command = "STOPTILT";
      }
      element.commandQueue.addCommand(
        BluetoothMessage(message: command, priority: Priority.low),
      );
    });
  }

  @override
  Future<void> onEnable() async {
    if (rxSubscriptions.isNotEmpty) {
      return;
    }
    KnownDevices.instance.getConnectedGearForType({DeviceType.ears}).forEach((
      element,
    ) {
      String command = "";
      if (element.firmwareStatus.firmwareVersion <
          Version(major: 5, minor: 4)) {
        command = "TILTMODE START";
      } else {
        command = "TILTMODE";
      }
      element.commandQueue.addCommand(
        BluetoothMessage(message: command, priority: Priority.low),
      );
    });
    //add listeners on new device paired
    KnownDevices.instance.addListener(onDeviceConnected);
  }

  Future<void> onDeviceConnected() async {
    KnownDevices.instance.getKnownGearForType({DeviceType.ears}).map((e) {
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
        .getConnectedGearForType({DeviceType.ears})
        .map((element) {
          String command = "";
          if (element.firmwareStatus.firmwareVersion <
              Version(major: 5, minor: 4)) {
            command = "TILTMODE START";
          } else {
            command = "TILTMODE";
          }
          element.commandQueue.addCommand(
            BluetoothMessage(message: command, priority: Priority.low),
          );
          return element.rxCharacteristicStream?.listen((msg) {
            if (msg.contains("TILT LEFT")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              sendCommands("Left");
            } else if (msg.contains("TILT RIGHT")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              sendCommands("Right");
            } else if (msg.contains("TILT FORWARD")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              sendCommands("Forward");
            } else if (msg.contains("TILT BACKWARD")) {
              // we don't store the actions in class as multiple Triggers can exist, so go get them. This is only necessary when the action is dependent on gear being available
              sendCommands("Backward");
            }
          });
        })
        .nonNulls
        .toList();
  }
}
