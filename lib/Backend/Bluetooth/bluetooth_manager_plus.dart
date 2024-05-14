import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:cross_platform/cross_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_service/flutter_foreground_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:logging/logging.dart' as log;
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/device_registry.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../constants.dart';
import '../sensors.dart';
import 'bluetooth_manager.dart';
import 'bluetooth_message.dart';

part 'bluetooth_manager_plus.g.dart';

StreamSubscription<OnConnectionStateChangedEvent>? _onConnectionStateChangedStreamSubscription;
StreamSubscription<OnReadRssiEvent>? _onReadRssiStreamSubscription;
StreamSubscription<OnDiscoveredServicesEvent>? _onDiscoveredServicesStreamSubscription;
StreamSubscription<OnCharacteristicReceivedEvent>? _onCharacteristicReceivedStreamSubscription;
StreamSubscription<OnServicesResetEvent>? _onServicesResetStreamSubscription;
StreamSubscription<BluetoothAdapterState>? _adapterStateStreamSubscription;
StreamSubscription<List<ScanResult>>? _onScanResultsStreamSubscription;
StreamSubscription<OnMtuChangedEvent>? _onMtuChanged;
StreamSubscription<void>? keepAliveStreamSubscription;

final _bluetoothPlusLogger = log.Logger('BluetoothPlus');

ValueNotifier<bool> isAnyGearConnected = ValueNotifier(false);
ValueNotifier<bool> isBluetoothEnabled = ValueNotifier(false);

bool _didInitFlutterBluePlus = false;

