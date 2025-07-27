import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:data_saver/data_saver.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_message.dart';
import 'package:tail_app/Backend/Definitions/Action/base_action.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/audio.dart';
import 'package:tail_app/Backend/command_queue.dart';
import 'package:tail_app/Backend/dynamic_config.dart';
import 'package:tail_app/Backend/logging_wrappers.dart';
import 'package:tail_app/Backend/move_lists.dart';
import 'package:tail_app/constants.dart';
import 'package:battery_plus/battery_plus.dart';

part 'command_runner.g.dart';

@Riverpod()
class RunAction extends _$RunAction {
  @override
  BaseStatefulDevice build(BaseStatefulDevice device) {
    return device;
  }

  DataSaver dataSaver = DataSaver();
  Battery battery = Battery();

  Future<void> _actionAnalytics(BaseAction action, String triggeredBy) async {
    DynamicConfigInfo dynamicConfigInfo = await getDynamicConfigInfo();
    if (!dynamicConfigInfo.featureFlags.enableActionAnalytics) {
      return;
    }

    // lets not kill the battery
    final int batteryLevel = await battery.batteryLevel;
    final bool batterySaver = await battery.isInBatterySaveMode;
    
    if (batteryLevel < 50 || batterySaver) {
      return;
    }

    final DataSaverMode mode = await dataSaver.checkMode();
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

    // lets not burn through all of the data
    if (mode == DataSaverMode.enabled && connectivityResult.contains(ConnectivityResult.mobile)) {
      return;
    }

    bool isCustomAction = [ActionCategory.sequence, ActionCategory.audio].contains(action.actionCategory);
    bool isAudioAction = action.actionCategory == ActionCategory.audio;
    String actionName = isCustomAction ? "Custom ${isAudioAction ? "Audio" : "Move"}" : action.name;

    analyticsEvent(name: "Run Action", props: {"Action Name": actionName, "Action Type": action.actionCategory.name, "Triggered By": triggeredBy});
  }

