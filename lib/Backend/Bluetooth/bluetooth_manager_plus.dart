import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:logging/logging.dart' as log;
import 'package:permission_handler/permission_handler.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/command_history.dart';
import 'package:tail_app/Backend/version.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../Frontend/utils.dart';
import '../../constants.dart';
import '../Definitions/Device/device_definition.dart';
import '../device_registry.dart';
import '../firmware_update.dart';
import '../logging_wrappers.dart';
import '../sensors.dart';
import 'known_devices.dart';
import 'bluetooth_message.dart';

final _bluetoothPlusLogger = log.Logger('BluetoothPlus');

ValueNotifier<bool> isBluetoothEnabled = ValueNotifier(false);

bool _didInitFlutterBluePlus = false;

Future<void> initFlutterBluePlus() async {
  if (_didInitFlutterBluePlus) {
    return;
  }
  if (await getBluetoothPermission() == BluetoothPermissionStatus.denied) {
    _bluetoothPlusLogger.info("Bluetooth permission not granted");
    return;
  }

  await FlutterBluePlus.setLogLevel(LogLevel.warning, color: true);
  // first, check if bluetooth is supported by your hardware
  // Note: The platform is initialized on the first call to any FlutterBluePlus method.
  if (await FlutterBluePlus.isSupported == false) {
    _bluetoothPlusLogger.info("Bluetooth not supported by this device");
    return;
  }
  _didInitFlutterBluePlus = true;

  // handle bluetooth on & off
  // note: for iOS the initial state is typically BluetoothAdapterState.unknown
  // note: if you have permissions issues you will get stuck at BluetoothAdapterState.unauthorized
  // starts the listener providers

  FlutterBluePlus.adapterState.listen(_adapterStateListener);
  FlutterBluePlus.events.onServicesReset.listen(_onServicesResetListener);
  FlutterBluePlus.events.onMtuChanged.listen(_onMtuChangedListener);
  FlutterBluePlus.events.onCharacteristicReceived.listen(_onCharacteristicReceivedListener);
  FlutterBluePlus.events.onConnectionStateChanged.listen(_onConnectionStateChangedListener);
  FlutterBluePlus.events.onReadRssi.listen(_onReadRssiListener, onError: (e) => _bluetoothPlusLogger.warning("Unable to read rssi: $e", e));
  FlutterBluePlus.events.onDiscoveredServices.listen(_onDiscoveredServicesListener, onError: (e) => _bluetoothPlusLogger.warning("Unable to discover services: $e", e));
  FlutterBluePlus.onScanResults.listen(_onScanResultsListener, onError: (e, s) => _bluetoothPlusLogger.severe("", e, s));
  Scan.instance;
  _KeepGearAwake.instance;
}

void _onServicesResetListener(OnServicesResetEvent event) async {
  _bluetoothPlusLogger.info("${event.device.advName} onServicesReset");
  await event.device.discoverServices();
}

void _adapterStateListener(BluetoothAdapterState state) {
  _bluetoothPlusLogger.info(state);
  isBluetoothEnabled.value = state == BluetoothAdapterState.on;
}

void _onMtuChangedListener(OnMtuChangedEvent event) {
  _bluetoothPlusLogger.info('${event.device.advName} MTU:${event.mtu}');
  BaseStatefulDevice? statefulDevice = KnownDevices.instance.state[event.device.remoteId.str];
  statefulDevice?.mtu.value = event.mtu;
}

