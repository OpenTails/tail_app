import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:circular_buffer/circular_buffer.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/firmware_update.dart';

import '../../../Frontend/intn_defs.dart';
import '../../Bluetooth/bluetooth_message.dart';

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
  final Uuid bleDeviceService;
  final Uuid bleRxCharacteristic;
  final Uuid bleTxCharacteristic;
  final DeviceType deviceType;
  final String fwURL;

  const BaseDeviceDefinition(this.uuid, this.btName, this.bleDeviceService, this.bleRxCharacteristic, this.bleTxCharacteristic, this.deviceType, this.fwURL);

  @override
  String toString() {
    return 'BaseDeviceDefinition{btName: $btName, deviceType: $deviceType}';
  }
}

// data that represents the current state of a device
class BaseStatefulDevice {
  final BaseDeviceDefinition baseDeviceDefinition;
  final BaseStoredDevice baseStoredDevice;
  late final QualifiedCharacteristic rxCharacteristic;
  late final QualifiedCharacteristic txCharacteristic;
  late final QualifiedCharacteristic batteryCharacteristic;
  late final QualifiedCharacteristic batteryChargeCharacteristic;

  final ValueNotifier<double> batteryLevel = ValueNotifier(-1);
  final ValueNotifier<bool> batteryCharging = ValueNotifier(false);
  final ValueNotifier<bool> batteryLow = ValueNotifier(false);
  final ValueNotifier<bool> gearReturnedError = ValueNotifier(false);

  final ValueNotifier<String> fwVersion = ValueNotifier("");
  final ValueNotifier<String> hwVersion = ValueNotifier("");

  final ValueNotifier<bool> hasGlowtip = ValueNotifier(false);
  StreamSubscription<ConnectionStateUpdate>? connectionStateStreamSubscription;
  final ValueNotifier<DeviceState> deviceState = ValueNotifier(DeviceState.standby);
  Stream<String>? _rxCharacteristicStream;
  StreamSubscription<void>? keepAliveStreamSubscription;

  Stream<String>? get rxCharacteristicStream => _rxCharacteristicStream;
  final ValueNotifier<ConnectivityState> deviceConnectionState = ValueNotifier(ConnectivityState.disconnected);
  final ValueNotifier<int> rssi = ValueNotifier(-1);
  final ValueNotifier<FWInfo?> fwInfo = ValueNotifier(null);
  final ValueNotifier<bool> hasUpdate = ValueNotifier(false);

  set rxCharacteristicStream(Stream<String>? value) {
    _rxCharacteristicStream = value?.asBroadcastStream();
  }

  Ref? ref;
  late final CommandQueue commandQueue;
  StreamSubscription<List<int>>? batteryCharacteristicStreamSubscription;
  StreamSubscription<String>? batteryChargeCharacteristicStreamSubscription;
  List<FlSpot> batlevels = [];
  Stopwatch stopWatch = Stopwatch();
  bool disableAutoConnect = false;
  bool forgetOnDisconnect = false;

  final CircularBuffer<MessageHistoryEntry> messageHistory = CircularBuffer(50);

  BaseStatefulDevice(this.baseDeviceDefinition, this.baseStoredDevice, this.ref) {
    rxCharacteristic = QualifiedCharacteristic(characteristicId: baseDeviceDefinition.bleRxCharacteristic, serviceId: baseDeviceDefinition.bleDeviceService, deviceId: baseStoredDevice.btMACAddress);
    txCharacteristic = QualifiedCharacteristic(characteristicId: baseDeviceDefinition.bleTxCharacteristic, serviceId: baseDeviceDefinition.bleDeviceService, deviceId: baseStoredDevice.btMACAddress);
    batteryCharacteristic = QualifiedCharacteristic(serviceId: Uuid.parse("0000180f-0000-1000-8000-00805f9b34fb"), characteristicId: Uuid.parse("00002a19-0000-1000-8000-00805f9b34fb"), deviceId: baseStoredDevice.btMACAddress);
    batteryChargeCharacteristic = QualifiedCharacteristic(serviceId: Uuid.parse("0000180f-0000-1000-8000-00805f9b34fb"), characteristicId: Uuid.parse("5073792e-4fc0-45a0-b0a5-78b6c1756c91"), deviceId: baseStoredDevice.btMACAddress);

    commandQueue = CommandQueue(ref, this);
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
    fwVersion.value = "";
    hwVersion.value = "";
    hasGlowtip.value = false;
    connectionStateStreamSubscription?.cancel();
    connectionStateStreamSubscription = null;
    deviceState.value = DeviceState.standby;
    rxCharacteristicStream = null;
    keepAliveStreamSubscription?.cancel();
    keepAliveStreamSubscription = null;
    deviceConnectionState.value = ConnectivityState.disconnected;
    rssi.value = -1;
    fwInfo.value = null;
    hasUpdate.value = false;
    batteryCharacteristicStreamSubscription?.cancel();
    batteryCharacteristicStreamSubscription = null;
    batteryChargeCharacteristicStreamSubscription?.cancel();
    batteryChargeCharacteristicStreamSubscription = null;
    batlevels = [];
    stopWatch.reset();
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
class BaseStoredDevice {
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
  int color;

  BaseStoredDevice(this.deviceDefinitionUUID, this.btMACAddress, this.color);

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
      //Check if the device is still known and connected;
      if (device.deviceConnectionState.value != ConnectivityState.connected) {
        device.deviceState.value = DeviceState.standby;
        return;
      }
      //TODO: Resend on busy
      if (bluetoothMessage.delay == null) {
        try {
          bluetoothLog.fine("Sending command to ${device.baseStoredDevice.name}:${message.message}");
          await ref?.read(reactiveBLEProvider).writeCharacteristicWithResponse(message.device.txCharacteristic, value: const Utf8Encoder().convert(message.message));
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
              Future<String> response = message.device.rxCharacteristicStream!.timeout(timeoutDuration, onTimeout: (sink) => sink.close()).where((event) {
                bluetoothLog.info('Response:$event');
                return event == message.responseMSG!;
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