@Riverpod(keepAlive: true)
Future<void> initFlutterBluePlus(InitFlutterBluePlusRef ref) async {
  if (_didInitFlutterBluePlus) {
    return;
  }
  _didInitFlutterBluePlus = true;

  await FlutterBluePlus.setLogLevel(LogLevel.warning, color: false);
  // first, check if bluetooth is supported by your hardware
  // Note: The platform is initialized on the first call to any FlutterBluePlus method.
  if (await FlutterBluePlus.isSupported == false) {
    _bluetoothPlusLogger.info("Bluetooth not supported by this device");
    return;
  }

  // listen to *any device* connection state changes
  _onConnectionStateChangedStreamSubscription = FlutterBluePlus.events.onConnectionStateChanged.listen((event) async {
    _bluetoothPlusLogger.info('${event.device.advName} ${event.connectionState}');
    Map<String, BaseStatefulDevice> knownDevices = ref.read(knownDevicesProvider);
    BluetoothDevice bluetoothDevice = event.device;
    BluetoothConnectionState bluetoothConnectionState = event.connectionState;
    String deviceID = bluetoothDevice.remoteId.str;

    //final ISentrySpan transaction = Sentry.startTransaction('connectToDevice()', 'task');
    BaseDeviceDefinition? deviceDefinition = DeviceRegistry.getByName(bluetoothDevice.advName);
    if (deviceDefinition == null) {
      bluetoothLog.warning("Unknown device found: ${bluetoothDevice.advName}");
      //transaction.status = const SpanStatus.notFound();
      //transaction.finish();
      return;
    }

    BaseStoredDevice baseStoredDevice;
    BaseStatefulDevice statefulDevice;
    //get existing entry
    if (knownDevices.containsKey(deviceID)) {
      statefulDevice = knownDevices[deviceID]!;
      baseStoredDevice = statefulDevice.baseStoredDevice;
      //transaction.setTag('Known Device', 'Yes');
    } else {
      baseStoredDevice = BaseStoredDevice(deviceDefinition.uuid, deviceID, deviceDefinition.deviceType.color.value);
      baseStoredDevice.name = getNameFromBTName(deviceDefinition.btName);
      statefulDevice = BaseStatefulDevice(deviceDefinition, baseStoredDevice, ref);
      //transaction.setTag('Known Device', 'No');
      Future(() => ref.read(knownDevicesProvider.notifier).add(statefulDevice));
    }
    //transaction.setTag('Device Name', device.name);
    statefulDevice.deviceConnectionState.value = event.connectionState == BluetoothConnectionState.connected ? ConnectivityState.connected : ConnectivityState.disconnected;
    if (bluetoothConnectionState == BluetoothConnectionState.connected) {
      bluetoothDevice.readRssi();
      BaseDeviceDefinition? baseDeviceDefinition = DeviceRegistry.getByName(event.device.advName);
      if (baseDeviceDefinition == null) {
        return;
      }
      // The timer used for the time value on the battery level graph
      statefulDevice.stopWatch.start();
      await Fluttertoast.showToast(
        msg: "${statefulDevice.baseStoredDevice.name} has ${event.connectionState.name}",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
      );
      isAnyGearConnected.value = true;
      if (SentryHive.box(settings).get(keepAwake, defaultValue: keepAwakeDefault)) {
        _bluetoothPlusLogger.fine('Enabling wakelock');
        WakelockPlus.enable();
      }
      if (Platform.isAndroid) {
        //start foreground service on device connected. Library handles duplicate start calls
        _bluetoothPlusLogger.fine('Requesting notification permission');
        _bluetoothPlusLogger.finer('Requesting notification permission result${await Permission.notification.request()}'); // Used only for Foreground service
        ForegroundServiceHandler.notification.setPriority(AndroidNotificationPriority.LOW);
        ForegroundServiceHandler.notification.setTitle("Gear Connected");
        _bluetoothPlusLogger.fine('Starting foreground service');
        ForegroundService().start();
      }
      await event.device.discoverServices();
    }
    if (bluetoothConnectionState == BluetoothConnectionState.disconnected) {
      _bluetoothPlusLogger.info("Disconnected from device: ${bluetoothDevice.remoteId.str}");
      // We don't want to display the app review screen right away. We keep track of gear disconnects and after 5 we try to display the review dialog.
      int count = SentryHive.box(settings).get(gearDisconnectCount, defaultValue: gearDisconnectCountDefault) + 1;
      if (count > 5 && SentryHive.box(settings).get(hasDisplayedReview, defaultValue: hasDisplayedReviewDefault)) {
        SentryHive.box(settings).put(shouldDisplayReview, true);
        _bluetoothPlusLogger.finer('Setting shouldDisplayReview to true');
      } else {
        SentryHive.box(settings).put(gearDisconnectCount, count);
        _bluetoothPlusLogger.finer('Setting gearDisconnectCount to $count');
      }
      //ref.read(snackbarStreamProvider.notifier).add(SnackBar(content: Text("Disconnected from ${baseStatefulDevice.baseStoredDevice.name}")));

      // remove foreground service if no devices connected
      int deviceCount = knownDevices.values.where((element) => element.deviceConnectionState.value == ConnectivityState.connected).length;
      bool lastDevice = deviceCount == 0;
      if (lastDevice) {
        _bluetoothPlusLogger.fine('Last gear detected');
        // Disable all triggers on last device
        ref.read(triggerListProvider).where((element) => element.enabled).forEach(
          (element) {
            element.enabled = false;
          },
        );
        isAnyGearConnected.value = false;
        _bluetoothPlusLogger.finer('Disabling wakelock');
        // stop wakelock if its started
        WakelockPlus.disable();
        // Close foreground service
        if (Platform.isAndroid) {
          _bluetoothPlusLogger.finer('Stopping foreground service');
          ForegroundService().stop();
        }
      }
      // if the forget button was used, remove the device
      if (knownDevices[bluetoothDevice.remoteId.str]!.forgetOnDisconnect) {
        _bluetoothPlusLogger.finer('forgetting about gear');
        ref.read(knownDevicesProvider.notifier).remove(bluetoothDevice.remoteId.str);
      }
    }
  });
  _onReadRssiStreamSubscription = FlutterBluePlus.events.onReadRssi.listen((event) {
    _bluetoothPlusLogger.info('${event.device.advName} RSSI:${event.rssi}');
    BaseStatefulDevice? statefulDevice = ref.read(knownDevicesProvider)[event.device.remoteId.str];
    statefulDevice?.rssi.value = event.rssi;
  });
  _onMtuChanged = FlutterBluePlus.events.onMtuChanged.listen((event) {
    _bluetoothPlusLogger.info('${event.device.advName} MTU:${event.mtu}');
    BaseStatefulDevice? statefulDevice = ref.read(knownDevicesProvider)[event.device.remoteId.str];
    statefulDevice?.mtu.value = event.mtu;
  });
  _onDiscoveredServicesStreamSubscription = FlutterBluePlus.events.onDiscoveredServices.listen((event) async {
    //_bluetoothPlusLogger.info('${event.device} ${event.services}');
    //Subscribes to all characteristics
    for (BluetoothService service in event.services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        await characteristic.setNotifyValue(true);
      }
    }
  });
  _onCharacteristicReceivedStreamSubscription = FlutterBluePlus.events.onCharacteristicReceived.listen((event) {
    _bluetoothPlusLogger.info('onCharacteristicReceived ${event.device.advName} ${event.characteristic.uuid.str} ${event.value}');

    BluetoothDevice bluetoothDevice = event.device;
    BluetoothCharacteristic bluetoothCharacteristic = event.characteristic;
    List<int> values = event.value;
    BaseStatefulDevice? statefulDevice = ref.read(knownDevicesProvider)[bluetoothDevice.remoteId.str];
    // get Device object
    // set value
    if (statefulDevice == null) {
      return;
    }
    if (bluetoothCharacteristic.characteristicUuid == Guid("2a19")) {
      statefulDevice.batteryLevel.value = values.first.toDouble();
    } else if (bluetoothCharacteristic.characteristicUuid == Guid("5073792e-4fc0-45a0-b0a5-78b6c1756c91")) {
      String value = const Utf8Decoder().convert(values);
      statefulDevice.messageHistory.add(MessageHistoryEntry(type: MessageHistoryType.receive, message: value));
      statefulDevice.batteryCharging.value = value == "CHARGE ON";
    } else if (bluetoothCharacteristic.characteristicUuid == Guid(statefulDevice.baseDeviceDefinition.bleRxCharacteristic)) {
      String value = const Utf8Decoder().convert(values);
      statefulDevice.messageHistory.add(MessageHistoryEntry(type: MessageHistoryType.receive, message: value));
      // Firmware Version
      if (value.startsWith("VER")) {
        statefulDevice.fwVersion.value = value.substring(value.indexOf(" "));
        // Sent after VER message
      } else if (value.startsWith("GLOWTIP")) {
        statefulDevice.hasGlowtip.value = "TRUE" == value.substring(value.indexOf(" "));
      } else if (value.contains("BUSY")) {
        //statefulDevice.deviceState.value = DeviceState.busy;
      } else if (value.contains("LOWBATT")) {
        statefulDevice.batteryLow.value = true;
      } else if (value.contains("ERR")) {
        statefulDevice.gearReturnedError.value = true;
      } else if (value.contains("HWVER")) {
        // Hardware Version
        statefulDevice.hwVersion.value = value.substring(value.indexOf(" "));
      }
    }
  });
  _onServicesResetStreamSubscription = FlutterBluePlus.events.onServicesReset.listen((event) async {
    _bluetoothPlusLogger.info("${event.device.advName} onServicesReset");
    await event.device.discoverServices();
  });
  // handle bluetooth on & off
  // note: for iOS the initial state is typically BluetoothAdapterState.unknown
  // note: if you have permissions issues you will get stuck at BluetoothAdapterState.unauthorized
  _adapterStateStreamSubscription = FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
    _bluetoothPlusLogger.info(state);
    isBluetoothEnabled.value = state == BluetoothAdapterState.on;
  });
  _onScanResultsStreamSubscription = FlutterBluePlus.onScanResults.listen(
    (results) async {
      if (results.isNotEmpty) {
        ScanResult r = results.last; // the most recently found device
        _bluetoothPlusLogger.info('${r.device.remoteId}: "${r.advertisementData.advName}" found!');
        Map<String, BaseStatefulDevice> knownDevices = ref.read(knownDevicesProvider);
        if (knownDevices.containsKey(r.device.remoteId.str) && knownDevices[r.device.remoteId.str]?.deviceConnectionState.value == ConnectivityState.disconnected && !knownDevices[r.device.remoteId.str]!.disableAutoConnect) {
          knownDevices[r.device.remoteId.str]?.deviceConnectionState.value = ConnectivityState.connecting;
          await r.device.connect();
        }
      }
    },
    onError: (e) => _bluetoothPlusLogger.severe(e),
  );

  keepAliveStreamSubscription = Stream.periodic(const Duration(seconds: 15)).listen((event) async {
    Map<String, BaseStatefulDevice> knownDevices = ref.read(knownDevicesProvider);
    for (var element in FlutterBluePlus.connectedDevices) {
      BaseStatefulDevice? device = knownDevices[element.remoteId.str];
      if (device != null) {
        device.commandQueue.addCommand(BluetoothMessage(message: "PING", device: device, priority: Priority.low, type: Type.system));
        element.readRssi();
      }
    }
  }, cancelOnError: true);
}

