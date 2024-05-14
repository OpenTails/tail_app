import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:cross_platform/cross_platform.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
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

import '../../Frontend/utils.dart';
import '../../constants.dart';
import '../auto_move.dart';
import '../firmware_update.dart';
import '../sensors.dart';
import 'bluetooth_manager.dart';
import 'bluetooth_message.dart';

part 'bluetooth_manager_plus.g.dart';

StreamSubscription<OnConnectionStateChangedEvent>? onConnectionStateChangedStreamSubscription;
StreamSubscription<OnReadRssiEvent>? onReadRssiStreamSubscription;
StreamSubscription<OnDiscoveredServicesEvent>? onDiscoveredServicesStreamSubscription;
StreamSubscription<OnCharacteristicReceivedEvent>? onCharacteristicReceivedStreamSubscription;
StreamSubscription<OnServicesResetEvent>? onServicesResetStreamSubscription;
StreamSubscription<BluetoothAdapterState>? adapterStateStreamSubscription;
StreamSubscription<List<ScanResult>>? onScanResultsStreamSubscription;
StreamSubscription<OnMtuChangedEvent>? onMtuChanged;

final bluetoothPlusLogger = log.Logger('BluetoothPlus');

ValueNotifier<bool> isAnyGearConnected = ValueNotifier(false);
ValueNotifier<bool> isBluetoothEnabled = ValueNotifier(false);

