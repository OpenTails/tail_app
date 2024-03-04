import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:cross_platform/cross_platform.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_foreground_service/flutter_foreground_service.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Sensors.dart';
import 'package:tail_app/main.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../AutoMove.dart';
import '../Definitions/Device/BaseDeviceDefinition.dart';
import '../DeviceRegistry.dart';
import '../FirmwareUpdate.dart';
import 'btMessage.dart';

part 'BluetoothManager.g.dart';

@Riverpod(dependencies: [reactiveBLE, KnownDevices])
Stream<DiscoveredDevice> scanForDevices(ScanForDevicesRef ref) {
  Flogger.d("Starting scan");
  final FlutterReactiveBle bluetoothManagerRef = ref.watch(reactiveBLEProvider);
  Stream<DiscoveredDevice> scanStream = bluetoothManagerRef.scanForDevices(withServices: DeviceRegistry.getAllIds(), requireLocationServicesEnabled: false, scanMode: ScanMode.lowPower).asBroadcastStream();
  scanStream.listen((DiscoveredDevice event) {
    if (ref.read(knownDevicesProvider).containsKey(event.id) && ref.read(knownDevicesProvider)[event.id]?.deviceConnectionState.value == DeviceConnectionState.disconnected) {
      ref.read(knownDevicesProvider.notifier).connect(event);
    }
  });
  return scanStream.skipWhile((DiscoveredDevice element) => ref.read(knownDevicesProvider).containsKey(element.id));
}

@Riverpod(keepAlive: true)
class KnownDevices extends _$KnownDevices {
  @override
  Map<String, BaseStatefulDevice> build() {
    List<BaseStoredDevice> storedDevices = SentryHive.box<BaseStoredDevice>('devices').values.toList();
    Map<String, BaseStatefulDevice> results = {};
    try {
      if (storedDevices.isNotEmpty) {
        for (BaseStoredDevice e in storedDevices) {
          BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.getByUUID(e.deviceDefinitionUUID);
          BaseStatefulDevice baseStatefulDevice = BaseStatefulDevice(baseDeviceDefinition, e, ref);
          results[e.btMACAddress] = baseStatefulDevice;
        }
      }
    } catch (e, s) {
      Flogger.e("Unable to load stored devices due to $e", stackTrace: s);
    }

    return results;
  }

  void add(BaseStatefulDevice baseStatefulDevice) {
    Map<String, BaseStatefulDevice> state2 = Map.from(state);
    state2[baseStatefulDevice.baseStoredDevice.btMACAddress] = baseStatefulDevice;
    state = state2;
    store();
  }

  void remove(String id) {
    Map<String, BaseStatefulDevice> state2 = Map.from(state);
    state2.remove(id);
    state = state2;
    store();
  }

  Future<void> store() async {
    SentryHive.box<BaseStoredDevice>('devices')
      ..clear()
      ..addAll(state.values.map((e) => e.baseStoredDevice));
  }

