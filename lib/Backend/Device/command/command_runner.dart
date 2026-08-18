import 'dart:math';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_message.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/audio.dart';
import 'package:tail_app/Backend/dynamic_config.dart';
import 'package:tail_app/Backend/logging_wrappers.dart';
import 'package:tail_app/Backend/move_lists_backend.dart';
import 'package:tail_app/Frontend/utils.dart';
import 'package:tail_app/constants.dart';

import '../../Action/action_category.dart';
import '../../Action/base_action.dart';
import '../device_registry.dart';
import '../device_type_enum.dart';
import '../ear_speed_enum.dart';
import '../stateful/connected_gear.dart';

Battery _battery = Battery();
Logger _logger = Logger("CommandRunner");

Future<void> _actionAnalytics(BaseAction action, String triggeredBy) async {
  DynamicConfigInfo dynamicConfigInfo = await getDynamicConfigInfo();
  if (!dynamicConfigInfo.featureFlags.enableActionAnalytics) {
    return;
  }

  // lets not kill the battery
  final int batteryLevel = await _battery.batteryLevel;
  final bool batterySaver = await _battery.isInBatterySaveMode;

  if (batteryLevel < 50 || batterySaver) {
    return;
  }

  if (await isLimitedDataEnvironment()) {
    return;
  }

  bool isCustomAction = [
    ActionCategory.sequence,
    ActionCategory.audio,
  ].contains(action.actionCategory);
  bool isAudioAction = action.actionCategory == ActionCategory.audio;
  String actionName = isCustomAction
      ? "Custom ${isAudioAction ? "Audio" : "Move"}"
      : action.name;

  analyticsEvent(
    name: "Run Action",
    props: {
      "Action Name": actionName,
      "Action Type": action.getCategoryNameAnalytics(),
      "Triggered By": triggeredBy,
    },
  );
}

Future<void> runActionOnAllSupportedGear(
  BaseAction action, {
  required String triggeredBy,
  bool useHaptics = false,
}) async {
  List<StatefulDevice> devices = getByAction(action).toList()..shuffle();

  if (devices.isNotEmpty &&
      useHaptics &&
      HiveProxy.getOrDefault(settings, haptics, defaultValue: hapticsDefault)) {
    HapticFeedback.selectionClick();
  }

  for (StatefulDevice device in devices) {
    if (HiveProxy.getOrDefault(
      settings,
      kitsuneModeToggle,
      defaultValue: kitsuneModeDefault,
    )) {
      await Future.delayed(
        Duration(milliseconds: Random().nextInt(kitsuneDelayRange)),
      );
    }
    await runAction(device, action, triggeredBy: triggeredBy);
  }
}

Future<void> runAction(
  StatefulDevice device,
  BaseAction action, {
  required String triggeredBy,
}) async {
  _actionAnalytics(action, triggeredBy);
  List<BluetoothMessage> commands = [];
  if (action is CommandAction) {
    commands.addAll(generateCommandActionCommands(action, device));
  } else if (action is MoveList) {
    commands.addAll(generateMoveListCommand(action, device));
  } else if (action is AudioAction) {
    String file = action.file;

    playSound(file);
  }
  for (BluetoothMessage bluetoothMessage in commands) {
    device.commandQueue.addCommand(bluetoothMessage);
  }
}

List<BluetoothMessage> generateCommandActionCommands(
  CommandAction action,
  StatefulDevice device,
) {
  List<BluetoothMessage> commands = [];
  if (device.deviceDefinition.deviceType == DeviceType.ears &&
      !device.bluetoothUartService!.isTailcontrol &&
      action.legacyEarCommandMoves != null) {
    commands.addAll(generateLegacyEarMoveCommands(action, device));
  } else {
    if (action.actionCategory == ActionCategory.rgb) {
      commands.add(generateRgbCommand(action, device));
    } else {
      //Tailcontrol/Normal command
      commands.add(
        BluetoothMessage(
          message: action.command,
          responseMSG: action.response,
          type: CommandType.move,
        ),
      );
    }
  }
  return commands;
}

List<BluetoothMessage> generateLegacyEarMoveCommands(
  CommandAction action,
  StatefulDevice device,
) {
  List<BluetoothMessage> commands = [];
  //support legacy ear firmware
  EarSpeed earSpeed = HiveProxy.getOrDefault(
    settings,
    earMoveSpeed,
    defaultValue: earMoveSpeedDefault,
  );
  BluetoothMessage speedMsg = BluetoothMessage(
    message: earSpeed.command,
    type: CommandType.move,
    responseMSG: earSpeed.command,
  );
  commands.add(speedMsg);

  //There is a delay from when the legacy eargear responds to
  // setting speed before the new speed applies
  BluetoothMessage delayMessage = BluetoothMessage(
    delay: 1,
    type: CommandType.move,
    message: '',
  );
  commands.add(delayMessage);
  for (int i = 0; i < action.legacyEarCommandMoves!.length; i++) {
    Object element = action.legacyEarCommandMoves![i];
    if (element is Move) {
      if (element.moveType == MoveType.delay) {
        BluetoothMessage message = BluetoothMessage(
          delay: element.time,
          type: CommandType.move,
          message: '',
        );
        commands.add(message);
      }
    } else if (element is CommandAction) {
      //Generate move command
      BluetoothMessage message = BluetoothMessage(
        message: element.command,
        type: CommandType.move,
        responseMSG: element.response,
      );
      commands.add(message);
    }
  }
  return commands;
}