Future<void> disconnect(String id) async {
  await FlutterBluePlus.connectedDevices.firstWhere((element) => element.remoteId.str == id).disconnect();
}

Future<void> connect(String id) async {
  List<ScanResult> results = await FlutterBluePlus.onScanResults.first;
  ScanResult? result = results.where((element) => element.device.remoteId.str == id).firstOrNull;
  if (result != null) {
    result.device.connect();
  }
}

Future<void> beginScan() async {
  if (!FlutterBluePlus.isScanningNow) {
    await FlutterBluePlus.startScan(withServices: DeviceRegistry.getAllIds().map((e) => Guid(e)).toList(), continuousUpdates: SentryHive.box(settings).get(alwaysScanning, defaultValue: alwaysScanningDefault), androidScanMode: AndroidScanMode.lowPower);
  }
}

Future<void> stopScan() async {
  await FlutterBluePlus.stopScan();
}

Future<void> sendMessage(BaseStatefulDevice device, List<int> message, {bool withoutResponse = false, bool allowLongWrite = false}) async {
  BluetoothDevice? bluetoothDevice = FlutterBluePlus.connectedDevices.firstWhereOrNull((element) => element.remoteId.str == device.baseStoredDevice.btMACAddress);
  if (bluetoothDevice != null) {
    BluetoothCharacteristic? bluetoothCharacteristic =
        bluetoothDevice.servicesList.firstWhereOrNull((element) => element.uuid == Guid(device.baseDeviceDefinition.bleDeviceService))?.characteristics.firstWhereOrNull((element) => element.characteristicUuid == Guid(device.baseDeviceDefinition.bleTxCharacteristic));
    await bluetoothCharacteristic?.write(message, withoutResponse: withoutResponse, allowLongWrite: allowLongWrite);
  }
}