  Future<void> connect(DiscoveredDevice device) async {
    final ISentrySpan transaction = Sentry.startTransaction('connectToDevice()', 'task');
    BaseDeviceDefinition? deviceDefinition = DeviceRegistry.getByName(device.name);
    if (deviceDefinition == null) {
      Flogger.w("Unknown device found: ${device.name}");
      transaction.status = const SpanStatus.notFound();
      transaction.finish();
      return;
    }
    BaseStoredDevice baseStoredDevice;
    BaseStatefulDevice statefulDevice;
    transaction.setTag('Device Name', device.name);
    try {
      //get existing entry
      if (state.containsKey(device.id)) {
        statefulDevice = state[device.id]!;
        statefulDevice.deviceConnectionState.value = DeviceConnectionState.connecting;
        baseStoredDevice = statefulDevice.baseStoredDevice;
        transaction.setTag('Known Device', 'Yes');
      } else {
        baseStoredDevice = BaseStoredDevice(deviceDefinition.uuid, device.id, deviceDefinition.deviceType.color.value);
        baseStoredDevice.name = getNameFromBTName(deviceDefinition.btName);
        statefulDevice = BaseStatefulDevice(deviceDefinition, baseStoredDevice, ref);
        transaction.setTag('Known Device', 'No');
        Future(() => add(statefulDevice));
      }
      FlutterReactiveBle reactiveBLE = ref.read(reactiveBLEProvider);
      statefulDevice.connectionStateStreamSubscription = reactiveBLE.connectToDevice(id: device.id).listen((event) async {
        statefulDevice.deviceConnectionState.value = event.connectionState;
        Flogger.i("Connection State updated for ${baseStoredDevice.name}: ${event.connectionState}");
        if (event.connectionState == DeviceConnectionState.connected) {
          statefulDevice.stopWatch.start();
          statefulDevice.rssi.value = await reactiveBLE.readRssi(device.id);
          Flogger.i("Discovering services for ${baseStoredDevice.name}");
          reactiveBLE.discoverAllServices(device.id);
          statefulDevice.rxCharacteristicStream = reactiveBLE.subscribeToCharacteristic(statefulDevice.rxCharacteristic);
          statefulDevice.rxCharacteristicStream?.listen((event) {
            String value = const Utf8Decoder().convert(event);
            Flogger.i("Received message from ${baseStoredDevice.name}: $value");
            if (value.startsWith("VER")) {
              statefulDevice.fwVersion.value = value.substring(value.indexOf(" "));
              if (statefulDevice.fwInfo.value != null) {
                if (statefulDevice.fwInfo.value?.version.split(" ")[1] != statefulDevice.fwVersion.value) {
                  statefulDevice.hasUpdate.value = true;
                }
              }
            } else if (value.startsWith("GLOWTIP")) {
              statefulDevice.glowTip.value = "TRUE" == value.substring(value.indexOf(" "));
            } else if (value.contains("BUSY")) {
              //statefulDevice.deviceState.value = DeviceState.busy;
            } else if (value.contains("LOWBATT")) {
              statefulDevice.batteryLow.value = true;
            } else if (value.contains("ERR")) {
              statefulDevice.error.value = true;
            }
          });
          statefulDevice.batteryCharacteristicStreamSubscription = reactiveBLE.subscribeToCharacteristic(statefulDevice.batteryCharacteristic).listen((List<int> event) {
            Flogger.d("Received Battery message from ${baseStoredDevice.name}: $event");
            statefulDevice.battery.value = event.first.toDouble();
            statefulDevice.batlevels.add(FlSpot(statefulDevice.stopWatch.elapsed.inSeconds.toDouble(), event.first.toDouble()));
          });
          statefulDevice.batteryChargeCharacteristicStreamSubscription = reactiveBLE.subscribeToCharacteristic(statefulDevice.batteryChargeCharacteristic).listen((List<int> event) {
            String value = const Utf8Decoder().convert(event);
            Flogger.d("Received Battery Charge message from ${baseStoredDevice.name}: $value");
            statefulDevice.batteryCharging.value = value == "CHARGE ON";
          });
          statefulDevice.keepAliveStreamSubscription = Stream.periodic(const Duration(seconds: 15)).listen((event) async {
            if (state.containsKey(device.id)) {
              statefulDevice.commandQueue.addCommand(BluetoothMessage("PING", statefulDevice, Priority.low));
              statefulDevice.rssi.value = await reactiveBLE.readRssi(device.id);
            } else {
              throw Exception("Disconnected from device");
            }
          }, cancelOnError: true);
          if (deviceDefinition.fwURL != "") {
            initDio().get(statefulDevice.baseDeviceDefinition.fwURL, options: Options(responseType: ResponseType.json)).then(
              (value) {
                if (value.statusCode == 200) {
                  statefulDevice.fwInfo.value = FWInfo.fromJson(const JsonDecoder().convert(value.data.toString()));
                  if (statefulDevice.fwVersion.value != "") {
                    if (statefulDevice.fwInfo.value?.version.split(" ")[1] != statefulDevice.fwVersion.value) {
                      statefulDevice.hasUpdate.value = true;
                    }
                  }
                }
              },
            ).onError((error, stackTrace) => Flogger.e("Unable to get Firmware info for ${statefulDevice.baseDeviceDefinition.fwURL} :$error"));
          }
          statefulDevice.commandQueue.addCommand(BluetoothMessage("VER", statefulDevice, Priority.low));
          if (statefulDevice.baseStoredDevice.autoMove) {
            ChangeAutoMove(statefulDevice);
          }
        }
      });
      transaction.status = const SpanStatus.ok();
    } catch (e, s) {
      Sentry.captureException(e, stackTrace: s);
      transaction.status = const SpanStatus.internalError();
    } finally {
      await transaction.finish();
    }
    return;
  }
}

@Riverpod(keepAlive: true, dependencies: [reactiveBLE])
Stream<BleStatus> btStatus(BtStatusRef ref) {
  return ref.read(reactiveBLEProvider).statusStream;
}