BluetoothMessage generateRgbCommand(
  CommandAction action,
  StatefulDevice device,
) {
  double rgbBrightnessValue = HiveProxy.getOrDefault(
    settings,
    rgbBrightness,
    defaultValue: rgbBrightnessDefault,
  );

  return BluetoothMessage(
    message: "${action.command} ${rgbBrightnessValue.toInt().clamp(1, 100)}",
    responseMSG: action.response,
    type: CommandType.move,
  );
}

// Generates the DSSP command for a given move
List<BluetoothMessage> generateMoveCommand(
  Move move,
  StatefulDevice device,
  CommandType type, {
  bool noResponseMsg = false,
  Priority priority = Priority.normal,
}) {
  List<BluetoothMessage> commands = [];
  if (move.moveType == MoveType.home) {
    if (device.deviceDefinition.deviceType == DeviceType.ears &&
        !device.bluetoothUartService!.isTailcontrol) {
      commands.add(
        BluetoothMessage(
          message: "EARHOME",
          priority: priority,
          responseMSG: noResponseMsg ? null : "EARHOME END",
          type: type,
        ),
      );
    } else {
      commands.add(
        BluetoothMessage(
          message: "TAILHM",
          priority: priority,
          responseMSG: noResponseMsg ? null : "END TAILHM",
          type: type,
        ),
      );
    }
  } else if (move.moveType == MoveType.move) {
    if (device.deviceDefinition.deviceType == DeviceType.ears &&
        !device.bluetoothUartService!.isTailcontrol) {
      commands
        ..add(
          BluetoothMessage(
            message: move.speed > 60
                ? EarSpeed.fast.command
                : EarSpeed.slow.command,
            priority: priority,
            responseMSG: noResponseMsg
                ? null
                : move.speed > 60
                ? EarSpeed.fast.command
                : EarSpeed.slow.command,
            type: type,
          ),
        )
        ..add(
          BluetoothMessage(
            message:
                "DSSP ${move.leftServo.round().clamp(0, 128)} ${move.rightServo.round().clamp(0, 128)} 000 000",
            priority: priority,
            responseMSG: noResponseMsg ? null : "DSSP END",
            type: CommandType.move,
          ),
        );
    } else {
      commands.add(
        BluetoothMessage(
          message:
              "DSSP E${move.easingType.num} F${move.easingType.num} A${move.leftServo.round().clamp(0, 128) ~/ 16} B${move.rightServo.round().clamp(0, 128) ~/ 16} L${move.speed.toInt()} M${move.speed.toInt()}",
          priority: priority,
          responseMSG: noResponseMsg ? null : "OK",
          type: type,
        ),
      );
    }
  }
  return commands;
}

List<BluetoothMessage> generateMoveListCommand(
  MoveList movelist,
  StatefulDevice device,
) {
  _logger.info("Starting MoveList ${movelist.name}.");
  List<BluetoothMessage> commands = [];
  if (movelist.moves.isNotEmpty &&
      movelist.moves.length <= 5 &&
      (device.deviceDefinition.deviceType != DeviceType.ears ||
          device.bluetoothUartService!.isTailcontrol)) {
    String cmd =
        "USERMOVE U1P${movelist.moves.length}N${movelist.repeat.toInt()}";
    String a = ''; // servo 1 position
    String b = ''; // servo 2 position
    String e = ''; // servo 1 easing
    String f = ''; // servo 2 easing
    String sl = ''; // servo 1 speed
    String m = ''; // servo 2 speed
    for (int i = 0; i < movelist.moves.length; i++) {
      Move move = movelist.moves[i];
      if (i == 0 && move.moveType == MoveType.delay) {
        continue; // Skip first move if it is a delay
      }
      if (move.moveType == MoveType.delay) {
        if (i > 0 &&
            movelist.moves.length > i + 1 &&
            movelist.moves[i + 1].moveType == MoveType.move) {
          Move prevMove = movelist.moves[i + 1];
          e = '${e}E${prevMove.easingType.num}';
          f = '${f}F${prevMove.easingType.num}';
          a = '${a}A${prevMove.leftServo.round().clamp(0, 128) ~/ 16}';
          b = '${b}B${prevMove.rightServo.round().clamp(0, 128) ~/ 16}';
          sl = '${sl}S${move.speed.toInt()}';
          m = '${m}M${move.speed.toInt()}';
        }
      }
      e = '${e}E${move.easingType.num}';
      f = '${f}F${move.easingType.num}';
      a = '${a}A${move.leftServo.round().clamp(0, 128) ~/ 16}';
      b = '${b}B${move.rightServo.round().clamp(0, 128) ~/ 16}';
      sl = '${sl}L${move.speed.toInt()}';
      m = '${m}M${move.speed.toInt()}';
    }
    cmd = '$cmd $a $b $e $f $sl $m H1';
    commands.add(BluetoothMessage(message: cmd, type: CommandType.move));
    //runs the generated USERMOVE action
    commands.add(
      BluetoothMessage(
        message: "TAILU1",
        responseMSG: "TAILU1 END",
        type: CommandType.move,
      ),
    );
  } else {
    List<Move> newMoveList = List.from(
      movelist.moves,
    ); //prevent home move from being added to original MoveList
    if (movelist.repeat.toInt() > 1) {
      for (int i = 1; i < movelist.repeat; i++) {
        newMoveList.addAll(movelist.moves);
      }
    }
    newMoveList.add(Move.home()); // add final home move
    for (Move element in newMoveList) {
      //run move command
      if (element.moveType == MoveType.delay) {
        BluetoothMessage message = BluetoothMessage(
          delay: element.time,
          type: CommandType.move,
          message: '',
        );
        commands.add(message);
      } else {
        //Generate move command
        commands.addAll(generateMoveCommand(element, device, CommandType.move));
      }
    }
  }
  return commands;
}
