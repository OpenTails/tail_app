import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:circular_buffer/circular_buffer.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../../Bluetooth/bluetooth_manager.dart';
import '../../Bluetooth/bluetooth_manager_plus.dart';
import '../../Bluetooth/bluetooth_message.dart';
import '../../firmware_update.dart';
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
  slow,
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
          .where(
            (element) => element.baseDeviceDefinition.deviceType == this,
          )
          .map(
            (e) => e.baseStoredDevice.color,
          )
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

enum tailControlStatus { tailControl, legacy, unknown }

@freezed
class BluetoothUartService with _$BluetoothUartService {
  const factory BluetoothUartService({
    required String bleDeviceService,
    required String bleRxCharacteristic,
    required String bleTxCharacteristic,
  }) = _BluetoothUartService;
}

final List<BluetoothUartService> uartServices = const [
  BluetoothUartService(
    bleDeviceService: "3af2108b-d066-42da-a7d4-55648fa0a9b6",
    bleRxCharacteristic: "c6612b64-0087-4974-939e-68968ef294b0",
    bleTxCharacteristic: "5bfd6484-ddee-4723-bfe6-b653372bbfd6",
  ),
  BluetoothUartService(
    bleDeviceService: "927dee04-ddd4-4582-8e42-69dc9fbfae66",
    bleRxCharacteristic: "0b646a19-371e-4327-b169-9632d56c0e84",
    bleTxCharacteristic: "05e026d8-b395-4416-9f8a-c00d6c3781b9",
  ),
  // TailCoNTROL uuids
  BluetoothUartService(
    bleDeviceService: "19F8ADE2-D0C6-4C0A-912A-30601D9B3060",
    bleRxCharacteristic: "5E4D86AC-EF2F-466F-A857-8776D45FFBC2",
    bleTxCharacteristic: "567A99D6-A442-4AC0-B676-4993BF95F805",
  ),
];

@freezed
class BaseDeviceDefinition with _$BaseDeviceDefinition {
  const factory BaseDeviceDefinition({
    required String uuid,
    required String btName,
    required DeviceType deviceType,
    @Default("") String fwURL,
    Version? minVersion,
    @Default(false) bool unsupported,
  }) = _BaseDeviceDefinition;
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
  final ValueNotifier<tailControlStatus> isTailCoNTROL = ValueNotifier(tailControlStatus.unknown);

  late final Stream<String> rxCharacteristicStream;
  late final CommandQueue commandQueue;
  List<FlSpot> batlevels = [];
  Stopwatch stopWatch = Stopwatch();
  bool disableAutoConnect = false;
  bool forgetOnDisconnect = false;
  ValueNotifier<bool> mandatoryOtaRequired = ValueNotifier(false);
  final CircularBuffer<MessageHistoryEntry> messageHistory = CircularBuffer(50);

  BaseStatefulDevice(this.baseDeviceDefinition, this.baseStoredDevice) {
    commandQueue = CommandQueue(this);
    rxCharacteristicStream = flutterBluePlus.events.onCharacteristicReceived.asBroadcastStream().where((event) {
      return event.device.remoteId.str == baseStoredDevice.btMACAddress && bluetoothUartService.value != null && event.characteristic.characteristicUuid.str == bluetoothUartService.value!.bleRxCharacteristic;
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
      } else if (deviceConnectionState.value == ConnectivityState.connected) {
        // Add initial commands to the queue
        Future.delayed(const Duration(seconds: 2), () {
          commandQueue
            ..addCommand(BluetoothMessage(message: "VER", device: this, priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()))
            ..addCommand(BluetoothMessage(message: "HWVER", device: this, priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
        });
      }
    });
    batteryLevel.addListener(() {
      batlevels.add(FlSpot(stopWatch.elapsed.inSeconds.toDouble(), batteryLevel.value));
      batteryLow.value = batteryLevel.value < 20;
    });

    bluetoothUartService.addListener(
      () {
        if (bluetoothUartService.value == null) {
          isTailCoNTROL.value = tailControlStatus.unknown;
          return;
        }

        isTailCoNTROL.value = bluetoothUartService.value ==
                uartServices.firstWhere(
                  (element) => element.bleDeviceService == "19F8ADE2-D0C6-4C0A-912A-30601D9B3060",
                )
            ? tailControlStatus.tailControl
            : tailControlStatus.legacy;
      },
    );
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
  }
}

enum MessageHistoryType {
  send,
  receive,
}

@freezed
// TailControl only
class GearConfigInfo with _$GearConfigInfo {
  const GearConfigInfo._();

  const factory GearConfigInfo({
    @Default("") String ver,
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
    @Default("") String securityPasskey,
  }) = _GearConfigInfo;

  factory GearConfigInfo.fromGearString(String fwInput) {
    String values = fwInput;
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
      securityPasskey: securityPasskey,
    );
  }

  String toGearString() {
    return "$ver $minsToSleep $minsToNPM $minNPMPauseSec $maxNPMPauseSec $groupsNPM $servo1home $servo2home $listenModeNPMEnabled $listenModeResponseOnly $groupsLM $tiltModeNPMEnabled $tiltModeResponseOnly $disconnectedCountdownEnabled $homeOnAppPoweroff $conferenceModeEnabled $securityPasskey";
  }
}

