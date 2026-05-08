import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:tail_app/Backend/triggers/permissions.dart';
import 'package:tail_app/Backend/triggers/sensor_definition_action_definition.dart';
import 'package:tail_app/Backend/triggers/trigger_action.dart';

import '../Action/action_category.dart';
import '../Action/action_registry.dart';
import '../Action/base_action.dart';
import '../Bluetooth/known_devices.dart';
import '../Device/common_device_stuffs.dart';
import '../Device/device_type_enum.dart';
import '../command_runner.dart';
import '../wear_bridge.dart';

final _random = Random();

abstract class TriggerDefinition extends ChangeNotifier
    implements Comparable<TriggerDefinition> {
  late final Function name;
  late final Function description;
  late final Widget icon;
  late final String uuid;
  List<TriggerAction> triggerActions = [];
  bool _enabled = false;

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (value == _enabled) {
      return;
    }
    if (!value && triggerActions.isEmpty) {
      _enabled = false;
      onDisable();
      notifyListeners();
    } else if (requiredPermission != null && value) {
      requiredPermission?.hasAllPermissions().then((granted) async {
        if (granted) {
          _enabled = true;
          onEnable();
        }
        notifyListeners();
      });
    } else if (value) {
      _enabled = true;
      onEnable();
      notifyListeners();
    }

    //Refresh wear data when a trigger is enabled/disabled
    // ignore: unused_result
    updateWearData(reason: "Trigger Enabled/Disabled");
  }

  String _debug = "";

  String get debug => _debug;

  set debug(String value) {
    _debug = value;
    notifyListeners();
  }

  Future<void> onEnable();

  Future<void> onDisable();

  TriggerPermissionHandle? requiredPermission;
  late final List<TriggerActionDef> triggerActionDefinitions;

  TriggerDefinition();

  // add check here if a trigger is supported on a given device/platform
  Future<bool> isSupported() async {
    return true;
  }

  Future<void> sendCommands(String name) async {
    if (KnownDevices.instance.connectedGear.isEmpty) {
      return;
    }
    triggerActions
        .where(
          (e) =>
              triggerActionDefinitions
                  .firstWhere((element) => element.name == name)
                  .uuid ==
              e.uuid,
        )
        .forEach((TriggerAction triggerAction) async {
          if (triggerAction.isActive || triggerAction.actions.isEmpty) {
            // 15 second cool-down between moves
            return;
          }
          final List<BaseAction> allActionsMapped = triggerAction.actions
              .map((element) => ActionRegistry.getActionFromUUID(element))
              .nonNulls
              .toList();

          // no moves exist
          if (allActionsMapped.isEmpty) {
            return;
          }
          // we need to handle legacy ears for now
          // assuming only legacy or tailcontrol ears are connected. no mixing
          bool hasLegacyEars = KnownDevices.instance.isLegacyEarsConnected;
          bool hasGlowtipGear = KnownDevices.instance.isGlowtipGearConnected;
          bool hasRgbGear = KnownDevices.instance.isRgbGearConnected;

          final List<BaseAction> moveActions = allActionsMapped
              .where(
                (element) => !const [
                  ActionCategory.glowtip,
                  ActionCategory.rgb,
                  ActionCategory.audio,
                ].contains(element.actionCategory),
              )
              .toList();

          final List<BaseAction> glowActions = hasGlowtipGear
              ? allActionsMapped
                    .where(
                      (element) => const [
                        ActionCategory.glowtip,
                      ].contains(element.actionCategory),
                    )
                    .toList()
              : [];
          final List<BaseAction> rgbActions = hasRgbGear
              ? allActionsMapped
                    .where(
                      (element) => const [
                        ActionCategory.rgb,
                      ].contains(element.actionCategory),
                    )
                    .toList()
              : [];

          final List<BaseAction> audioActions = allActionsMapped
              .where(
                (element) => const [
                  ActionCategory.audio,
                ].contains(element.actionCategory),
              )
              .toList();

          BaseAction? baseAction;
          List<BaseAction> actionsToRun = [];

          // add a glowtip action if it exists
          if (glowActions.isNotEmpty) {
            final BaseAction glowAction =
                glowActions[_random.nextInt(glowActions.length)];
            actionsToRun.add(glowAction);
          }
          // add a rgb action if it exists
          if (rgbActions.isNotEmpty) {
            final BaseAction rgbAction =
                rgbActions[_random.nextInt(rgbActions.length)];
            actionsToRun.add(rgbAction);
          }
          // add a audio action if it exists
          if (audioActions.isNotEmpty) {
            final BaseAction audioAction =
                audioActions[_random.nextInt(audioActions.length)];
            actionsToRun.add(audioAction);
          }
          // check if non glowy actions are set
          if (moveActions.isNotEmpty) {
            baseAction = moveActions[_random.nextInt(moveActions.length)];
            actionsToRun.add(baseAction);
          }
          // if more than 1 move is selected
          if (baseAction != null &&
              moveActions.length > 1 &&
              !baseAction.deviceCategory.toSet().containsAll(
                DeviceType.values.toSet(),
              )) {
            // find the missing device type
            // The goal here is if a user selects multiple moves, send a move to all gear
            final Set<DeviceType>
            baseActionDeviceCategories = baseAction.deviceCategory.where(
              // filtering out the first actions ears entry if its a unified move but legacy gear is connected
              (element) {
                if (element == DeviceType.ears) {
                  if (baseAction is CommandAction) {
                    return hasLegacyEars &&
                        baseAction.legacyEarCommandMoves != null;
                  }
                }
                return true;
              },
            ).toSet();
            final Set<DeviceType> missingGearAction = DeviceType.values
                .toSet()
                .difference(baseActionDeviceCategories);
            final List<BaseAction> remainingActions = moveActions.where(
              // Check if any actions contain the device type of the gear the first action is missing
              (element) {
                return element.deviceCategory
                    .toSet()
                    .intersection(missingGearAction)
                    .isNotEmpty;
              },
            ).toList();
            if (remainingActions.isNotEmpty) {
              final BaseAction otherAction =
                  remainingActions[_random.nextInt(remainingActions.length)];
              actionsToRun.add(otherAction);
            }
          }
          // updates the frontend that a trigger activated
          triggerAction.isActive = true;

          // keep track of the devices a command was sent to so multiple move commands are not sent to the same device
          Set<DeviceType> sentDeviceTypes = {};
          for (BaseAction baseAction in actionsToRun) {
            Set<DeviceType> availableDeviceTypesToRun = KnownDevices.instance
                .getConnectedIdleGearForType(
                  baseAction.deviceCategory.toSet().intersection(
                    DeviceType.values.toSet(),
                  ),
                )
                .where(
                  // support sending to next device type if 2 actions+ actions are set
                  (element) => !sentDeviceTypes.contains(
                    element.deviceDefinition.deviceType,
                  ),
                )
                .where((element) {
                  // filter out devices without a glowtip if its a glowtip action
                  if ([
                    ActionCategory.glowtip,
                  ].contains(baseAction.actionCategory)) {
                    return element.hasGlowtip.value == GlowtipStatus.glowtip;
                  }
                  if ([
                    ActionCategory.rgb,
                  ].contains(baseAction.actionCategory)) {
                    return element.hasRGB.value == RGBStatus.rgb;
                  }
                  // return remaining gear
                  return true;
                })
                .map((e) => e.deviceDefinition.deviceType)
                .toSet();

            // Move on to the next action
            if (availableDeviceTypesToRun.isEmpty) {
              continue;
            }

            runActionOnAllSupportedGear(
              baseAction,
              triggeredBy: Intl.withLocale('en', () => this.name()),
            );

            // filter out non move categories from the send device types.
            if ([ActionCategory.sequence].contains(baseAction.actionCategory) ||
                baseAction.actionCategory == null) {
              sentDeviceTypes.addAll(availableDeviceTypesToRun);
            }
          }
        });
  }

  @override
  int compareTo(TriggerDefinition other) {
    return name().compareTo(other.name());
  }
}