Future<void> _onCharacteristicReceivedListener(OnCharacteristicReceivedEvent event) async {
  _bluetoothPlusLogger.info('onCharacteristicReceived ${event.device.advName} ${event.characteristic.uuid.str128} ${event.value}');

  BluetoothDevice bluetoothDevice = event.device;
  BluetoothCharacteristic bluetoothCharacteristic = event.characteristic;
  List<int> values = event.value;
  BaseStatefulDevice? statefulDevice = KnownDevices.instance.state[bluetoothDevice.remoteId.str];
  // get Device object
  // set value
  if (statefulDevice == null) {
    return;
  }
  if (bluetoothCharacteristic.characteristicUuid.str.toLowerCase() == "2a19") {
    statefulDevice.batteryLevel.value = values.first.toDouble();
  } else if (bluetoothCharacteristic.characteristicUuid.str128.toLowerCase() == "5073792e-4fc0-45a0-b0a5-78b6c1756c91") {
    try {
      String value = const Utf8Decoder().convert(values);
      statefulDevice.commandQueue.commandHistory.add(type: MessageHistoryType.receive, message: value);

      statefulDevice.batteryCharging.value = value == "CHARGE ON";
    } catch (e) {
      _bluetoothPlusLogger.warning("Unable to read values: $values", e);
      statefulDevice.commandQueue.commandHistory.add(type: MessageHistoryType.receive, message: "Unknown: ${values.toString()}");

      return;
    }
  } else if (statefulDevice.bluetoothUartService.value != null &&
      bluetoothCharacteristic.characteristicUuid.str128.toLowerCase() == statefulDevice.bluetoothUartService.value!.bleRxCharacteristic.toLowerCase()) {
    String value = "";
    try {
      value = const Utf8Decoder().convert(values);
    } catch (e) {
      _bluetoothPlusLogger.warning("Unable to read values: $values $e");
      statefulDevice.commandQueue.commandHistory.add(type: MessageHistoryType.receive, message: "Unknown: ${values.toString()}");
      return;
    }
    statefulDevice.commandQueue.commandHistory.add(type: MessageHistoryType.receive, message: value);

    // Firmware Version
    if (value.startsWith("VER")) {
      statefulDevice.fwVersion.value = getVersionSemVer(value.substring(value.indexOf(" ")));
      if (statefulDevice.isTailCoNTROL.value == TailControlStatus.tailControl) {
        statefulDevice.commandQueue.addCommand(BluetoothMessage(message: "READNVS", timestamp: DateTime.timestamp()));
      }
      // Don't check for updates unless both values are set
      if (statefulDevice.hwVersion.value.isNotEmpty && statefulDevice.fwVersion.value != Version()) {
        await hasOtaUpdate(statefulDevice).catchError((error, stackTrace) => true);
      }
      // Sent after VER message
    } else if (value.startsWith("GLOWTIP")) {
      String substring = value.substring(value.indexOf(" ")).trim();
      if (substring == 'TRUE') {
        statefulDevice.hasGlowtip.value = GlowtipStatus.glowtip;
      } else if (substring == 'FALSE') {
        statefulDevice.hasGlowtip.value = GlowtipStatus.noGlowtip;
      }
    } else if (value.startsWith("RGB")) {
      String substring = value.substring(value.indexOf(" ")).trim();
      if (substring == 'TRUE') {
        statefulDevice.hasRGB.value = RGBStatus.rgb;
      } else if (substring == 'FALSE') {
        statefulDevice.hasRGB.value = RGBStatus.noRGB;
      }
    } else if (value.contains("BUSY")) {
      //statefulDevice.deviceState.value = DeviceState.busy;
      statefulDevice.gearReturnedError.value = true;
    } else if (value.contains("LOWBATT")) {
      statefulDevice.batteryLow.value = true;
    } else if (value.contains("ERR")) {
      statefulDevice.gearReturnedError.value = true;
    } else if (value.contains("SHUTDOWN BEGIN")) {
      statefulDevice.deviceConnectionState.value = ConnectivityState.disconnected;
    } else if (value.contains("HWVER") || value.contains("MITAIL") || value.contains("MINITAIL") || value.contains("FLUTTERWINGS")) {
      // Hardware Version
      statefulDevice.hwVersion.value = value.substring(value.indexOf(" "));
      // Don't check for updates unless both values are set
      if (statefulDevice.hwVersion.value.isNotEmpty && statefulDevice.fwVersion.value != Version()) {
        await hasOtaUpdate(statefulDevice).catchError((error, stackTrace) => true);
      }
    } else if (value.contains("READNVS")) {
      try {
        statefulDevice.gearConfigInfo.value = GearConfigInfo.fromGearString(value.replaceFirst("READNVS ", ""));
      } on Exception catch (e) {
        _bluetoothPlusLogger.warning("Unable to parse NVS data: $e");
      }
    } else if (int.tryParse(value) != null) {
      // Battery Level
      statefulDevice.batteryLevel.value = int.parse(value).toDouble();
    }
  }
}

