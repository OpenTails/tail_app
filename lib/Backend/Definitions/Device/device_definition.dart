import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:circular_buffer/circular_buffer.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../../../constants.dart';
import '../../Bluetooth/bluetooth_manager.dart';
import '../../Bluetooth/bluetooth_manager_plus.dart';
import '../../Bluetooth/bluetooth_message.dart';
import '../../firmware_update.dart';
import '../../logging_wrappers.dart';
import '../../version.dart';

part 'device_definition.freezed.dart';

part 'device_definition.g.dart';

@HiveType(typeId: 6)
enum DeviceType {
  @HiveField(1)
  tail,
  @HiveField(2)
  ears,
  @HiveField(3)
  wings,
  @HiveField(4)
  miniTail
} //TODO extend with icon

@HiveType(typeId: 14)
enum EarSpeed {
  @HiveField(1)
  fast,
  @HiveField(2)
  slow
}

extension EarSpeedExtension on EarSpeed {
  String get name {
    switch (this) {
      case EarSpeed.fast:
        return earSpeedFast();
      case EarSpeed.slow:
        return earSpeedSlow();
    }
  }

  Widget get icon {
    switch (this) {
      case EarSpeed.fast:
        return const Icon(Icons.fast_forward);
      case EarSpeed.slow:
        return const Icon(Icons.play_arrow);
    }
  }

  String get command {
    switch (this) {
      case EarSpeed.fast:
        return "SPEED FAST";
      case EarSpeed.slow:
        return "SPEED SLOW";
    }
  }
}

extension DeviceTypeExtension on DeviceType {
  String get name {
    switch (this) {
      case DeviceType.tail:
        return deviceTypeTail();
      case DeviceType.ears:
        return deviceTypeEars();
      case DeviceType.wings:
        return deviceTypeWings();
      case DeviceType.miniTail:
        return deviceTypeMiniTail();
    }
  }

  Color color({Object? ref}) {
    if (ref != null && (ref is WidgetRef || ref is Ref)) {
      Iterable<BaseStatefulDevice> knownDevices = [];
      if (ref is WidgetRef) {
        knownDevices = ref.read(knownDevicesProvider).values;
      } else if (ref is Ref) {
        knownDevices = ref.read(knownDevicesProvider).values;
      }
      int? color = knownDevices
          .where((element) => element.baseDeviceDefinition.deviceType == this)
          .map((e) => e.baseStoredDevice.color)
          .firstOrNull;
      if (color != null) {
        return Color(color);
      }
    }
    switch (this) {
      case DeviceType.tail:
        return Colors.orangeAccent;
      case DeviceType.miniTail:
        return Colors.redAccent;
      case DeviceType.ears:
        return Colors.blueAccent;
      case DeviceType.wings:
        return Colors.greenAccent;
    }
  }
}

enum ConnectivityState { connected, disconnected, connecting }

enum DeviceState { standby, runAction, busy }

enum GlowtipStatus { glowtip, noGlowtip, unknown }

enum TailControlStatus { tailControl, legacy, unknown }

@freezed
abstract class BluetoothUartService with _$BluetoothUartService {
  const factory BluetoothUartService(
      {required String bleDeviceService,
      required String bleRxCharacteristic,
      required String bleTxCharacteristic,
      required String label}) = _BluetoothUartService;
}

final List<BluetoothUartService> uartServices = const [
  BluetoothUartService(
      bleDeviceService: "3af2108b-d066-42da-a7d4-55648fa0a9b6",
      bleRxCharacteristic: "c6612b64-0087-4974-939e-68968ef294b0",
      bleTxCharacteristic: "5bfd6484-ddee-4723-bfe6-b653372bbfd6",
      label: "Legacy Gear"),
  BluetoothUartService(
      bleDeviceService: "0000ffe0-0000-1000-8000-00805f9b34fb",
      bleRxCharacteristic: "",
      bleTxCharacteristic: "0000ffe1-0000-1000-8000-00805f9b34fb",
      label: "DigiTail"),
  BluetoothUartService(
      bleDeviceService: "927dee04-ddd4-4582-8e42-69dc9fbfae66",
      bleRxCharacteristic: "0b646a19-371e-4327-b169-9632d56c0e84",
      bleTxCharacteristic: "05e026d8-b395-4416-9f8a-c00d6c3781b9",
      label: "Legacy Ears"),
  // TailCoNTROL uuids
  BluetoothUartService(
      bleDeviceService: "19f8ade2-d0c6-4c0a-912a-30601d9b3060",
      bleRxCharacteristic: "567a99d6-a442-4ac0-b676-4993bf95f805",
      bleTxCharacteristic: "5e4d86ac-ef2f-466f-a857-8776d45ffbc2",
      label: "TailCoNTROL")
];

