import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:circular_buffer/circular_buffer.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/firmware_update.dart';

import '../../../Frontend/intn_defs.dart';
import '../../../Frontend/utils.dart';
import '../../Bluetooth/bluetooth_message.dart';
import '../../auto_move.dart';

part 'device_definition.g.dart';

@HiveType(typeId: 6)
enum DeviceType {
  @HiveField(1)
  tail,
  @HiveField(2)
  ears,
  @HiveField(3)
  wings,
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
    }
  }

  Color get color {
    switch (this) {
      case DeviceType.tail:
        return Colors.orangeAccent;
      case DeviceType.ears:
        return Colors.blueAccent;
      case DeviceType.wings:
        return Colors.greenAccent;
    }
  }
}

enum ConnectivityState { connected, disconnected, connecting }

enum DeviceState { standby, runAction, busy }

class BaseDeviceDefinition {
  final String uuid;
  final String btName;
  final String bleDeviceService;
  final String bleRxCharacteristic;
  final String bleTxCharacteristic;
  final DeviceType deviceType;
  final String fwURL;

  const BaseDeviceDefinition(this.uuid, this.btName, this.bleDeviceService, this.bleRxCharacteristic, this.bleTxCharacteristic, this.deviceType, this.fwURL);

  @override
  String toString() {
    return 'BaseDeviceDefinition{btName: $btName, deviceType: $deviceType}';
  }
}

// data that represents the current state of a device
class BaseStatefulDevice extends ChangeNotifier {
  final BaseDeviceDefinition baseDeviceDefinition;
  final BaseStoredDevice baseStoredDevice;
  final ValueNotifier<double> batteryLevel = ValueNotifier(-1);
  final ValueNotifier<bool> batteryCharging = ValueNotifier(false);
  final ValueNotifier<bool> batteryLow = ValueNotifier(false);
  final ValueNotifier<bool> gearReturnedError = ValueNotifier(false);

  final ValueNotifier<String> fwVersion = ValueNotifier("");
  final ValueNotifier<String> hwVersion = ValueNotifier("");
  final ValueNotifier<bool> hasGlowtip = ValueNotifier(false);
  final ValueNotifier<DeviceState> deviceState = ValueNotifier(DeviceState.standby);
  final ValueNotifier<ConnectivityState> deviceConnectionState = ValueNotifier(ConnectivityState.disconnected);
  final ValueNotifier<int> rssi = ValueNotifier(-1);
  final ValueNotifier<int> mtu = ValueNotifier(-1);

  final ValueNotifier<FWInfo?> fwInfo = ValueNotifier(null);
  final ValueNotifier<bool> hasUpdate = ValueNotifier(false);
  late final Stream<String> rxCharacteristicStream;
  Ref? ref;
  late final CommandQueue commandQueue;
  List<FlSpot> batlevels = [];
  Stopwatch stopWatch = Stopwatch();
  bool disableAutoConnect = false;
  bool forgetOnDisconnect = false;

  final CircularBuffer<MessageHistoryEntry> messageHistory = CircularBuffer(50);

  BaseStatefulDevice(this.baseDeviceDefinition, this.baseStoredDevice, this.ref) {
    commandQueue = CommandQueue(ref, this);
    rxCharacteristicStream = FlutterBluePlus.events.onCharacteristicReceived
        .asBroadcastStream()
        .where((event) => event.device.remoteId.str == baseStoredDevice.btMACAddress && event.characteristic.characteristicUuid.str == baseDeviceDefinition.bleRxCharacteristic)
        .map((event) => const Utf8Decoder().convert(event.value));
    deviceConnectionState.addListener(() {
      if (deviceConnectionState.value == ConnectivityState.disconnected) {
        reset();
      } else if (deviceConnectionState.value == ConnectivityState.connected) {
        // Add initial commands to the queue
        Future.delayed(const Duration(seconds: 5), () {
          commandQueue.addCommand(BluetoothMessage(message: "VER", device: this, priority: Priority.low, type: Type.system, responseMSG: "VER "));
          commandQueue.addCommand(BluetoothMessage(message: "HWVER", device: this, priority: Priority.low, type: Type.system, responseMSG: "HWVER "));
          if (baseStoredDevice.autoMove) {
            changeAutoMove(this);
          }
        });
      }
    });
    batteryLevel.addListener(() {
      batlevels.add(FlSpot(stopWatch.elapsed.inSeconds.toDouble(), batteryLevel.value));
      batteryLow.value = batteryLevel.value < 20;
    });
    fwInfo.addListener(() {
      if (fwInfo.value != null) {
        if (fwInfo.value?.version.split(" ")[1] != fwVersion.value) {
          hasUpdate.value = true;
        }
      }
    });
    getFirmwareInfo();
  }

  @override
  String toString() {
    return 'BaseStatefulDevice{baseDeviceDefinition: $baseDeviceDefinition, baseStoredDevice: $baseStoredDevice, battery: $batteryLevel}';
  }

  void getFirmwareInfo() {
    // Try to get firmware update information from Tail Company site
    if (baseDeviceDefinition.fwURL != "" && fwInfo.value == null) {
      initDio().get(baseDeviceDefinition.fwURL, options: Options(responseType: ResponseType.json)).then(
        (value) {
          if (value.statusCode == 200) {
            fwInfo.value = FWInfo.fromJson(const JsonDecoder().convert(value.data.toString()));
            if (fwVersion.value != "") {
              if (fwInfo.value?.version.split(" ")[1] != fwVersion.value) {
                hasUpdate.value = true;
              }
            }
          }
        },
      ).onError((error, stackTrace) {
        bluetoothLog.warning("Unable to get Firmware info for ${baseDeviceDefinition.fwURL} :$error", error, stackTrace);
      });
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
    batlevels = [];
    stopWatch.reset();
    mtu.value = -1;
  }
}

enum MessageHistoryType {
  send,
  receive,
}

class MessageHistoryEntry {
  final MessageHistoryType type;
  final String message;