@Riverpod(keepAlive: true)
Future<void> initFlutterBluePlus(InitFlutterBluePlusRef ref) async {
  await FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  // first, check if bluetooth is supported by your hardware
  // Note: The platform is initialized on the first call to any FlutterBluePlus method.
  if (await FlutterBluePlus.isSupported == false) {
    bluetoothPlusLogger.info("Bluetooth not supported by this device");
    return;
  }

  // listen to *any device* connection state changes
  onConnectionStateChangedStreamSubscription = FlutterBluePlus.events.onConnectionStateChanged.listen((event) async {
    bluetoothPlusLogger.info('${event.device} ${event.connectionState}');
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
        bluetoothPlusLogger.fine('Enabling wakelock');
        WakelockPlus.enable();
      }
      if (Platform.isAndroid) {
        //start foreground service on device connected. Library handles duplicate start calls
        bluetoothPlusLogger.fine('Requesting notification permission');
        bluetoothPlusLogger.finer('Requesting notification permission result${await Permission.notification.request()}'); // Used only for Foreground service
        ForegroundServiceHandler.notification.setPriority(AndroidNotificationPriority.LOW);
        ForegroundServiceHandler.notification.setTitle("Gear Connected");
        bluetoothPlusLogger.fine('Starting foreground service');
        ForegroundService().start();
      }
      await event.device.discoverServices();
      // Try to get firmware update information from Tail Company site
      if (deviceDefinition.fwURL != "" && statefulDevice.fwInfo.value == null) {
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
        ).onError((error, stackTrace) {
          bluetoothLog.warning("Unable to get Firmware info for ${statefulDevice.baseDeviceDefinition.fwURL} :$error", error, stackTrace);
        });
      }
      statefulDevice.keepAliveStreamSubscription = Stream.periodic(const Duration(seconds: 15)).listen((event) async {
        if (ref.read(knownDevicesProvider).containsKey(deviceID) && statefulDevice.deviceConnectionState.value == ConnectivityState.connected) {
          statefulDevice.commandQueue.addCommand(BluetoothMessage(message: "PING", device: statefulDevice, priority: Priority.low, type: Type.system));
          bluetoothDevice.readRssi();
        } else {
          statefulDevice.keepAliveStreamSubscription?.cancel();
          bluetoothLog.warning("Disconnected from device");
        }
      }, cancelOnError: true);
    }
    if (bluetoothConnectionState == BluetoothConnectionState.disconnected) {
      bluetoothPlusLogger.info("Disconnected from device: ${bluetoothDevice.remoteId.str}");
      // We don't want to display the app review screen right away. We keep track of gear disconnects and after 5 we try to display the review dialog.
      int count = SentryHive.box(settings).get(gearDisconnectCount, defaultValue: gearDisconnectCountDefault) + 1;
      if (count > 5 && SentryHive.box(settings).get(hasDisplayedReview, defaultValue: hasDisplayedReviewDefault)) {
        SentryHive.box(settings).put(shouldDisplayReview, true);
        bluetoothPlusLogger.finer('Setting shouldDisplayReview to true');
      } else {
        SentryHive.box(settings).put(gearDisconnectCount, count);
        bluetoothPlusLogger.finer('Setting gearDisconnectCount to $count');
      }
      //ref.read(snackbarStreamProvider.notifier).add(SnackBar(content: Text("Disconnected from ${baseStatefulDevice.baseStoredDevice.name}")));

      // remove foreground service if no devices connected
      int deviceCount = knownDevices.values.where((element) => element.deviceConnectionState.value == ConnectivityState.connected).length;
      bool lastDevice = deviceCount == 0;
      if (lastDevice) {
        bluetoothPlusLogger.fine('Last gear detected');
        // Disable all triggers on last device
        ref.read(triggerListProvider).where((element) => element.enabled).forEach(
          (element) {
            element.enabled = false;
          },
        );
        isAnyGearConnected.value = false;
        bluetoothPlusLogger.finer('Disabling wakelock');
        // stop wakelock if its started
        WakelockPlus.disable();
        // Close foreground service
        if (Platform.isAndroid) {
          bluetoothPlusLogger.finer('Stopping foreground service');
          ForegroundService().stop();
        }
      }
      // if the forget button was used, remove the device
      if (knownDevices[bluetoothDevice.remoteId.str]!.forgetOnDisconnect) {
        bluetoothPlusLogger.finer('forgetting about gear');
        ref.read(knownDevicesProvider.notifier).remove(bluetoothDevice.remoteId.str);
      }
    }
  });
  onReadRssiStreamSubscription = FlutterBluePlus.events.onReadRssi.listen((event) {
    bluetoothPlusLogger.info('${event.device} RSSI:${event.rssi}');
    BaseStatefulDevice? statefulDevice = ref.read(knownDevicesProvider)[event.device.remoteId.str];
    statefulDevice?.rssi.value = event.rssi;
  });
  onMtuChanged = FlutterBluePlus.events.onMtuChanged.listen((event) {
    bluetoothPlusLogger.info('${event.device} MTU:${event.mtu}');
    BaseStatefulDevice? statefulDevice = ref.read(knownDevicesProvider)[event.device.remoteId.str];
    statefulDevice?.mtu.value = event.mtu;
  });
  onDiscoveredServicesStreamSubscription = FlutterBluePlus.events.onDiscoveredServices.listen((event) async {
    bluetoothPlusLogger.info('${event.device} ${event.services}');
    BaseStatefulDevice? statefulDevice = ref.read(knownDevicesProvider)[event.device.remoteId.str];
    //Subscribes to all characteristics
    for (BluetoothService service in event.services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        await characteristic.setNotifyValue(true);
      }
    }
    // Add initial commands to the queue
    statefulDevice?.commandQueue.addCommand(BluetoothMessage(message: "VER", device: statefulDevice, priority: Priority.low, type: Type.system));
    statefulDevice?.commandQueue.addCommand(BluetoothMessage(message: "HWVER", device: statefulDevice, priority: Priority.low, type: Type.system));
    if (statefulDevice!.baseStoredDevice.autoMove) {
      changeAutoMove(statefulDevice);
    }
  });
  onCharacteristicReceivedStreamSubscription = FlutterBluePlus.events.onCharacteristicReceived.listen((event) {
    bluetoothPlusLogger.info('${event.device} ${event.value}');

    BluetoothDevice bluetoothDevice = event.device;
    BluetoothCharacteristic bluetoothCharacteristic = event.characteristic;
    List<int> values = event.value;
    BaseStatefulDevice? statefulDevice = ref.read(knownDevicesProvider)[bluetoothDevice.remoteId.str];
    // get Device object
    // set value
    if (bluetoothCharacteristic.characteristicUuid == Guid("00002a19-0000-1000-8000-00805f9b34fb")) {
      statefulDevice?.batteryLevel.value == values.first;
      statefulDevice?.batlevels.add(FlSpot(statefulDevice.stopWatch.elapsed.inSeconds.toDouble(), values.first.toDouble()));
    }
    if (bluetoothCharacteristic.characteristicUuid == Guid("5073792e-4fc0-45a0-b0a5-78b6c1756c91")) {
      statefulDevice?.batteryCharging.value = const Utf8Decoder().convert(values) == "CHARGE ON";
    }
    if (bluetoothCharacteristic.characteristicUuid.str == statefulDevice?.baseDeviceDefinition.bleRxCharacteristic) {
      String value = const Utf8Decoder().convert(values);
      statefulDevice?.messageHistory.add(MessageHistoryEntry(type: MessageHistoryType.receive, message: value));
      // Firmware Version
      if (value.startsWith("VER")) {
        statefulDevice?.fwVersion.value = value.substring(value.indexOf(" "));
        if (statefulDevice?.fwInfo.value != null) {
          if (statefulDevice?.fwInfo.value?.version.split(" ")[1] != statefulDevice?.fwVersion.value) {
            statefulDevice?.hasUpdate.value = true;
          }
        }
        // Sent after VER message
      } else if (value.startsWith("GLOWTIP")) {
        statefulDevice?.hasGlowtip.value = "TRUE" == value.substring(value.indexOf(" "));
      } else if (value.contains("BUSY")) {
        //statefulDevice.deviceState.value = DeviceState.busy;
      } else if (value.contains("LOWBATT")) {
        statefulDevice?.batteryLow.value = true;
      } else if (value.contains("ERR")) {
        statefulDevice?.gearReturnedError.value = true;
      } else if (value.contains("HWVER")) {
        // Hardware Version
        statefulDevice?.hwVersion.value = value.substring(value.indexOf(" "));
      }
    }
  });
  onServicesResetStreamSubscription = FlutterBluePlus.events.onServicesReset.listen((event) async {
    bluetoothPlusLogger.info("${event.device} onServicesReset");
    await event.device.discoverServices();
  });
  // handle bluetooth on & off
  // note: for iOS the initial state is typically BluetoothAdapterState.unknown
  // note: if you have permissions issues you will get stuck at BluetoothAdapterState.unauthorized
  adapterStateStreamSubscription = FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
    bluetoothPlusLogger.info(state);
    isBluetoothEnabled.value = state == BluetoothAdapterState.on;
  });
  onScanResultsStreamSubscription = FlutterBluePlus.onScanResults.listen(
    (results) async {
      if (results.isNotEmpty) {
        ScanResult r = results.last; // the most recently found device
        bluetoothPlusLogger.info('${r.device.remoteId}: "${r.advertisementData.advName}" found!');
        Map<String, BaseStatefulDevice> knownDevices = ref.read(knownDevicesProvider);
        if (knownDevices.containsKey(r.device.remoteId.str) && knownDevices[r.device.remoteId.str]?.deviceConnectionState.value == ConnectivityState.disconnected && !knownDevices[r.device.remoteId.str]!.disableAutoConnect) {
          knownDevices[r.device.remoteId.str]?.deviceConnectionState.value = ConnectivityState.connecting;
          await r.device.connect();
        }
      }
    },
    onError: (e) => bluetoothPlusLogger.severe(e),
  );
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
        bluetoothDevice.servicesList.firstWhereOrNull((element) => element.uuid.str == device.baseDeviceDefinition.bleDeviceService)?.characteristics.firstWhereOrNull((element) => element.characteristicUuid.str == device.baseDeviceDefinition.bleTxCharacteristic);
    await bluetoothCharacteristic?.write(message, withoutResponse: withoutResponse, allowLongWrite: allowLongWrite);
  }
}