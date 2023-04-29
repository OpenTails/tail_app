import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tail_app/Backend/DeviceRegistry.dart';

import '../Definitions/Device/BaseDeviceDefinition.dart';
import '../btMessage.dart';

class BluetoothManager extends ChangeNotifier {
  final ValueNotifier<Set<DiscoveredDevice>> listenableResults = ValueNotifier({});
  final ValueNotifier<Set<BaseStatefulDevice>> knownDevices = ValueNotifier({});
  final ValueNotifier<String> btState = ValueNotifier("UnknownState");
  bool isScanning = false;
  final StreamController<btMessage> incomingMessageQueue = StreamController();
  final StreamController<btMessage> outgoingMessageQueue = StreamController();
  final flutterReactiveBle = FlutterReactiveBle();

  late StreamSubscription<BleStatus> statusStream;
  late StreamSubscription<ConnectionStateUpdate> connectedDeviceStream;
  late StreamSubscription<CharacteristicValue> characteristicValueStream;
  late StreamSubscription<btMessage> outgoingMessageQueueStream;
  late StreamSubscription<btMessage> incomingMessageQueueStream;

  BluetoothManager() {}

  Future<void> init() async {
    await flutterReactiveBle.initialize();
    flutterReactiveBle.logLevel = LogLevel.verbose;
    statusStream = flutterReactiveBle.statusStream.listen((event) {
      Flogger.i("BluetoothState::$event");
      btState.value = event.toString();
    });
    connectedDeviceStream = flutterReactiveBle.connectedDeviceStream.listen((event) {
      Flogger.i("ConnectedDevice::$event");
    });
    characteristicValueStream = flutterReactiveBle.characteristicValueStream.listen((event) {
      Flogger.i("CharacteristicValue::$event");
    });
    outgoingMessageQueueStream = outgoingMessageQueue.stream.listen((event) async {
      Flogger.i("OutgoingMessage::$event");
      //await event.device.writeCharacteristic?.write(utf8.encode(event.message), withoutResponse: true);
    });
    incomingMessageQueueStream = incomingMessageQueue.stream.listen((event) {
      Flogger.i("IncomingMessage::$event");
    });
  }

  Future<void> scan() async {
    if (await Permission.bluetoothScan.isGranted == false) {
      return;
    }
    Flogger.d("Starting scan");

    
    StreamSubscription<DiscoveredDevice> scanForDevicesStream;
    scanForDevicesStream = flutterReactiveBle.scanForDevices(withServices: [], scanMode: ScanMode.opportunistic, requireLocationServicesEnabled: false).listen((device) {
      Flogger.i("DeviceFound::$device");
      if (device.name.isEmpty || !DeviceRegistry.hasByName(device.name)) {
        return;
      }
      Set<DiscoveredDevice> resultsSet = listenableResults.value;
      resultsSet.add(device);
      listenableResults.value = resultsSet;

      //code for handling results
    }, onError: (Object error) {
      Flogger.e("Error in scanForDevices", stackTrace: StackTrace.current);
    });
  }

  @override
  void dispose() {
    super.dispose();
    Flogger.i("Calling dispose in BluetoothManager");
    listenableResults.dispose();
    btState.dispose();
    incomingMessageQueue.close();
    outgoingMessageQueue.close();
  }

