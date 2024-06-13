import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:circular_buffer/circular_buffer.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../../../Frontend/utils.dart';
import '../../Bluetooth/bluetooth_manager.dart';
import '../../Bluetooth/bluetooth_manager_plus.dart';
import '../../Bluetooth/bluetooth_message.dart';
import '../../firmware_update.dart';

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

@freezed
class BaseDeviceDefinition with _$BaseDeviceDefinition {
  const factory BaseDeviceDefinition({
    required String uuid,
    required String btName,
    required String bleDeviceService,
    required String bleRxCharacteristic,
    required String bleTxCharacteristic,
    required DeviceType deviceType,
    @Default("") String fwURL,
    Version? minVersion,
    @Default(false) bool unsupported,
  }) = _BaseDeviceDefinition;
}

// data that represents the current state of a device
class BaseStatefulDevice extends ChangeNotifier {
  final BaseDeviceDefinition baseDeviceDefinition;
  final BaseStoredDevice baseStoredDevice;
  final ValueNotifier<double> batteryLevel = ValueNotifier(-1);
  final ValueNotifier<bool> batteryCharging = ValueNotifier(false);
  final ValueNotifier<bool> batteryLow = ValueNotifier(false);
  final ValueNotifier<bool> gearReturnedError = ValueNotifier(false);

  final ValueNotifier<Version> fwVersion = ValueNotifier(Version.none);
  final ValueNotifier<String> hwVersion = ValueNotifier("");
  final ValueNotifier<GlowtipStatus> hasGlowtip = ValueNotifier(GlowtipStatus.unknown);
  final ValueNotifier<DeviceState> deviceState = ValueNotifier(DeviceState.standby);
  final ValueNotifier<ConnectivityState> deviceConnectionState = ValueNotifier(ConnectivityState.disconnected);
  final ValueNotifier<int> rssi = ValueNotifier(-1);
  final ValueNotifier<int> mtu = ValueNotifier(-1);

  final ValueNotifier<FWInfo?> fwInfo = ValueNotifier(null);
  final ValueNotifier<bool> hasUpdate = ValueNotifier(false);
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
    rxCharacteristicStream = flutterBluePlus.events.onCharacteristicReceived.asBroadcastStream().where((event) => event.device.remoteId.str == baseStoredDevice.btMACAddress && event.characteristic.characteristicUuid.str == baseDeviceDefinition.bleRxCharacteristic).map((event) {
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
    fwInfo.addListener(() {
      if (fwInfo.value != null && fwVersion.value.compareTo(Version.none) > 0 && fwVersion.value.compareTo(getVersionSemVer(fwInfo.value!.version)) < 0) {
        hasUpdate.value = true;
      }
    });
    fwVersion.addListener(() {
      if (baseDeviceDefinition.minVersion != null && fwVersion.value.compareTo(baseDeviceDefinition.minVersion!) < 0) {
        mandatoryOtaRequired.value = true;
      }
      if (fwInfo.value != null && fwVersion.value.compareTo(Version.none) > 0 && fwVersion.value.compareTo(getVersionSemVer(fwInfo.value!.version)) < 0) {
        hasUpdate.value = true;
      }
    });
    getFirmwareInfo();
  }

  @override
  String toString() {
    return 'BaseStatefulDevice{baseDeviceDefinition: $baseDeviceDefinition, baseStoredDevice: $baseStoredDevice, battery: $batteryLevel}';
  }

  Future<void> getFirmwareInfo() async {
    // Try to get firmware update information from Tail Company site
    if (baseDeviceDefinition.fwURL != "" && fwInfo.value == null) {
      Future<Response<String>> valueFuture = (await initDio()).get(baseDeviceDefinition.fwURL, options: Options(responseType: ResponseType.json))
        ..onError((error, stackTrace) {
          bluetoothLog.warning("Unable to get Firmware info for ${baseDeviceDefinition.fwURL} :$error", error, stackTrace);
          return Response(requestOptions: RequestOptions(), statusCode: 500);
        });
      Response<String> value = await valueFuture;
      if (value.statusCode == 200) {
        fwInfo.value = FWInfo.fromJson(const JsonDecoder().convert(value.data.toString()));
      }
    }
  }

  void reset() {
    batteryLevel.value = -1;
    batteryCharging.value = false;
    batteryLow.value = false;
    gearReturnedError.value = false;
    deviceState.value = DeviceState.standby;
    rssi.value = -1;
    hasUpdate.value = false;
    fwVersion.value = Version.none;
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
      state.toUnorderedList().where((element) => [CommandType.move, CommandType.direct].contains(element.type)).forEach((element) => state.remove(element));
    }
    state.add(bluetoothMessage);
  }
}