@freezed
abstract class BaseDeviceDefinition with _$BaseDeviceDefinition {
  const factory BaseDeviceDefinition(
      {required String uuid,
      required String btName,
      required DeviceType deviceType,
      @Default("") String fwURL,
      Version? minVersion,
      @Default(false) bool unsupported}) = _BaseDeviceDefinition;
}

// data that represents the current state of a device
class BaseStatefulDevice {
  final BaseDeviceDefinition baseDeviceDefinition;
  final BaseStoredDevice baseStoredDevice;
  final ValueNotifier<BluetoothUartService?> bluetoothUartService = ValueNotifier(null);
  final ValueNotifier<double> batteryLevel = ValueNotifier(-1);
  final ValueNotifier<bool> batteryCharging = ValueNotifier(false);
  final ValueNotifier<bool> batteryLow = ValueNotifier(false);
  final ValueNotifier<bool> gearReturnedError = ValueNotifier(false);
  final ValueNotifier<Version> fwVersion = ValueNotifier(const Version());
  final ValueNotifier<String> hwVersion = ValueNotifier("");
  final ValueNotifier<GlowtipStatus> hasGlowtip = ValueNotifier(GlowtipStatus.unknown);
  final ValueNotifier<DeviceState> deviceState = ValueNotifier(DeviceState.standby);
  final ValueNotifier<ConnectivityState> deviceConnectionState = ValueNotifier(ConnectivityState.disconnected);
  final ValueNotifier<int> rssi = ValueNotifier(-1);
  final ValueNotifier<int> mtu = ValueNotifier(-1);
  final ValueNotifier<GearConfigInfo> gearConfigInfo = ValueNotifier(GearConfigInfo());
  final ValueNotifier<FWInfo?> fwInfo = ValueNotifier(null);
  final ValueNotifier<bool> hasUpdate = ValueNotifier(false);
  final ValueNotifier<TailControlStatus> isTailCoNTROL = ValueNotifier(TailControlStatus.unknown);

  late final Stream<String> rxCharacteristicStream;
  List<FlSpot> batlevels = [];
  Stopwatch stopWatch = Stopwatch();
  bool disableAutoConnect = false;
  bool forgetOnDisconnect = false;
  ValueNotifier<bool> mandatoryOtaRequired = ValueNotifier(false);
  final CircularBuffer<MessageHistoryEntry> messageHistory = CircularBuffer(50);
  Timer? deviceStateWatchdogTimer;

  BaseStatefulDevice(this.baseDeviceDefinition, this.baseStoredDevice) {
    rxCharacteristicStream = flutterBluePlus.events.onCharacteristicReceived.asBroadcastStream().where((event) {
      return event.device.remoteId.str == baseStoredDevice.btMACAddress &&
          bluetoothUartService.value != null &&
          event.characteristic.characteristicUuid.str == bluetoothUartService.value!.bleRxCharacteristic;
    }).map((event) {
      try {
        return const Utf8Decoder().convert(event.value);
      } catch (e) {
        bluetoothLog.warning("Unable to read values: ${event.value} $e");
      }
      return "";
    }).where((event) => event.isNotEmpty);

    deviceConnectionState.addListener(() {
      if (deviceConnectionState.value == ConnectivityState.disconnected) {
        reset();
      }
    });
    batteryLevel.addListener(() {
      batlevels.add(FlSpot(stopWatch.elapsed.inSeconds.toDouble(), batteryLevel.value));
      batteryLow.value = batteryLevel.value < 20;
    });

    bluetoothUartService.addListener(() {
      if (bluetoothUartService.value == null) {
        isTailCoNTROL.value = TailControlStatus.unknown;
        return;
      }

      isTailCoNTROL.value = bluetoothUartService.value ==
              uartServices.firstWhere(
                  (element) => element.bleDeviceService.toLowerCase() == "19f8ade2-d0c6-4c0a-912a-30601d9b3060")
          ? TailControlStatus.tailControl
          : TailControlStatus.legacy;
    });
    // prevent gear from being stuck in a move.
    deviceState.addListener(() {
      if (deviceState.value == DeviceState.runAction && deviceStateWatchdogTimer == null) {
        deviceStateWatchdogTimer = Timer(
            Duration(
                seconds:
                    HiveProxy.getOrDefault(settings, triggerActionCooldown, defaultValue: triggerActionCooldownDefault)),
            () {
          deviceState.value = DeviceState.standby;
        });
      } else if (deviceState.value != DeviceState.runAction && deviceStateWatchdogTimer != null) {
        deviceStateWatchdogTimer?.cancel();
        deviceStateWatchdogTimer = null;
      }
    });
  }