  void sendCommand(btMessage message) {
    try {
      Flogger.d("Sending command::$message");
      outgoingMessageQueue.add(message);
    } catch (e, s) {
      Flogger.e("Error in sendCommand: $e", stackTrace: s);
    }
  }

/*  Future<BaseStatefulDevice?> registerNewDevice(BluetoothDevice bluetoothDevice) async {
    try {
      Flogger.d("Registering new device::${bluetoothDevice.name}");
      if (!DeviceRegistry.hasByName(bluetoothDevice.name)) {
        Flogger.d("Device not registered::${bluetoothDevice.name}");
        return null;
      }
      BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.getByName(bluetoothDevice.name);
      BaseStatefulDevice baseStatefulDevice = BaseStatefulDevice(baseDeviceDefinition, BaseStoredDevice(baseDeviceDefinition.uuid, bluetoothDevice.id.id), bluetoothDevice);
      bluetoothDevice.connect(autoConnect: true);
      await registerDeviceListeners(baseStatefulDevice);

      Set<BaseStatefulDevice> knownDevicesSet = {};
      knownDevicesSet.addAll(knownDevices.value);
      knownDevicesSet.add(baseStatefulDevice);
      knownDevices.value = knownDevicesSet;
      Flogger.d("Registered new device::${bluetoothDevice.name}");
      return baseStatefulDevice;
    } catch (e, s) {
      Flogger.e("Error in registerNewDevic:e $e", stackTrace: s);
      return null;
    }
  }*/

/*  Future<BaseStatefulDevice> registerExistingDevice(BaseStoredDevice device) async {
    Flogger.d("Registering existing device::${device.deviceDefinitionUUID}::${device.btMACAddress}");
    BluetoothDevice btDevice = BluetoothDevice.fromId(device.btMACAddress);
    BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.allDevices.firstWhere((element) => element.uuid == device.deviceDefinitionUUID);
    BaseStatefulDevice baseStatefulDevice = BaseStatefulDevice(baseDeviceDefinition, device, btDevice);
    btDevice.connect(autoConnect: true); //TODO: connect to autoconnect option
    await registerDeviceListeners(baseStatefulDevice);

    Set<BaseStatefulDevice> knownDevicesSet = {};
    knownDevicesSet.addAll(knownDevices.value);
    knownDevicesSet.add(baseStatefulDevice);
    knownDevices.value = knownDevicesSet;
    Flogger.d("Registered new device::${device.name}");
    return baseStatefulDevice;
  }*/

/*  Future<BaseStatefulDevice> registerDeviceListeners(BaseStatefulDevice baseStatefulDevice) async {
    Flogger.d("Registering device listeners::${baseStatefulDevice.device.name}");
    baseStatefulDevice.device.state.listen((event) {
      Flogger.i("BTDeviceState::$event");

      if (event == BluetoothDeviceState.connected) {
        Flogger.i("${event.name}::BTDeviceServices::Discovering services");

        baseStatefulDevice.device.discoverServices();
        baseStatefulDevice.device.services.listen((servicesEvent) async {
          Flogger.i("${event.name}::BTDeviceServices::$servicesEvent");

          for (BluetoothService service in servicesEvent) {
            Flogger.i("${event.name}::BTDeviceServices::${service.uuid}");

            if (service.uuid == Guid(batteryService)) {
              baseStatefulDevice.batteryCharacteristic = service.characteristics.first;
              await baseStatefulDevice.batteryCharacteristic?.setNotifyValue(true);
              baseStatefulDevice.batteryCharacteristic?.value.listen((event) {
                Flogger.d("${baseStatefulDevice.device.name}::BTDeviceService::${service.uuid}::$event");
                Utf8Decoder decoder = const Utf8Decoder();
                String data = decoder.convert(event);
                Flogger.d("${baseStatefulDevice.device.name}::Battery::$data");
                baseStatefulDevice.battery = double.parse(data);
              });
            }
            if (service.uuid == Guid(baseStatefulDevice.baseDeviceDefinition.bleDeviceService)) {
              baseStatefulDevice.readCharacteristic = service.characteristics.firstWhere((element) => element.uuid == Guid(baseStatefulDevice.baseDeviceDefinition.bleRxCharacteristic));
              baseStatefulDevice.writeCharacteristic = service.characteristics.firstWhere((element) => element.uuid == Guid(baseStatefulDevice.baseDeviceDefinition.bleTxCharacteristic));
              await baseStatefulDevice.readCharacteristic?.setNotifyValue(true);
            }

            baseStatefulDevice.readCharacteristic?.value.listen((event) {
              Utf8Decoder decoder = const Utf8Decoder();
              String data = decoder.convert(event);
              Flogger.d("${baseStatefulDevice.device.name}::BTDeviceService::${service.uuid}::$data");

              btMessage message = btMessage(data, baseStatefulDevice);
              incomingMessageQueue.add(message);
            });
          }
        });
      } else if (event == BluetoothDeviceState.disconnected) {
        Flogger.i("${event.name}::BTDeviceServices::Disconnecting services");
        baseStatefulDevice.batteryCharacteristic = null;
        baseStatefulDevice.readCharacteristic = null;
        baseStatefulDevice.writeCharacteristic = null;
      }
    });
    Flogger.d("Registered listeners for device::${baseStatefulDevice.device.name}");
    return baseStatefulDevice;
  }

  void turnOnBluetooth(FlutterBluePlus flutterBlue) async {
    if (await flutterBlue.isOn == false) {
      Flogger.i("Bluetooth is off, turning on");
      await flutterBlue.turnOn();
    }
  }*/
}