@freezed
class MessageHistoryEntry with _$MessageHistoryEntry {
  const factory MessageHistoryEntry({
    required MessageHistoryType type,
    required String message,
  }) = _MessageHistoryEntry;
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

class CommandQueue {
  final PriorityQueue<BluetoothMessage> state = PriorityQueue();
  final BaseStatefulDevice device;

  CommandQueue(this.device);

  Stream<BluetoothMessage> messageQueueStream() async* {
    while (device.deviceConnectionState.value == ConnectivityState.connected) {
      // Limit the speed commands are processed
      await Future.delayed(const Duration(milliseconds: 100));
      // wait for
      if (state.isNotEmpty && device.deviceState.value == DeviceState.standby) {
        device.deviceState.value = DeviceState.runAction;
        yield state.removeFirst();
      }
    }
    state.clear(); // clear the queue on disconnect
    messageQueueStreamSubscription?.cancel();
    messageQueueStreamSubscription = null;
  }

  StreamSubscription<BluetoothMessage>? messageQueueStreamSubscription;

  void addCommand(BluetoothMessage bluetoothMessage) {
    bluetoothLog.info("Adding commands to queue $bluetoothMessage");
    if (device.deviceConnectionState.value != ConnectivityState.connected || device.baseStoredDevice.btMACAddress.startsWith("DEV")) {
      device.deviceState.value = DeviceState.standby; //Mainly for dev gear. Marks the gear as being idle
      return;
    }
    messageQueueStreamSubscription ??= messageQueueStream().listen((message) async {
      //TODO: Resend on busy
      if (message.delay == null) {
        try {
          bluetoothLog.fine("Sending command to ${device.baseStoredDevice.name}:${message.message}");
          Future<String?>? response;
          //Start listening before the response is received
          Duration timeoutDuration = const Duration(seconds: 10);
          Timer? timer;
          if (message.responseMSG != null) {
            // We use a timeout as sometimes a response isn't sent by the gear
            timer = Timer(timeoutDuration, () {});
            response = device.rxCharacteristicStream
                .timeout(
                  timeoutDuration,
                  onTimeout: (sink) {
                    sink.addError("");
                  },
                )
                .where((event) {
                  bluetoothLog.info('Response:$event');
                  return event.contains(message.responseMSG!);
                })
                .handleError((string) => "")
                .first
              ..catchError((string) => "");
          }
          await sendMessage(device, const Utf8Encoder().convert(message.message));
          device.messageHistory.add(MessageHistoryEntry(type: MessageHistoryType.send, message: message.message));
          if (message.onCommandSent != null) {
            // Callback when the specific command is run
            message.onCommandSent!();
          }
          try {
            if (message.responseMSG != null) {
              bluetoothLog.fine("Waiting for response from ${device.baseStoredDevice.name}:${message.responseMSG}");

              // Handles response value
              response!.then(
                (value) {
                  timer?.cancel();
                  if (message.onResponseReceived != null) {
                    //callback when the command response is received
                    message.onResponseReceived!(value!);
                  }
                },
                onError: (e) => "",
              );
              response.timeout(
                timeoutDuration,
                onTimeout: () {
                  bluetoothLog.warning("Timed out waiting for response from ${device.baseStoredDevice.name}:${message.responseMSG}");
                  return "";
                },
              );
              while (timer!.isActive) {
                //allow higher priority commands to interrupt waiting for a response
                if (state.isNotEmpty && state.first.priority.index > message.priority.index) {
                  timer.cancel();
                }
                await Future.delayed(const Duration(milliseconds: 100)); // Prevent the loop from consuming too many resources
              }
              bluetoothLog.fine("Finished waiting for response from ${device.baseStoredDevice.name}:${message.responseMSG}");
            }
          } catch (e, s) {
            bluetoothLog.warning('Command timed out or threw error: $e', e, s);
          }
        } catch (e, s) {
          Sentry.captureException(e, stackTrace: s);
        }
      } else {
        bluetoothLog.fine("Pausing queue for ${device.baseStoredDevice.name}");
        Timer timer = Timer(Duration(milliseconds: message.delay!.toInt() * 20), () {});
        while (timer.isActive) {
          //allow higher priority commands to interrupt the delay
          if (state.isNotEmpty && state.first.priority.index > message.priority.index) {
            //timer.cancel();
          }
          await Future.delayed(const Duration(milliseconds: 50)); // Prevent the loop from consuming too many resources
        }
        bluetoothLog.fine("Resuming queue for ${device.baseStoredDevice.name}");
      }
      device.deviceState.value = DeviceState.standby; //Without setting state to standby, another command can not run
    });
    // preempt queue
    if (bluetoothMessage.type == CommandType.direct) {
      state.toUnorderedList().where((element) => [CommandType.move, CommandType.direct].contains(element.type)).forEach(state.remove);
    }
    state.add(bluetoothMessage);
  }
}
