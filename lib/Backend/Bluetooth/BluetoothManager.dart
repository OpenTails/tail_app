import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:cross_platform/cross_platform.dart';
import 'package:flutter_foreground_service/flutter_foreground_service.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../main.dart';
import '../Definitions/Device/BaseDeviceDefinition.dart';
import '../DeviceRegistry.dart';
import '../btMessage.dart';

part 'BluetoothManager.g.dart';

@Riverpod(dependencies: [reactiveBLE, btConnect])
Stream<DiscoveredDevice> scanForDevices(ScanForDevicesRef ref) {
  Flogger.d("Starting scan");
  final FlutterReactiveBle bluetoothManagerRef = ref.watch(reactiveBLEProvider);
  Stream<DiscoveredDevice> scanStream = bluetoothManagerRef.scanForDevices(withServices: DeviceRegistry.getAllIds()).asBroadcastStream();
  scanStream.listen((DiscoveredDevice event) {
    if (ref.read(knownDevicesProvider).containsKey(event.id) && ref.read(knownDevicesProvider)[event.id]?.deviceConnectionState.value == DeviceConnectionState.disconnected) {
      ref.read(btConnectProvider(event));
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
    store();
  }

  void remove(String id) {
    state.remove(id);
    store();
  }

  Future<void> store() async {
    await prefs.setStringList(
        "devices",
        state.values.map((e) {
          return jsonEncode(e.baseStoredDevice.toJson());
        }).toList());
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

@Riverpod(dependencies: [reactiveBLE, KnownDevices])
bool btConnect(BtConnectRef ref, DiscoveredDevice device) {
  Map<String, BaseStatefulDevice> knownDevices = ref.read(knownDevicesProvider);
  BaseDeviceDefinition? deviceDefinition = DeviceRegistry.getByService(device.serviceUuids);
  if (deviceDefinition == null) {
    Flogger.w("Unknown device found: ${device.name}");
    return false;
  }
  //TODO: store it
  BaseStoredDevice baseStoredDevice;
  BaseStatefulDevice statefulDevice;
  //get existing entry
  if (knownDevices.containsKey(device.id)) {
    statefulDevice = knownDevices[device.id]!;
    statefulDevice.deviceConnectionState.value = DeviceConnectionState.connecting;
    baseStoredDevice = statefulDevice.baseStoredDevice;
  } else {
    baseStoredDevice = BaseStoredDevice(deviceDefinition.uuid, device.id);
    baseStoredDevice.name = getNameFromBTName(deviceDefinition.btName);
    statefulDevice = BaseStatefulDevice(deviceDefinition, baseStoredDevice, ref);
    ref.watch(knownDevicesProvider.notifier).add(statefulDevice);
  }
  statefulDevice.connectionStateStream = ref.read(reactiveBLEProvider).connectToDevice(id: device.id);
  statefulDevice.connectionStateStream?.listen((event) {
    statefulDevice.deviceConnectionState.value = event.connectionState;
    Flogger.i("Connection State updated for ${baseStoredDevice.name}: ${event.connectionState}");
    if (event.connectionState == DeviceConnectionState.connected) {
      Flogger.i("Discovering services for ${baseStoredDevice.name}");
      ref.read(reactiveBLEProvider).discoverAllServices(device.id);
      statefulDevice.rxCharacteristicStream = ref.read(reactiveBLEProvider).subscribeToCharacteristic(statefulDevice.rxCharacteristic);
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
      statefulDevice.batteryCharacteristicStream = ref.read(reactiveBLEProvider).subscribeToCharacteristic(statefulDevice.batteryCharacteristic);
      statefulDevice.batteryCharacteristicStream?.listen((List<int> event) {
        Flogger.i("Received Battery message from ${baseStoredDevice.name}: $event");
        statefulDevice.battery.value = event.first.toDouble();
      });
      statefulDevice.keepAliveStream = Stream.periodic(const Duration(seconds: 30));
      statefulDevice.keepAliveStream?.listen((event) {
        if (knownDevices.containsKey(device.id)) {
          statefulDevice.commandQueue.addCommand(BluetoothMessage("PING", statefulDevice, Priority.low));
        } else {
          throw Exception("disconnected from device");
        }
      }, cancelOnError: true);
    }
  });
  //ref.watch(btSendCommandProvider(btMessage('VER', statefulDevice)));
  return true;
}

class CommandQueue {
  Ref ref;
  PriorityQueue<BluetoothMessage> state = PriorityQueue();
  BaseStatefulDevice device;

  CommandQueue(this.ref, this.device);

  Stream<BluetoothMessage> messageQueueStream() async* {
    while (true) {
      await Future.delayed(const Duration(milliseconds: 100));
      while (state.isNotEmpty) {
        yield state.removeFirst();
      }
    }
  }

  StreamSubscription<BluetoothMessage>? messageQueueStreamSubscription;

  void addCommand(BluetoothMessage bluetoothMessage) {
    messageQueueStreamSubscription ??= messageQueueStream().listen((message) async {
      //Check if the device is still known and connected;
      if (device.deviceConnectionState.value != DeviceConnectionState.connected) {
        return;
      }
      //TODO: Resend on busy
      device.deviceState.value = DeviceState.runAction;
      if (bluetoothMessage.delay == null) {
        for (String msg in message.message.split("\n")) {
          await ref.read(reactiveBLEProvider).writeCharacteristicWithResponse(message.device.txCharacteristic, value: const Utf8Encoder().convert(msg));
        }
        if (message.onCommandSent != null) {
          message.onCommandSent!();
        }
        if (message.onResponseReceived != null && message.responseMSG != null) {
          List<int>? response = await message.device.rxCharacteristicStream?.timeout(const Duration(seconds: 10), onTimeout: (sink) => sink.close()).where((event) => const Utf8Decoder().convert(event).startsWith(message.responseMSG!)).first;
          if (response != null) {
            message.onResponseReceived!(const Utf8Decoder().convert(response));
          }
        }
      } else {
        //TODO: Allow higher priority commands to run
        await Future.delayed(Duration(seconds: bluetoothMessage.delay!.round()));
      }
      device.deviceState.value = DeviceState.standby;
    });
    state.add(bluetoothMessage);
  }
}