Future<void> _onDiscoveredServicesListener(OnDiscoveredServicesEvent event) async {
  //_bluetoothPlusLogger.info('${event.device} ${event.services}');
  //Subscribes to all characteristics
  for (BluetoothService service in event.services) {
    BluetoothUartService? bluetoothUartService = uartServices.firstWhereOrNull((element) => element.bleDeviceService.toLowerCase() == service.serviceUuid.str128.toLowerCase());
    if (bluetoothUartService != null) {
      BaseStatefulDevice? statefulDevice = KnownDevices.instance.state[event.device.remoteId.str];
      statefulDevice?.bluetoothUartService.value = bluetoothUartService;
    }
    for (BluetoothCharacteristic characteristic in service.characteristics) {
      try {
        await characteristic.setNotifyValue(true);
      } on Exception catch (e) {
        // TODO
      }
    }
  }
}

void _onReadRssiListener(OnReadRssiEvent event) {
  _bluetoothPlusLogger.info('${event.device.advName} RSSI:${event.rssi}');
  BaseStatefulDevice? statefulDevice = KnownDevices.instance.state[event.device.remoteId.str];
  statefulDevice?.rssi.value = event.rssi;
}

Future<void> _onConnectionStateChangedListener(OnConnectionStateChangedEvent event) async {
  _bluetoothPlusLogger.info('${event.device.advName} ${event.connectionState}');
  BuiltMap<String, BaseStatefulDevice> knownDevices = KnownDevices.instance.state;
  BluetoothDevice bluetoothDevice = event.device;
  BluetoothConnectionState bluetoothConnectionState = event.connectionState;
  String deviceID = bluetoothDevice.remoteId.str;

  BaseDeviceDefinition? deviceDefinition = DeviceRegistry.getByName(bluetoothDevice.advName);
  if (deviceDefinition == null) {
    bluetoothLog.warning("Unknown device found: ${bluetoothDevice.advName}");
    return;
  }

  BaseStoredDevice baseStoredDevice;
  BaseStatefulDevice statefulDevice;
  //get existing entry
  if (knownDevices.containsKey(deviceID)) {
    statefulDevice = knownDevices[deviceID]!;
    baseStoredDevice = statefulDevice.baseStoredDevice;
    if (statefulDevice.baseStoredDevice.conModePin.isEmpty) {
      int code = Random().nextInt(899999) + 100000;
      baseStoredDevice.conModePin = code.toString();
      Future(() => KnownDevices.instance.add(statefulDevice));
    }
  } else {
    baseStoredDevice = BaseStoredDevice(deviceDefinition.uuid, deviceID, deviceDefinition.deviceType.color().toARGB32())..name = getNameFromBTName(deviceDefinition.btName);
    int code = Random().nextInt(899999) + 100000;
    baseStoredDevice.conModePin = code.toString();
    statefulDevice = BaseStatefulDevice(deviceDefinition, baseStoredDevice);
    Future(() => KnownDevices.instance.add(statefulDevice));
  }
  statefulDevice.deviceConnectionState.value = event.connectionState == BluetoothConnectionState.connected ? ConnectivityState.connected : ConnectivityState.disconnected;
  if (bluetoothConnectionState == BluetoothConnectionState.connected) {
    bluetoothDevice.readRssi().catchError((e) => -1).onError((error, stackTrace) => -1);
    BaseDeviceDefinition? baseDeviceDefinition = DeviceRegistry.getByName(event.device.advName);
    if (baseDeviceDefinition == null) {
      return;
    }
    // The timer used for the time value on the battery level graph
    statefulDevice.stopWatch.start();
    if (HiveProxy.getOrDefault(settings, keepAwake, defaultValue: keepAwakeDefault)) {
      _bluetoothPlusLogger.fine('Enabling wakelock');
      WakelockPlus.enable();
    }
    if (Platform.isAndroid) {
      //start foreground service on device connected. Library handles duplicate start calls
      _bluetoothPlusLogger
        ..fine('Requesting notification permission')
        ..finer('Requesting notification permission result${await Permission.notification.request()}'); // Used only for Foreground service
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'foreground_service',
          channelName: 'Gear Connected',
          channelDescription: 'This notification appears when any gear is running.',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        foregroundTaskOptions: ForegroundTaskOptions(eventAction: ForegroundTaskEventAction.repeat(100), allowWakeLock: true),
      );
      FlutterForegroundTask.startService(
        notificationTitle: "Gear Connected",
        notificationText: "Gear is connected to The Tail Company app",
        notificationIcon: const NotificationIcon(metaDataName: 'com.codel1417.tailApp.notificationIcon'),
      );
      FlutterForegroundTask.setOnLockScreenVisibility(true);
    }
    analyticsEvent(name: "Connect Gear", props: {"Gear Type": deviceDefinition.btName});
    await event.device.discoverServices();

    // queue up commands to get gear info
    statefulDevice.commandQueue
      ..addCommand(BluetoothMessage(message: "VER", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()))
      ..addCommand(BluetoothMessage(message: "HWVER", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
  }
  if (bluetoothConnectionState == BluetoothConnectionState.disconnected) {
    _bluetoothPlusLogger.info("Disconnected from device: ${bluetoothDevice.remoteId.str}");

    // remove foreground service if no devices connected
    int deviceCount = knownDevices.values.where((element) => element.deviceConnectionState.value == ConnectivityState.connected).length;
    bool lastDevice = deviceCount == 0;
    if (lastDevice) {
      _bluetoothPlusLogger.fine('Last gear detected');
      // Disable all triggers on last device
      TriggerList.instance.state.where((element) => element.enabled).forEach((element) {
        element.enabled = false;
      });
      _bluetoothPlusLogger.finer('Disabling wakelock');
      // stop wakelock if its started
      WakelockPlus.disable();
      // Close foreground service
      if (Platform.isAndroid) {
        _bluetoothPlusLogger.finer('Stopping foreground service');
        FlutterForegroundTask.stopService();
      }
    }
    // if the forget button was used, remove the device
    if (knownDevices[bluetoothDevice.remoteId.str] != null && knownDevices[bluetoothDevice.remoteId.str]!.forgetOnDisconnect) {
      _bluetoothPlusLogger.finer('forgetting about gear');
      KnownDevices.instance.remove(bluetoothDevice.remoteId.str);
      analyticsEvent(name: "Forgetting Gear", props: {"Gear Type": deviceDefinition.btName});
    } else {
      analyticsEvent(name: "Disconnect Gear", props: {"Gear Type": deviceDefinition.btName});
    }
  }
}

class _KeepGearAwake {
  StreamSubscription? _streamSubscription;
  static final _KeepGearAwake instance = _KeepGearAwake._internal();
  _KeepGearAwake._internal() {
    KnownDevices.instance.addListener(_deviceConnectedListener);
    _deviceConnectedListener();
  }

  void _deviceConnectedListener() {
    if (KnownDevices.instance.connectedGear.isEmpty) {
      _streamSubscription?.cancel();
      _streamSubscription == null;
    } else {
      _streamSubscription ??= Stream.periodic(const Duration(seconds: 15)).listen(_periodicListener);
    }
  }

  void _periodicListener(dynamic event) {
    BuiltMap<String, BaseStatefulDevice> knownDevices = KnownDevices.instance.state;
    for (var element in FlutterBluePlus.connectedDevices) {
      BaseStatefulDevice? device = knownDevices[element.remoteId.str];
      if (device != null) {
        // required to keep the connection open on IOS, otherwise the app will suspend and walk mode will stop working
        device.commandQueue.addCommand(BluetoothMessage(message: "PING", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
        // Battery characteristic works fine for tailcontrol, so we don't need to manually request the battery level
        if (device.isTailCoNTROL.value != TailControlStatus.tailControl) {
          device.commandQueue.addCommand(BluetoothMessage(message: "BATT", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
        }
        element.readRssi().catchError((e) => -1).onError((error, stackTrace) => -1);

        if (device.fwVersion.value == Version()) {
          device.commandQueue.addCommand(BluetoothMessage(message: "VER", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
        }
        if (device.hwVersion.value.isEmpty) {
          device.commandQueue.addCommand(BluetoothMessage(message: "HWVER", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
        }
      }
    }
  }
}

Future<void> _onScanResultsListener(List<ScanResult> results) async {
  if (results.isNotEmpty) {
    ScanResult r = results.last; // the most recently found device
    _bluetoothPlusLogger.info('${r.device.remoteId}: "${r.advertisementData.advName}" found!');
    BuiltMap<String, BaseStatefulDevice> knownDevices = KnownDevices.instance.state;
    if (knownDevices.containsKey(r.device.remoteId.str) &&
        knownDevices[r.device.remoteId.str]?.deviceConnectionState.value == ConnectivityState.disconnected &&
        !knownDevices[r.device.remoteId.str]!.disableAutoConnect) {
      knownDevices[r.device.remoteId.str]?.deviceConnectionState.value = ConnectivityState.connecting;
      await connect(r.device.remoteId.str);
    }
  }
}

Future<void> disconnect(String id) async {
  if (!_didInitFlutterBluePlus) {
    return;
  }
  BluetoothDevice? device = FlutterBluePlus.connectedDevices.firstWhereOrNull((element) => element.remoteId.str == id);
  if (device != null) {
    _bluetoothPlusLogger.info("disconnecting from ${device.advName}");
    await device.disconnect(queue: false);
  }
}

Future<void> forgetBond(String id) async {
  if (!_didInitFlutterBluePlus) {
    return;
  }
  // removing bonds is supported on android
  if (!Platform.isAndroid) {
    return;
  }
  BluetoothDevice? device = FlutterBluePlus.connectedDevices.firstWhereOrNull((element) => element.remoteId.str == id);
  if (device != null) {
    _bluetoothPlusLogger.info("forgetting ${device.advName}");
    await device.removeBond();
  }
}

Future<void> connect(String id) async {
  if (!_didInitFlutterBluePlus) {
    return;
  }
  List<ScanResult> results = await FlutterBluePlus.onScanResults.first;
  ScanResult? result = results.where((element) => element.device.remoteId.str == id).firstOrNull;
  if (result != null) {
    int retry = 0;
    while (retry < HiveProxy.getOrDefault(settings, gearConnectRetryAttempts, defaultValue: gearConnectRetryAttemptsDefault)) {
      try {
        await result.device.connect();
        break;
      } on FlutterBluePlusException catch (e) {
        retry = retry + 1;
        _bluetoothPlusLogger.warning(
          "Failed to connect to ${result.device.advName}. Attempt $retry/${HiveProxy.getOrDefault(settings, gearConnectRetryAttempts, defaultValue: gearConnectRetryAttemptsDefault)}",
          e,
        );
        await Future.delayed(Duration(milliseconds: 250));
      }
    }
  }
}

class Scan with ChangeNotifier {
  StreamSubscription<bool>? isScanningStreamSubscription;
  ScanReason get state => _state;
  ScanReason _state = ScanReason.notScanning;
  static final Scan instance = Scan._internal();

  Scan._internal() {
    isScanningStreamSubscription = FlutterBluePlus.isScanning.listen(onIsScanningChange);

    Hive.box(settings).listenable(keys: [hasCompletedOnboarding])
      ..removeListener(isAllGearConnectedListener)
      ..addListener(isAllGearConnectedListener);
    isBluetoothEnabled
      ..removeListener(isAllGearConnectedListener)
      ..addListener(isAllGearConnectedListener);
    KnownDevices.instance
      ..removeListener(isAllGearConnectedListener)
      ..addListener(isAllGearConnectedListener);
    // Has to be delayed so the provider initializes before calling the listener. Otherwise we can't call ref or set state in other methods
    Future.delayed(Duration(milliseconds: 1), () => isAllGearConnectedListener());
  }

  void onIsScanningChange(bool isScanning) {
    if (_state != ScanReason.notScanning && !isScanning) {
      _state = ScanReason.notScanning;
    }
  }

  Future<void> beginScan({required ScanReason scanReason, Duration? timeout}) async {
    if (_didInitFlutterBluePlus && !FlutterBluePlus.isScanningNow && isBluetoothEnabled.value) {
      _bluetoothPlusLogger.info("Starting scan");
      _state = scanReason;
      await FlutterBluePlus.startScan(withServices: DeviceRegistry.getAllIds().map(Guid.new).toList(), continuousUpdates: timeout == null, androidScanMode: AndroidScanMode.lowPower, timeout: timeout);
    }
  }

  void stopActiveScan() {
    if (_state == ScanReason.addGear) {
      _state = ScanReason.background;
    }
    isAllGearConnectedListener();
  }

  Future<void> stopScan() async {
    if (!_didInitFlutterBluePlus) {
      return;
    }
    _bluetoothPlusLogger.info("stopScan called");
    await FlutterBluePlus.stopScan();
    _state = ScanReason.notScanning;
  }

  void isAllGearConnectedListener() {
    bool allConnected = KnownDevices.instance.isAllGearConnected;
    bool isInOnboarding = HiveProxy.getOrDefault(settings, hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault) < hasCompletedOnboardingVersionToAgree;
    if ((!allConnected || isInOnboarding) && isBluetoothEnabled.value) {
      beginScan(scanReason: ScanReason.background);
    } else if ((allConnected && !isInOnboarding && _state == ScanReason.background) || !isBluetoothEnabled.value) {
      stopScan();
    }
  }
}

enum ScanReason { background, addGear, notScanning }

Future<void> sendMessage(BaseStatefulDevice device, List<int> message, {bool withoutResponse = false}) async {
  if (!_didInitFlutterBluePlus || device.baseStoredDevice.btMACAddress.startsWith("DEV")) {
    return;
  }
  BluetoothDevice? bluetoothDevice = FlutterBluePlus.connectedDevices.firstWhereOrNull((element) => element.remoteId.str == device.baseStoredDevice.btMACAddress);
  if (bluetoothDevice != null && device.bluetoothUartService.value != null) {
    BluetoothCharacteristic? bluetoothCharacteristic = bluetoothDevice.servicesList
        .firstWhereOrNull((element) => element.uuid.str128.toLowerCase() == device.bluetoothUartService.value!.bleDeviceService.toLowerCase())
        ?.characteristics
        .firstWhereOrNull((element) => element.characteristicUuid.str128.toLowerCase() == device.bluetoothUartService.value!.bleTxCharacteristic.toLowerCase());
    if (bluetoothCharacteristic == null) {
      _bluetoothPlusLogger.warning("Unable to find bluetooth characteristic to send command to");
      return;
    }

    Future<void> future = bluetoothCharacteristic
        .write(message, withoutResponse: withoutResponse && bluetoothCharacteristic.properties.writeWithoutResponse)
        .catchError((e) => _bluetoothPlusLogger.warning("Unable to send message to ${device.baseDeviceDefinition.btName} $e", e))
        .onError((e, s) => _bluetoothPlusLogger.severe("Unable to send message to ${device.baseDeviceDefinition.btName} $e", e));
    await future;
  }
}

bool isScanningNow() {
  if (!_didInitFlutterBluePlus) {
    return false;
  }
  return FlutterBluePlus.isScanningNow;
}

Stream<bool> isScanning() {
  if (!_didInitFlutterBluePlus) {
    return Stream.value(false);
  }
  return FlutterBluePlus.isScanning;
}
