import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tail_app/Backend/DeviceRegistry.dart';

import '../Definitions/Device/BaseDeviceDefinition.dart';
import '../btMessage.dart';

class BluetoothManager {
  final Set<DiscoveredDevice> foundDevices = {};
  final ValueNotifier<Set<BaseStatefulDevice>> knownDevices = ValueNotifier({});
  bool isScanning = false;
  final StreamController<btMessage> incomingMessageQueue = StreamController();
  final StreamController<btMessage> outgoingMessageQueue = StreamController();
  final flutterReactiveBle = FlutterReactiveBle();

  BluetoothManager() {
    Flogger.i("Initializing BluetoothManager");
    flutterReactiveBle.initialize();
    flutterReactiveBle.logLevel = LogLevel.verbose;
    flutterReactiveBle.statusStream.listen((event) {
      Flogger.i("BluetoothState::$event");
      if (kDebugMode) {
        print(event);
      }
    });
    flutterReactiveBle.connectedDeviceStream.listen((event) {
      Flogger.i("ConnectedDevice::$event");
    });
    flutterReactiveBle.characteristicValueStream.listen((event) {
      Flogger.i("CharacteristicValue::$event");
    });
    outgoingMessageQueue.stream.listen((event) async {
      Flogger.i("OutgoingMessage::$event");
      flutterReactiveBle.writeCharacteristicWithoutResponse(QualifiedCharacteristic(characteristicId: event.device.baseDeviceDefinition.bleTxCharacteristic, serviceId: event.device.baseDeviceDefinition.bleDeviceService, deviceId: event.device.baseStoredDevice.btMACAddress),
          value: const Utf8Encoder().convert(event.message));
    });
    incomingMessageQueue.stream.listen((event) {
      Flogger.i("IncomingMessage::$event");
    });
  }

  Future<void> scan() async {
    if (await Permission.bluetoothScan.isGranted == false) {
      return;
    }
    if (isScanning) {
      return;
    }
    Flogger.d("Starting scan");
    isScanning = true;
    flutterReactiveBle.scanForDevices(withServices: DeviceRegistry.getAllIds()).listen((DiscoveredDevice device) {
      //code for handling results
      if (foundDevices.any((element) => element.id == device.id)) {
        return;
      }
      Flogger.i("DeviceFound::${device.name}");
      foundDevices.add(device);
      BaseDeviceDefinition? deviceDefinition = DeviceRegistry.getByService(device.serviceUuids);
      if (deviceDefinition == null) {
        Flogger.w("Unknown device found: ${device.name}");
        return;
      }
      Flogger.i("Found device: ${device.name}");
      BaseStoredDevice baseStoredDevice = BaseStoredDevice(deviceDefinition.uuid.toString(), device.id);
      BaseStatefulDevice statefulDevice = BaseStatefulDevice(deviceDefinition, baseStoredDevice);
      flutterReactiveBle.connectToDevice(id: device.id).listen((event) {
        if (event.connectionState == DeviceConnectionState.disconnected) {
          Flogger.i("Disconnected from device: ${device.name}");
          statefulDevice.deviceState = DeviceState.disconnected;
          foundDevices.remove(device);
          knownDevices.value.remove(statefulDevice);
        }

        if (event.connectionState == DeviceConnectionState.connected) {
          knownDevices.value.add(statefulDevice);
          statefulDevice.deviceState = DeviceState.standby;
          Flogger.i("Connected to device: ${device.name}");
          flutterReactiveBle.subscribeToCharacteristic(QualifiedCharacteristic(characteristicId: deviceDefinition.bleRxCharacteristic, serviceId: deviceDefinition.bleDeviceService, deviceId: device.id)).listen((event) {
            String value = const Utf8Decoder().convert(event);
            Flogger.i("Received message: $value");
            incomingMessageQueue.add(btMessage(value, statefulDevice));
          });
        }
      });
    }, onError: (Object error) {
      isScanning = false;
      Flogger.e("Error in scanForDevices", stackTrace: StackTrace.current);
    });
  }

  void sendCommand(btMessage message) {
    try {
      Flogger.d("Sending command::$message");
      outgoingMessageQueue.add(message);
    } catch (e, s) {
      Flogger.e("Error in sendCommand: $e", stackTrace: s);
    }
  }
}