  @override
  String toString() {
    return 'BaseStatefulDevice{baseDeviceDefinition: $baseDeviceDefinition, baseStoredDevice: $baseStoredDevice, battery: $batteryLevel}';
  }

  void reset() {
    batteryLevel.value = -1;
    batteryCharging.value = false;
    batteryLow.value = false;
    gearReturnedError.value = false;
    deviceState.value = DeviceState.standby;
    rssi.value = -1;
    hasUpdate.value = false;
    fwVersion.value = const Version();
    batlevels = [];
    stopWatch.reset();
    mtu.value = -1;
    mandatoryOtaRequired.value = false;
    isTailCoNTROL.value = TailControlStatus.unknown;
    bluetoothUartService.value = null;
  }
}

enum MessageHistoryType { send, receive }

@freezed
// TailControl only
abstract class GearConfigInfo with _$GearConfigInfo {
  const GearConfigInfo._();

  const factory GearConfigInfo(
      {@Default("") String ver,
      @Default("") String minsToSleep,
      @Default("") String minsToNPM,
      @Default("") String minNPMPauseSec,
      @Default("") String maxNPMPauseSec,
      @Default("") String groupsNPM,
      @Default("") String servo1home,
      @Default("") String servo2home,
      @Default("") String listenModeNPMEnabled,
      @Default("") String listenModeResponseOnly,
      @Default("") String groupsLM,
      @Default("") String tiltModeNPMEnabled,
      @Default("") String tiltModeResponseOnly,
      @Default("") String disconnectedCountdownEnabled,
      @Default("") String homeOnAppPoweroff,
      @Default("") String conferenceModeEnabled,
      @Default("") String securityPasskey}) = _GearConfigInfo;

  factory GearConfigInfo.fromGearString(String fwInput) {
    List<String> values = fwInput.split(" ");
    String ver = values[0];
    String minsToSleep = values[1];
    String minsToNPM = values[2];
    String minNPMPauseSec = values[3];
    String maxNPMPauseSec = values[4];
    String groupsNPM = values[5];
    String servo1home = values[6];
    String servo2home = values[7];
    String listenModeNPMEnabled = values[8];
    String listenModeResponseOnly = values[9];
    String groupsLM = values[10];
    String tiltModeNPMEnabled = values[11];
    String tiltModeResponseOnly = values[12];
    String disconnectedCountdownEnabled = values[13];
    String homeOnAppPoweroff = values[14];
    String conferenceModeEnabled = values[15];
    String securityPasskey = values[16];

    return GearConfigInfo(
        ver: ver,
        minsToSleep: minsToSleep,
        minsToNPM: minsToNPM,
        minNPMPauseSec: minNPMPauseSec,
        maxNPMPauseSec: maxNPMPauseSec,
        groupsNPM: groupsNPM,
        servo1home: servo1home,
        servo2home: servo2home,
        listenModeNPMEnabled: listenModeNPMEnabled,
        listenModeResponseOnly: listenModeResponseOnly,
        groupsLM: groupsLM,
        tiltModeNPMEnabled: tiltModeNPMEnabled,
        tiltModeResponseOnly: tiltModeResponseOnly,
        disconnectedCountdownEnabled: disconnectedCountdownEnabled,
        homeOnAppPoweroff: homeOnAppPoweroff,
        conferenceModeEnabled: conferenceModeEnabled,
        securityPasskey: securityPasskey);
  }

  String toGearString() {
    return "$ver $minsToSleep $minsToNPM $minNPMPauseSec $maxNPMPauseSec $groupsNPM $servo1home $servo2home $listenModeNPMEnabled $listenModeResponseOnly $groupsLM $tiltModeNPMEnabled $tiltModeResponseOnly $disconnectedCountdownEnabled $homeOnAppPoweroff $conferenceModeEnabled $securityPasskey";
  }
}

@freezed
abstract class MessageHistoryEntry with _$MessageHistoryEntry {
  const factory MessageHistoryEntry({required MessageHistoryType type, required String message}) = _MessageHistoryEntry;
}

// All serialized/stored data
@HiveType(typeId: 1)
class BaseStoredDevice extends ChangeNotifier {
  @HiveField(0)
  String name = "New Gear";
  @HiveField(7)
  final String btMACAddress;
  @HiveField(8)
  final String deviceDefinitionUUID;
  @HiveField(9)
  int _color;

  @HiveField(10, defaultValue: 1)
  int leftHomePosition = 1;
  @HiveField(11, defaultValue: 1)
  int rightHomePosition = 1;
  @HiveField(12, defaultValue: "")
  String conModePin = "";
  @HiveField(13, defaultValue: false)
  bool conModeEnabled = false;

