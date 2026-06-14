import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Device/command/command_history.dart';
import 'package:tail_app/Backend/utilities/demo_gear_helpers.dart';

import '../../Bluetooth/bluetooth_message.dart';
import '../stateful/connected_gear.dart';

enum CommandQueueState {
  running,

  /// A command is in progress
  waitingForResponse,
  delay, // The queue is momentarily paused
  blocked, // the queue is stopped
  idle, // inbetween moves
  empty, // the queue is empty
}

class CommandQueue with ChangeNotifier {
  final Logger _logger = Logger("CommandQueue");
  final PriorityQueue<BluetoothMessage> _internalCommandQueue = PriorityQueue();
  final StatefulDevice device;
  Duration timeoutDuration = const Duration(seconds: 10);
  Timer? _runningCommandTimer;
  BluetoothMessage? currentMessage;
  int retryCount = -1;
  final CommandHistory commandHistory = CommandHistory();

  List<BluetoothMessage> get queue => _internalCommandQueue.toList();

  CommandQueue(this.device) {
    device.bluetoothUartService.addListener(_connectionStateListener);
    device.gearReturnedError.addListener(_gearErrorListener);
    device.deviceState.addListener(_deviceStateListener);
    addListener(_onStateChanged);
  }

  CommandQueueState get state => _state;
  CommandQueueState _state = CommandQueueState.empty;

  void _setState(CommandQueueState state) {
    if (_state == state) {
      return;
    }
    if (_internalCommandQueue.isEmpty && state == CommandQueueState.idle) {
      _state = CommandQueueState.empty;
    } else {
      _state = state;
    }
    notifyListeners();
  }

  void _connectionStateListener() {
    if (device.deviceConnectionState.value != ConnectivityState.connected) {
      _internalCommandQueue.clear(); // clear the queue on disconnect
      stopQueue();
    } else {
      startQueue();
    }
  }

  /// Used to listen for a response if one is set in [BluetoothMessage].responseMSG
  void bluetoothResponseListener(String msg) {
    if (state == CommandQueueState.waitingForResponse &&
        currentMessage != null &&
        currentMessage!.responseMSG != null) {
      if (msg == currentMessage!.responseMSG!) {
        _setState(CommandQueueState.idle);
      }
    }
  }

  /// Called when a command response is not received
  void _onTimeout() {
    if (currentMessage != null &&
        currentMessage!.resendRetries - retryCount > 0) {
      retryCount += 1;
      _logger.warning(
        "Resending command $currentMessage. Retries remaining "
        "$retryCount",
      );
      runCommand(currentMessage!);
    } else {
      _logger.warning("Command timed out! $currentMessage");
      _endCommand();
    }
  }

  void _endCommand() {
    currentMessage = null;
    _runningCommandTimer = null;
    retryCount = -1;
    if ([
      CommandQueueState.delay,
      CommandQueueState.waitingForResponse,
      CommandQueueState.running,
    ].contains(state)) {
      _setState(CommandQueueState.idle);
    }
  }

  /// Trigger resending the current command if the gear returns ERR/BUSY
  void _gearErrorListener() {
    if (device.gearReturnedError.value &&
        [
          CommandQueueState.delay,
          CommandQueueState.waitingForResponse,
        ].contains(state)) {
      device.gearReturnedError.value = false;
      _resendCommand();
    }
  }

  void _resendCommand() {
    if (currentMessage != null) {
      _logger.warning(
        "Resending message for ${device.storedDevice.name} $currentMessage",
      );
      addCommand(currentMessage!);
      _endCommand(); //abort waiting for the command to finish
    }
  }

  void _deviceStateListener() {
    if (state == CommandQueueState.blocked &&
        device.deviceState.value == DeviceMoveState.standby) {
      startQueue();
    } else if (state != CommandQueueState.blocked &&
        device.deviceState.value == DeviceMoveState.busy) {
      stopQueue();
    }
  }

  /// Stops the queue and aborts waiting for the next command;
  void stopQueue() {
    _logger.fine("Stopping queue for ${device.storedDevice.name}");
    _setState(CommandQueueState.blocked);
    _runningCommandTimer?.cancel();
    _runningCommandTimer = null;
    currentMessage = null;
  }

  void startQueue() {
    _logger.fine("Starting queue for ${device.storedDevice.name}");
    _setState(CommandQueueState.idle);
  }

  /// Handles running the next command and marking gear as busy/idle
  void _onStateChanged() {
    switch (state) {
      case CommandQueueState.running:
      case CommandQueueState.waitingForResponse:
      case CommandQueueState.delay:
        device.deviceState.value = DeviceMoveState.runAction;
        break;
      case CommandQueueState.blocked:
        device.deviceState.value = DeviceMoveState.busy;
        break;
      case CommandQueueState.idle:
        if (_internalCommandQueue.isEmpty) {
          _setState(CommandQueueState.empty);
        } else {
          Future(() => runCommand(_internalCommandQueue.removeFirst()));
        }
        break;
      case CommandQueueState.empty:
        device.deviceState.value = DeviceMoveState.standby;
        break;
    }
  }

  Future<void> runCommand(BluetoothMessage bluetoothMessage) async {
    currentMessage = bluetoothMessage;
    if (retryCount < 0) {
      retryCount = currentMessage!.resendRetries.clamp(0, 5);
    }
    _setState(CommandQueueState.running);
    device.gearReturnedError.value = false;

    // handle if the command is a delay command
    if (bluetoothMessage.delay != null) {
      _logger.fine("Pausing queue for ${device.storedDevice.name}");
      _runningCommandTimer = Timer(
        Duration(milliseconds: bluetoothMessage.delay!.toInt() * 20),
        _endCommand,
      );
      _setState(CommandQueueState.delay);
    } else {
      _logger.fine(
        "Sending command to ${device.storedDevice.name}:${bluetoothMessage.message}",
      );
      commandHistory.add(
        type: MessageHistoryType.send,
        message: bluetoothMessage.message,
      );

      if (!isDemoGear(device)) {
        if (bluetoothMessage.responseMSG != null) {
          _setState(CommandQueueState.waitingForResponse);
          _runningCommandTimer = Timer(timeoutDuration, _onTimeout);
        }
        await sendMessage(
          device,
          const Utf8Encoder().convert(bluetoothMessage.message),
        );
        if (bluetoothMessage.responseMSG == null) {
          _endCommand(); // end the current command if no reason to wait
        }
      } else {
        _endCommand(); // end the current command if demo gear
      }
    }
  }

  void addCommand(BluetoothMessage bluetoothMessage) {
    // Don't add commands to disconnected or dev gear.
    if (device.deviceConnectionState.value != ConnectivityState.connected ||
        state == CommandQueueState.blocked) {
      return;
    }
    _logger.info("Adding command to queue $bluetoothMessage");

    // preempt queue if other direct commands exist. used for joystick
    if (bluetoothMessage.type == CommandType.direct) {
      _internalCommandQueue
          .toUnorderedList()
          .where(
            (element) =>
                [CommandType.move, CommandType.direct].contains(element.type),
          )
          .forEach(_internalCommandQueue.remove);
    }
    _internalCommandQueue.add(bluetoothMessage);
    // Start the queue is its stopped/idle
    if (state == CommandQueueState.empty) {
      _setState(CommandQueueState.idle);
    }
  }
}