@Riverpod(keepAlive: true, dependencies: [reactiveBLE, KnownDevices, TriggerList])
StreamSubscription<ConnectionStateUpdate> btConnectStateHandler(BtConnectStateHandlerRef ref) {
  return ref.read(reactiveBLEProvider).connectedDeviceStream.listen((ConnectionStateUpdate event) {
    Flogger.i("ConnectedDevice::$event");
    Map<String, BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);
    //start foreground service on device connected. Library handles duplicate start calls
    if (Platform.isAndroid && event.connectionState == DeviceConnectionState.connected) {
      ForegroundServiceHandler.notification.setPriority(AndroidNotificationPriority.LOW);
      ForegroundServiceHandler.notification.setTitle("Gear Connected");
      ForegroundService().start();
    }
    if (event.connectionState == DeviceConnectionState.connected) {
      if (SentryHive.box('settings').get('keepAwake', defaultValue: false)) {
        WakelockPlus.enable();
      }
    }
    if (knownDevices.containsKey(event.deviceId)) {
      knownDevices[event.deviceId]?.deviceConnectionState.value = event.connectionState;
      if (event.connectionState == DeviceConnectionState.disconnected) {
        Flogger.i("Disconnected from device: ${event.deviceId}");
        knownDevices[event.deviceId]?.connectionStateStreamSubscription?.cancel();
        knownDevices[event.deviceId]?.connectionStateStreamSubscription = null;
        knownDevices[event.deviceId]?.batteryCharacteristicStreamSubscription?.cancel();
        knownDevices[event.deviceId]?.batteryCharacteristicStreamSubscription = null;
        knownDevices[event.deviceId]?.rxCharacteristicStream = null;
        knownDevices[event.deviceId]?.keepAliveStreamSubscription?.cancel();
        knownDevices[event.deviceId]?.keepAliveStreamSubscription = null;
        knownDevices[event.deviceId]?.battery.value = -1;
        knownDevices[event.deviceId]?.rssi.value = -1;
        knownDevices[event.deviceId]?.hasUpdate.value = false;
        knownDevices[event.deviceId]?.fwInfo.value = null;
        knownDevices[event.deviceId]?.fwVersion.value = "";
        knownDevices[event.deviceId]?.batteryCharging.value = false;
        knownDevices[event.deviceId]?.batteryChargeCharacteristicStreamSubscription?.cancel();
        knownDevices[event.deviceId]?.batteryChargeCharacteristicStreamSubscription = null;
        knownDevices[event.deviceId]?.stopWatch.stop();
        knownDevices[event.deviceId]?.stopWatch.reset();
        knownDevices[event.deviceId]?.batteryLow.value = false;
        //ref.read(snackbarStreamProvider.notifier).add(SnackBar(content: Text("Disconnected from ${knownDevices[event.deviceId]?.baseStoredDevice.name}")));
        //remove foreground service if no devices connected
        bool lastDevice = knownDevices.values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected).isEmpty;
        if (Platform.isAndroid && lastDevice) {
          ForegroundService().stop();
        }
        if (lastDevice) {
          // Disable all triggers on last device
          ref.read(triggerListProvider).where((element) => element.enabled).forEach((element) {
            element.enabled = false;
          });
          WakelockPlus.disable();
        }
      }
    }
  });
}

@Riverpod(keepAlive: true)
FlutterReactiveBle reactiveBLE(ReactiveBLERef ref) {
  Flogger.i("Initializing BluetoothManager");
  FlutterReactiveBle flutterReactiveBle = FlutterReactiveBle();
  flutterReactiveBle.logLevel = LogLevel.none;
  flutterReactiveBle.initialize();
  return FlutterReactiveBle();
}

class CommandQueue {
  Ref? ref;
  PriorityQueue<BluetoothMessage> state = PriorityQueue();
  BaseStatefulDevice device;

  CommandQueue(this.ref, this.device);

  Stream<BluetoothMessage> messageQueueStream() async* {
    while (true) {
      await Future.delayed(const Duration(milliseconds: 50));
      while (state.isNotEmpty && device.deviceState.value == DeviceState.standby) {
        device.deviceState.value = DeviceState.runAction;
        yield state.removeFirst();
      }
    }
  }

  StreamSubscription<BluetoothMessage>? messageQueueStreamSubscription;

  void addCommand(BluetoothMessage bluetoothMessage) {
    messageQueueStreamSubscription ??= messageQueueStream().listen((message) async {
      //Check if the device is still known and connected;
      if (device.deviceConnectionState.value != DeviceConnectionState.connected) {
        device.deviceState.value = DeviceState.standby;
        return;
      }
      //TODO: Resend on busy
      if (bluetoothMessage.delay == null) {
        try {
          Flogger.d("Sending command to ${device.baseStoredDevice.name}:${message.message}");
          await ref?.read(reactiveBLEProvider).writeCharacteristicWithResponse(message.device.txCharacteristic, value: const Utf8Encoder().convert(message.message));
          if (message.onCommandSent != null) {
            message.onCommandSent!();
          }
          if (message.responseMSG != null) {
            Flogger.d("Waiting for response from ${device.baseStoredDevice.name}:${message.responseMSG}");
            List<int>? response = await message.device.rxCharacteristicStream?.timeout(const Duration(seconds: 10), onTimeout: (sink) => sink.close()).where((event) {
              Flogger.i('Response:${const Utf8Decoder().convert(event)}');
              return const Utf8Decoder().convert(event) == message.responseMSG!;
            }).first;
            Flogger.d("Finished waiting for response from ${device.baseStoredDevice.name}:${message.responseMSG}");
            if (response != null) {
              if (message.onResponseReceived != null) {
                message.onResponseReceived!(const Utf8Decoder().convert(response));
              }
            } else {
              Flogger.d("Timed out waiting for response from ${device.baseStoredDevice.name}:${message.responseMSG}");
            }
          }
        } catch (e, s) {
          Sentry.captureException(e, stackTrace: s);
        }
      } else {
        //TODO: Allow higher priority commands to run
        Flogger.d("Pausing queue for ${device.baseStoredDevice.name}");
        await Future.delayed(Duration(milliseconds: bluetoothMessage.delay!.toInt() * 20));
        Flogger.d("Resuming queue for ${device.baseStoredDevice.name}");
      }
      device.deviceState.value = DeviceState.standby; //Without setting state to standby, another command can not run
    });
    state.add(bluetoothMessage);
  }
}
