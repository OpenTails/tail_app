import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/command_history.dart';

import 'Bluetooth/bluetooth_message.dart';
import 'Definitions/Device/device_definition.dart';

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
  final PriorityQueue<BluetoothMessage> _internalCommandQueue = PriorityQueue();
  late final BaseStatefulDevice _device;
  Duration timeoutDuration = const Duration(seconds: 10);
  Timer? _runningCommandTimer;
  BluetoothMessage? currentMessage;
  CommandHistory commandHistory = CommandHistory();

  List<BluetoothMessage> get queue => _internalCommandQueue.toList();

  CommandQueue(BaseStatefulDevice device) {
    _device = device;
    device.deviceConnectionState.addListener(_connectionStateListener);
    device.gearReturnedError.addListener(_gearErrorListener);
    device.deviceState.addListener(_deviceStateListener);
    device.rxCharacteristicStream.asBroadcastStream().listen(_bluetoothResponseListener);
    addListener(_onStateChanged);
  }

  CommandQueueState get state => _state;
  CommandQueueState _state = CommandQueueState.empty;

  void _setState(CommandQueueState state) {
    if (_internalCommandQueue.isEmpty && state == CommandQueueState.idle) {
      _state = CommandQueueState.empty;
    } else {
      _state = state;
    }
    notifyListeners();
  }

  void _connectionStateListener() {
    if (_device.deviceConnectionState.value != ConnectivityState.connected) {
      _internalCommandQueue.clear(); // clear the queue on disconnect
      stopQueue();
    } else {
      startQueue();
    }
  }

  /// Used to listen for a response if one is set in [BluetoothMessage].responseMSG
  void _bluetoothResponseListener(String msg) {
    if (state == CommandQueueState.waitingForResponse && currentMessage != null && currentMessage!.responseMSG != null) {
      if (msg == currentMessage!.responseMSG!) {
        _setState(CommandQueueState.idle);
      }
    }
  }

  /// Called when a delay command ends or after 10 seconds
  void _onTimeout() {
    currentMessage == null;
    _runningCommandTimer == null;
    if ([CommandQueueState.delay, CommandQueueState.waitingForResponse, CommandQueueState.running].contains(state)) {
      _setState(CommandQueueState.idle);
    }
  }

  /// Trigger resending the current command if the gear returns ERR/BUSY
  void _gearErrorListener() {
    if (_device.gearReturnedError.value && [CommandQueueState.delay, CommandQueueState.waitingForResponse].contains(state)) {
      _device.gearReturnedError.value = false;
      _resendCommand();
    }
  }

  void _resendCommand() {
    if (currentMessage != null) {
      bluetoothLog.warning("Resending message for ${_device.baseStoredDevice.name} $currentMessage");
      addCommand(currentMessage!);
      _onTimeout(); //abort waiting for the command to finish
    }
  }

  void _deviceStateListener() {
    if (state == CommandQueueState.blocked && _device.deviceState.value == DeviceState.standby) {
      startQueue();
    } else if (state != CommandQueueState.blocked && _device.deviceState.value == DeviceState.busy) {
      stopQueue();
    }
  }

  /// Stops the queue and aborts waiting for the next command;
  void stopQueue() {
    bluetoothLog.fine("Stopping queue for ${_device.baseStoredDevice.name}");
    _setState(CommandQueueState.blocked);
    _runningCommandTimer?.cancel();
    _runningCommandTimer = null;
    currentMessage = null;
  }

  void startQueue() {
    bluetoothLog.fine("Starting queue for ${_device.baseStoredDevice.name}");
    _setState(CommandQueueState.idle);
  }

  /// Handles running the next command and marking gear as busy/idle
  void _onStateChanged() {
    switch (state) {
      case CommandQueueState.running:
      case CommandQueueState.waitingForResponse:
      case CommandQueueState.delay:
        _device.deviceState.value = DeviceState.runAction;
        break;
      case CommandQueueState.blocked:
        _device.deviceState.value = DeviceState.busy;
        break;
      case CommandQueueState.idle:
        if (_internalCommandQueue.isEmpty) {
          _setState(CommandQueueState.empty);
        } else {
          Future(() => runCommand(_internalCommandQueue.removeFirst()));
        }
        break;
      case CommandQueueState.empty:
        _device.deviceState.value = DeviceState.standby;
        break;
    }
  }

  Future<void> runCommand(BluetoothMessage bluetoothMessage) async {
    currentMessage = bluetoothMessage;
    _setState(CommandQueueState.running);
    _device.gearReturnedError.value = false;

    // handle if the command is a delay command
    if (bluetoothMessage.delay != null) {
      bluetoothLog.fine("Pausing queue for ${_device.baseStoredDevice.name}");
      _runningCommandTimer = Timer(Duration(milliseconds: bluetoothMessage.delay!.toInt() * 20), _onTimeout);
      _setState(CommandQueueState.delay);
    } else {
      bluetoothLog.fine("Sending command to ${_device.baseStoredDevice.name}:${bluetoothMessage.message}");
      commandHistory.add(type: MessageHistoryType.send, message: bluetoothMessage.message);

      // skip delay for dev gear but still add the command to the queue
      if (bluetoothMessage.responseMSG != null && !_device.baseStoredDevice.btMACAddress.startsWith("DEV")) {
        _setState(CommandQueueState.waitingForResponse);
        _runningCommandTimer = Timer(timeoutDuration, _onTimeout);
      }
      await sendMessage(_device, const Utf8Encoder().convert(bluetoothMessage.message));
      if (bluetoothMessage.responseMSG == null) {
        _onTimeout(); // end the current command if no reason to wait
      }
    }
  }

  void addCommand(BluetoothMessage bluetoothMessage) {
    // Don't add commands to disconnected or dev gear.
    if (_device.deviceConnectionState.value != ConnectivityState.connected || state == CommandQueueState.blocked) {
      return;
    }
    bluetoothLog.info("Adding command to queue $bluetoothMessage");

    // preempt queue if other direct commands exist. used for joystick
    if (bluetoothMessage.type == CommandType.direct) {
      _internalCommandQueue.toUnorderedList().where((element) => [CommandType.move, CommandType.direct].contains(element.type)).forEach(_internalCommandQueue.remove);
    }
    _internalCommandQueue.add(bluetoothMessage);
    // Start the queue is its stopped/idle
    if (state == CommandQueueState.empty) {
      _setState(CommandQueueState.idle);
    }
  }
}
