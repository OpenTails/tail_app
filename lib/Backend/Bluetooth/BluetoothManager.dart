import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:cross_platform/cross_platform.dart';
import 'package:flutter_foreground_service/flutter_foreground_service.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../main.dart';
import '../Definitions/Device/BaseDeviceDefinition.dart';
import '../DeviceRegistry.dart';
import '../btMessage.dart';

part 'BluetoothManager.g.dart';

@Riverpod(dependencies: [reactiveBLE, KnownDevices])
Stream<DiscoveredDevice> scanForDevices(ScanForDevicesRef ref) {
  Flogger.d("Starting scan");
  final FlutterReactiveBle bluetoothManagerRef = ref.watch(reactiveBLEProvider);
  Stream<DiscoveredDevice> scanStream = bluetoothManagerRef.scanForDevices(withServices: DeviceRegistry.getAllIds()).asBroadcastStream();
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
    List<String>? storedDevices = prefs.getStringList("devices");
    Map<String, BaseStatefulDevice> results = {};
    try {
      if (storedDevices != null && storedDevices.isNotEmpty) {
        storedDevices.map((String e) => BaseStoredDevice.fromJson(jsonDecode(e))).forEach((BaseStoredDevice e) {
          BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.getByUUID(e.deviceDefinitionUUID);
          BaseStatefulDevice baseStatefulDevice = BaseStatefulDevice(baseDeviceDefinition, e, ref);
          results[e.btMACAddress] = baseStatefulDevice;
        });
      }
    } catch (e, s) {
      Flogger.e("Unable to load stored devices due to $e", stackTrace: s);
    }

    return results;
  }

  void add(BaseStatefulDevice baseStatefulDevice) {
    state[baseStatefulDevice.baseStoredDevice.btMACAddress] = baseStatefulDevice;
    state = state;
    store();
  }

  void remove(String id) {
    state.remove(id);
    state = state;
    store();
  }

  Future<void> store() async {
    await prefs.setStringList(
        "devices",
        state.values.map((e) {
          return const JsonEncoder.withIndent("    ").convert(e.baseStoredDevice.toJson());
        }).toList());
  }

  Future<void> connect(DiscoveredDevice device) async {
    final ISentrySpan transaction = Sentry.startTransaction('connectToDevice()', 'task');
    BaseDeviceDefinition? deviceDefinition = DeviceRegistry.getByService(device.serviceUuids);
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
        baseStoredDevice = BaseStoredDevice(deviceDefinition.uuid, device.id);
        baseStoredDevice.name = getNameFromBTName(deviceDefinition.btName);
        statefulDevice = BaseStatefulDevice(deviceDefinition, baseStoredDevice, ref);
        transaction.setTag('Known Device', 'No');
        Future(() => add(statefulDevice));
      }
      FlutterReactiveBle reactiveBLE = ref.read(reactiveBLEProvider);
      statefulDevice.connectionStateStream = reactiveBLE.connectToDevice(id: device.id);
      statefulDevice.connectionStateStream?.listen((event) {
        statefulDevice.deviceConnectionState.value = event.connectionState;
        Flogger.i("Connection State updated for ${baseStoredDevice.name}: ${event.connectionState}");
        if (event.connectionState == DeviceConnectionState.connected) {
          Flogger.i("Discovering services for ${baseStoredDevice.name}");
          reactiveBLE.discoverAllServices(device.id);
          statefulDevice.rxCharacteristicStream = reactiveBLE.subscribeToCharacteristic(statefulDevice.rxCharacteristic);
          statefulDevice.rxCharacteristicStream?.listen((event) {
            String value = const Utf8Decoder().convert(event);
            Flogger.i("Received message from ${baseStoredDevice.name}: $value");
            if (value.startsWith("VER")) {
              statefulDevice.fwVersion.value = value.substring(value.indexOf(" "));
            } else if (value.startsWith("GLOWTIP")) {
              statefulDevice.glowTip.value = "TRUE" == value.substring(value.indexOf(" "));
            } else if (value.contains("BUSY")) {
              statefulDevice.deviceState.value = DeviceState.busy;
              //TODO: add busy check to see if gear ready for next command
            }
          });
          statefulDevice.batteryCharacteristicStream = reactiveBLE.subscribeToCharacteristic(statefulDevice.batteryCharacteristic);
          statefulDevice.batteryCharacteristicStream?.listen((List<int> event) {
            Flogger.d("Received Battery message from ${baseStoredDevice.name}: $event");
            statefulDevice.battery.value = event.first.toDouble();
          });
          statefulDevice.keepAliveStream = Stream.periodic(const Duration(seconds: 30));
          statefulDevice.keepAliveStream?.listen((event) {
            if (state.containsKey(device.id)) {
              statefulDevice.commandQueue.addCommand(BluetoothMessage("PING", statefulDevice, Priority.low));
            } else {
              throw Exception("Disconnected from device");
            }
          }, cancelOnError: true);
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
StreamSubscription<BleStatus> btStatus(BtStatusRef ref) {
  return ref.read(reactiveBLEProvider).statusStream.listen((BleStatus event) {
    Flogger.i("BluetoothState::$event"); //TODO: Do something with this
  });
}

@Riverpod(keepAlive: true, dependencies: [reactiveBLE, KnownDevices])
StreamSubscription<ConnectionStateUpdate> btConnectStatus(BtConnectStatusRef ref) {
  return ref.read(reactiveBLEProvider).connectedDeviceStream.listen((ConnectionStateUpdate event) {
    Flogger.i("ConnectedDevice::$event");
    Map<String, BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);
    //start foreground service on device connected. Library handles duplicate start calls
    if (Platform.isAndroid && event.connectionState == DeviceConnectionState.connected) {
      ForegroundService().start();
    }
    if (knownDevices.containsKey(event.deviceId)) {
      knownDevices[event.deviceId]?.deviceConnectionState.value = event.connectionState;
      if (event.connectionState == DeviceConnectionState.disconnected) {
        Flogger.i("Disconnected from device: ${event.deviceId}");
        knownDevices[event.deviceId]?.connectionStateStream = null;
        knownDevices[event.deviceId]?.batteryCharacteristicStream = null;
        knownDevices[event.deviceId]?.rxCharacteristicStream = null;
        knownDevices[event.deviceId]?.keepAliveStream = null;
        knownDevices[event.deviceId]?.battery.value = 0;

        //remove foreground service if no devices connected
        if (Platform.isAndroid && knownDevices.values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected).isEmpty) {
          ForegroundService().stop();
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
  Ref ref;
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
        final ISentrySpan transaction = Sentry.startTransaction('sendBTCommand()', 'Send Command');
        try {
          final ISentrySpan innerSpan = transaction.startChild('Send Commands', description: 'Sends all commands to Gear');
          Flogger.d("Sending command to ${device.baseStoredDevice.name}:${message.message}");
          await ref.read(reactiveBLEProvider).writeCharacteristicWithResponse(message.device.txCharacteristic, value: const Utf8Encoder().convert(message.message));
          innerSpan.finish();
          if (message.onCommandSent != null) {
            message.onCommandSent!();
          }
          if (message.responseMSG != null) {
            final ISentrySpan responseSpan = transaction.startChild('Receive Response', description: 'Listens for the correct response message');
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
              responseSpan.status = const SpanStatus.ok();
            } else {
              Flogger.d("Timed out waiting for response from ${device.baseStoredDevice.name}:${message.responseMSG}");
              responseSpan.status = const SpanStatus.deadlineExceeded();
            }
            responseSpan.finish();
          }
        } catch (e, s) {
          Sentry.captureException(e, stackTrace: s);
          transaction.status = const SpanStatus.internalError();
        } finally {
          await transaction.finish();
        }
      } else {
        //TODO: Allow higher priority commands to run
        Flogger.d("Pausing queue for ${device.baseStoredDevice.name}");
        await Future.delayed(Duration(seconds: bluetoothMessage.delay!.round()));
        Flogger.d("Resuming queue for ${device.baseStoredDevice.name}");
      }
      device.deviceState.value = DeviceState.standby; //Without setting state to standby, another command can not run
    });
    state.add(bluetoothMessage);
  }
}