  Future<void> runAction(BaseAction action, {required String triggeredBy}) async {
    _actionAnalytics(action, triggeredBy);
    //cursed handling of ears specifically
    //TODO: Remove with TAILCoNTROL update
    if (action is EarsMoveList) {
      if (action.commandMoves.isNotEmpty && device.baseDeviceDefinition.deviceType == DeviceType.ears) {
        EarSpeed earSpeed = HiveProxy.getOrDefault(settings, earMoveSpeed, defaultValue: earMoveSpeedDefault);
        BluetoothMessage speedMsg = BluetoothMessage(message: earSpeed.command, priority: Priority.normal, type: CommandType.move, responseMSG: earSpeed.command, timestamp: DateTime.now());
        ref.read(commandQueueProvider(device).notifier).addCommand(speedMsg);
        BluetoothMessage delayMessage = BluetoothMessage(delay: 1, priority: Priority.normal, type: CommandType.move, message: '', timestamp: DateTime.now());
        ref.read(commandQueueProvider(device).notifier).addCommand(delayMessage);
        for (int i = 0; i < action.commandMoves.length; i++) {
          Object element = action.commandMoves[i];
          if (element is Move) {
            if (element.moveType == MoveType.delay) {
              BluetoothMessage message = BluetoothMessage(delay: element.time, priority: Priority.normal, type: CommandType.move, message: '', timestamp: DateTime.now());
              ref.read(commandQueueProvider(device).notifier).addCommand(message);
            }
          } else if (element is CommandAction) {
            //Generate move command
            BluetoothMessage message = BluetoothMessage(message: element.command, priority: Priority.normal, type: CommandType.move, responseMSG: element.response, timestamp: DateTime.now());
            ref.read(commandQueueProvider(device).notifier).addCommand(message);
          }
        }
      }
    } else if (action is CommandAction) {
      ref
          .read(commandQueueProvider(device).notifier)
          .addCommand(BluetoothMessage(message: action.command, priority: Priority.normal, responseMSG: action.response, type: CommandType.move, timestamp: DateTime.now()));
    } else if (action is MoveList) {
      sequencesLogger.info("Starting MoveList ${action.name}.");
      if (action.moves.isNotEmpty && action.moves.length <= 5 && (device.baseDeviceDefinition.deviceType != DeviceType.ears || device.isTailCoNTROL.value == TailControlStatus.tailControl)) {
        int preset = 1; //TODO: store
        String cmd = "USERMOVE U${preset}P${action.moves.length}N${action.repeat.toInt()}";
        String a = ''; // servo 1 position
        String b = ''; // servo 2 position
        String e = ''; // servo 1 easing
        String f = ''; // servo 2 easing
        String sl = ''; // servo 1 speed
        String m = ''; // servo 2 speed
        for (int i = 0; i < action.moves.length; i++) {
          Move move = action.moves[i];
          if (i == 0 && move.moveType == MoveType.delay) {
            continue; // Skip first move if it is a delay
          }
          if (move.moveType == MoveType.delay) {
            if (i > 0 && action.moves.length > i + 1 && action.moves[i + 1].moveType == MoveType.move) {
              Move prevMove = action.moves[i + 1];
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
        ref.read(commandQueueProvider(device).notifier).addCommand(BluetoothMessage(message: cmd, priority: Priority.normal, type: CommandType.move, timestamp: DateTime.now()));
        ref
            .read(commandQueueProvider(device).notifier)
            .addCommand(BluetoothMessage(message: "TAILU$preset", priority: Priority.normal, responseMSG: "TAILU$preset END", type: CommandType.move, timestamp: DateTime.now()));
      } else {
        List<Move> newMoveList = List.from(action.moves); //prevent home move from being added to original MoveList
        if (action.repeat.toInt() > 1) {
          for (int i = 1; i < action.repeat; i++) {
            newMoveList.addAll(action.moves);
          }
        }
        newMoveList.add(Move.home()); // add final home move
        for (Move element in newMoveList) {
          //run move command
          if (element.moveType == MoveType.delay) {
            BluetoothMessage message = BluetoothMessage(delay: element.time, priority: Priority.normal, type: CommandType.move, message: '', timestamp: DateTime.now());
            ref.read(commandQueueProvider(device).notifier).addCommand(message);
          } else {
            //Generate move command
            generateMoveCommand(element, device, CommandType.move).forEach(
              (element) {
                ref.read(commandQueueProvider(device).notifier).addCommand(element);
              },
            );
          }
        }
      }
    } else if (action is AudioAction) {
      String file = action.file;

      playSound(file);
    }
  }
}

// Generates the DSSP command for a given move
List<BluetoothMessage> generateMoveCommand(Move move, BaseStatefulDevice device, CommandType type, {bool noResponseMsg = false, Priority priority = Priority.normal}) {
  List<BluetoothMessage> commands = [];
  if (move.moveType == MoveType.home) {
    //TODO: Remove for TAILCoNTROL update
    if (device.baseDeviceDefinition.deviceType == DeviceType.ears && device.isTailCoNTROL.value != TailControlStatus.tailControl) {
      commands.add(BluetoothMessage(message: "EARHOME", priority: priority, responseMSG: noResponseMsg ? null : "EARHOME END", type: type, timestamp: DateTime.now()));
    } else {
      commands.add(BluetoothMessage(message: "TAILHM", priority: priority, responseMSG: noResponseMsg ? null : "END TAILHM", type: type, timestamp: DateTime.now()));
    }
  } else if (move.moveType == MoveType.move) {
    //TODO: Remove for TAILCoNTROL update
    if (device.baseDeviceDefinition.deviceType == DeviceType.ears && device.isTailCoNTROL.value != TailControlStatus.tailControl) {
      commands
        ..add(
          BluetoothMessage(
            message: move.speed > 60 ? EarSpeed.fast.command : EarSpeed.slow.command,
            priority: priority,
            responseMSG: noResponseMsg
                ? null
                : move.speed > 60
                    ? EarSpeed.fast.command
                    : EarSpeed.slow.command,
            type: type,
            timestamp: DateTime.now(),
          ),
        )
        ..add(BluetoothMessage(
            message: "DSSP ${move.leftServo.round().clamp(0, 128)} ${move.rightServo.round().clamp(0, 128)} 000 000",
            priority: priority,
            responseMSG: noResponseMsg ? null : "DSSP END",
            type: CommandType.move,
            timestamp: DateTime.now()));
    } else {
      commands.add(
        BluetoothMessage(
          message:
              "DSSP E${move.easingType.num} F${move.easingType.num} A${move.leftServo.round().clamp(0, 128) ~/ 16} B${move.rightServo.round().clamp(0, 128) ~/ 16} L${move.speed.toInt()} M${move.speed.toInt()}",
          priority: priority,
          responseMSG: noResponseMsg ? null : "OK",
          type: type,
          timestamp: DateTime.now(),
        ),
      );
    }
  }
  return commands;
}