  int get color => _color;

  set color(int value) {
    _color = value;
    notifyListeners();
  }

  BaseStoredDevice(this.deviceDefinitionUUID, this.btMACAddress, this._color);

  @override
  String toString() {
    return 'BaseStoredDevice{name: $name, btMACAddress: $btMACAddress, deviceDefinitionUUID: $deviceDefinitionUUID}';
  }
}

String getNameFromBTName(String bluetoothDeviceName) {
  switch (bluetoothDeviceName) {
    case 'EarGear':
      return 'EarGear';
    case 'EG2':
      return 'EarGear 2';
    case 'mitail':
      return 'MiTail';
    case 'minitail':
      return 'MiTail Mini';
    case 'flutter':
      return 'FlutterWings';
    case '(!)Tail1':
      return 'DigiTail';
  }
  return bluetoothDeviceName;
}

enum CommandQueueState {
  running,

  /// A command is in progress
  waitingForResponse,
  delay, // The queue is momentarily paused
  blocked, // the queue is stopped
  idle, // inbetween moves
  empty // the queue is empty
}

@Riverpod(keepAlive: true)
class CommandQueue extends _$CommandQueue {
  final PriorityQueue<BluetoothMessage> _commandQueue = PriorityQueue();
  late final BaseStatefulDevice _device;
  Duration timeoutDuration = const Duration(seconds: 10);
  Timer? _runningCommandTimer;
  BluetoothMessage? currentMessage;
  StreamSubscription<String>? _rxCharacteristicStreamSubscription;
  get queue => _commandQueue.toList();
  @override
  CommandQueueState build(BaseStatefulDevice device) {
    _device = device;
    device.deviceConnectionState.addListener(_connectionStateListener);
    device.gearReturnedError.addListener(_gearErrorListener);
    device.deviceState.addListener(_deviceStateListener);

    _rxCharacteristicStreamSubscription =
        device.rxCharacteristicStream.asBroadcastStream().listen(_bluetoothResponseListener);
    listenSelf(_onStateChanged);
    ref.onDispose(() {
      device.deviceConnectionState.removeListener(_connectionStateListener);
      device.gearReturnedError.removeListener(_gearErrorListener);
      device.deviceState.removeListener(_deviceStateListener);
      _rxCharacteristicStreamSubscription?.cancel();
      _rxCharacteristicStreamSubscription = null;
    });
    return CommandQueueState.empty;
  }

  void _connectionStateListener() {
    if (_device.deviceConnectionState.value != ConnectivityState.connected) {
      _commandQueue.clear(); // clear the queue on disconnect
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
    if (_device.gearReturnedError.value &&
        [CommandQueueState.delay, CommandQueueState.waitingForResponse].contains(state)) {
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
  void _onStateChanged(CommandQueueState? previous, CommandQueueState next) {
    switch (next) {
      case CommandQueueState.running:
      case CommandQueueState.waitingForResponse:
      case CommandQueueState.delay:
        _device.deviceState.value = DeviceState.runAction;
        break;
      case CommandQueueState.blocked:
        _device.deviceState.value = DeviceState.busy;
        break;
      case CommandQueueState.idle:
        if (_commandQueue.isEmpty) {
          _setState(CommandQueueState.empty);
        } else {
          runCommand(_commandQueue.removeFirst());
        }
        break;
      case CommandQueueState.empty:
        _device.deviceState.value = DeviceState.standby;
        break;
    }
  }

  void _setState(CommandQueueState state) {
    if (_commandQueue.isEmpty && state == CommandQueueState.idle) {
      _setState(CommandQueueState.empty);
    } else {
      this.state = state;
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
      _device.messageHistory.add(MessageHistoryEntry(type: MessageHistoryType.send, message: bluetoothMessage.message));
      if (bluetoothMessage.responseMSG != null) {
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
    if (_device.deviceConnectionState.value != ConnectivityState.connected ||
        _device.baseStoredDevice.btMACAddress.startsWith("DEV") ||
        state == CommandQueueState.blocked) {
      return;
    }
    bluetoothLog.info("Adding command to queue $bluetoothMessage");

    // preempt queue if other direct commands exist. used for joystick
    if (bluetoothMessage.type == CommandType.direct) {
      _commandQueue
          .toUnorderedList()
          .where((element) => [CommandType.move, CommandType.direct].contains(element.type))
          .forEach(_commandQueue.remove);
    }
    _commandQueue.add(bluetoothMessage);
    // Start the queue is its stopped/idle
    if (state == CommandQueueState.empty) {
      _setState(CommandQueueState.idle);
    }
  }
}