  MessageHistoryEntry({required this.type, required this.message});
}

@HiveType(typeId: 12)
enum AutoActionCategory {
  @HiveField(1)
  calm,
  @HiveField(2)
  fast,
  @HiveField(3)
  tense,
}

extension AutoActionCategoryExtension on AutoActionCategory {
  String get friendly {
    switch (this) {
      case AutoActionCategory.calm:
        return manageDevicesAutoMoveGroupsCalm();
      case AutoActionCategory.fast:
        return manageDevicesAutoMoveGroupsFast();
      case AutoActionCategory.tense:
        return manageDevicesAutoMoveGroupsFrustrated();
    }
  }
}

// All serialized/stored data
@HiveType(typeId: 1)
class BaseStoredDevice extends ChangeNotifier {
  @HiveField(0)
  String name = "New Gear";
  @HiveField(1)
  bool autoMove = false;
  @HiveField(2)
  double autoMoveMinPause = 15;
  @HiveField(3)
  double autoMoveMaxPause = 240;
  @HiveField(4)
  double autoMoveTotal = 60;
  @HiveField(5)
  double noPhoneDelayTime = 1;
  @HiveField(6)
  List<AutoActionCategory> selectedAutoCategories = [AutoActionCategory.calm];
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
  late final Ref? ref;
  final PriorityQueue<BluetoothMessage> state = PriorityQueue();
  final BaseStatefulDevice device;

  CommandQueue(this.ref, this.device);

  Stream<BluetoothMessage> messageQueueStream() async* {
    while (true) {
      // Limit the speed commands are processed
      await Future.delayed(const Duration(milliseconds: 100));
      // wait for
      if (state.isNotEmpty && device.deviceState.value == DeviceState.standby) {
        device.deviceState.value = DeviceState.runAction;
        yield state.removeFirst();
      }
    }
  }

  StreamSubscription<BluetoothMessage>? messageQueueStreamSubscription;

  void addCommand(BluetoothMessage bluetoothMessage) {
    messageQueueStreamSubscription ??= messageQueueStream().listen((message) async {
      //TODO: Resend on busy
      if (bluetoothMessage.delay == null) {
        try {
          bluetoothLog.fine("Sending command to ${device.baseStoredDevice.name}:${message.message}");
          await sendMessage(device, const Utf8Encoder().convert(message.message));
          device.messageHistory.add(MessageHistoryEntry(type: MessageHistoryType.send, message: message.message));
          if (message.onCommandSent != null) {
            // Callback when the specific command is run
            message.onCommandSent!();
          }
          try {
            if (message.responseMSG != null) {
              Duration timeoutDuration = const Duration(seconds: 10);
              bluetoothLog.fine("Waiting for response from ${device.baseStoredDevice.name}:${message.responseMSG}");
              Timer timer = Timer(timeoutDuration, () {});

              // We use a timeout as sometimes a response isn't sent by the gear
              Future<String> response = message.device.rxCharacteristicStream.timeout(timeoutDuration, onTimeout: (sink) => sink.close()).where((event) {
                bluetoothLog.info('Response:$event');
                return event.contains(message.responseMSG!);
              }).first;
              // Handles response value
              response.then((value) {
                timer.cancel();
                if (message.onResponseReceived != null) {
                  //callback when the command response is received
                  message.onResponseReceived!(value);
                }
              });
              response.timeout(
                timeoutDuration,
                onTimeout: () {
                  bluetoothLog.warning("Timed out waiting for response from ${device.baseStoredDevice.name}:${message.responseMSG}");
                  return "";
                },
              );
              while (timer.isActive) {
                //allow higher priority commands to interrupt waiting for a response
                if (state.isNotEmpty && state.first.priority.index > bluetoothMessage.priority.index) {
                  timer.cancel();
                }
                await Future.delayed(const Duration(milliseconds: 50)); // Prevent the loop from consuming too many resources
              }
              bluetoothLog.fine("Finished waiting for response from ${device.baseStoredDevice.name}:${message.responseMSG}");
            } else {
              await Future.delayed(const Duration(milliseconds: 200));
            }
          } catch (e, s) {
            bluetoothLog.warning('Command timed out or threw error: $e', e, s);
          }
        } catch (e, s) {
          Sentry.captureException(e, stackTrace: s);
        }
      } else {
        bluetoothLog.fine("Pausing queue for ${device.baseStoredDevice.name}");
        Timer timer = Timer(Duration(milliseconds: bluetoothMessage.delay!.toInt() * 20), () {});
        while (timer.isActive) {
          //allow higher priority commands to interrupt the delay
          if (state.isNotEmpty && state.first.priority.index > bluetoothMessage.priority.index) {
            timer.cancel();
          }
          await Future.delayed(const Duration(milliseconds: 50)); // Prevent the loop from consuming too many resources
        }
        bluetoothLog.fine("Resuming queue for ${device.baseStoredDevice.name}");
      }
      device.deviceState.value = DeviceState.standby; //Without setting state to standby, another command can not run
    });
    // preempt queue
    if (bluetoothMessage.type == Type.direct) {
      state.toUnorderedList().where((element) => [Type.move, Type.direct].contains(element.type)).forEach((element) => state.remove(element));
    }
    state.add(bluetoothMessage);
  }
}
