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
import 'package:riverpod/src/framework.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/command_history.dart';
import 'package:tail_app/Backend/command_queue.dart';
import 'package:tail_app/Backend/version.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../Frontend/utils.dart';
import '../../constants.dart';
import '../Definitions/Device/device_definition.dart';
import '../device_registry.dart';
import '../firmware_update.dart';
import '../logging_wrappers.dart';
import '../sensors.dart';
import 'bluetooth_manager.dart';
import 'bluetooth_message.dart';

part 'bluetooth_manager_plus.g.dart';

final _bluetoothPlusLogger = log.Logger('BluetoothPlus');

ValueNotifier<bool> isBluetoothEnabled = ValueNotifier(false);

bool _didInitFlutterBluePlus = false;

@Riverpod(keepAlive: true)
class InitFlutterBluePlus extends _$InitFlutterBluePlus {
  StreamSubscription<OnServicesResetEvent>? _onServicesResetStreamSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateStreamSubscription;

  @override
  Future<void> build() async {
    if (await ref.read(getBluetoothPermissionProvider.future) == BluetoothPermissionStatus.denied) {
      ref.invalidateSelf();
      _bluetoothPlusLogger.info("Bluetooth permission not granted");
      return;
    }

    _didInitFlutterBluePlus = true;

    await FlutterBluePlus.setLogLevel(LogLevel.warning, color: true);
    // first, check if bluetooth is supported by your hardware
    // Note: The platform is initialized on the first call to any FlutterBluePlus method.
    if (await FlutterBluePlus.isSupported == false) {
      _bluetoothPlusLogger.info("Bluetooth not supported by this device");
      return;
    }

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
    // starts the listener providers
    ref.watch(_keepGearAwakeProvider);
    ref.watch(_mTUChangedProvider);
    ref.watch(_onCharacteristicReceivedProvider);
    ref.watch(_onConnectionStateChangedProvider);
    ref.watch(_onDiscoveredServicesProvider);
    ref.watch(_rSSIChangedProvider);
    ref.watch(_onScanResultsProvider);
    // Shut down bluetooth related things
    ref.onDispose(() async {
      //Disconnect any gear
      for (var element in FlutterBluePlus.connectedDevices) {
        await disconnect(element.remoteId.str);
      }
      await _onServicesResetStreamSubscription?.cancel();
      _onServicesResetStreamSubscription = null;
      await _adapterStateStreamSubscription?.cancel();
      _adapterStateStreamSubscription = null;
      ref.invalidate(_keepGearAwakeProvider);
      ref.invalidate(_mTUChangedProvider);
      ref.invalidate(_onCharacteristicReceivedProvider);
      ref.invalidate(_onConnectionStateChangedProvider);
      ref.invalidate(_onDiscoveredServicesProvider);
      ref.invalidate(_rSSIChangedProvider);
      ref.invalidate(_onScanResultsProvider);
      // Mark all gear disconnected;
      ref.read(knownDevicesProvider).forEach(
            (key, value) => value.deviceConnectionState.value = ConnectivityState.disconnected,
          );
      isBluetoothEnabled.value = false;
      _didInitFlutterBluePlus = false; // Allow restarting ble stack
    });
    ref.read(scanProvider);
  }
}

@Riverpod(keepAlive: true)
class _MTUChanged extends _$MTUChanged {
  StreamSubscription<OnMtuChangedEvent>? streamSubscription;

  @override
  void build() {
    streamSubscription = FlutterBluePlus.events.onMtuChanged.listen(listener);
    ref.onDispose(
      () => streamSubscription?.cancel(),
    );
  }

  void listener(OnMtuChangedEvent event) {
    _bluetoothPlusLogger.info('${event.device.advName} MTU:${event.mtu}');
    BaseStatefulDevice? statefulDevice = ref.read(knownDevicesProvider)[event.device.remoteId.str];
    statefulDevice?.mtu.value = event.mtu;
  }
}

@Riverpod(keepAlive: true)
class _OnDiscoveredServices extends _$OnDiscoveredServices {
  StreamSubscription<OnDiscoveredServicesEvent>? streamSubscription;

  @override
  void build() {
    streamSubscription = FlutterBluePlus.events.onDiscoveredServices.listen(listener, onError: (e) => _bluetoothPlusLogger.warning("Unable to discover services: $e", e));
    ref.onDispose(
      () => streamSubscription?.cancel(),
    );
  }

  Future<void> listener(OnDiscoveredServicesEvent event) async {
    //_bluetoothPlusLogger.info('${event.device} ${event.services}');
    //Subscribes to all characteristics
    for (BluetoothService service in event.services) {
      BluetoothUartService? bluetoothUartService = uartServices.firstWhereOrNull(
        (element) => element.bleDeviceService.toLowerCase() == service.serviceUuid.str128.toLowerCase(),
      );
      if (bluetoothUartService != null) {
        BaseStatefulDevice? statefulDevice = ref.read(knownDevicesProvider)[event.device.remoteId.str];
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
}

@Riverpod(keepAlive: true)
class _RSSIChanged extends _$RSSIChanged {
  StreamSubscription<OnReadRssiEvent>? streamSubscription;

  @override
  void build() {
    streamSubscription = FlutterBluePlus.events.onReadRssi.listen(listener, onError: (e) => _bluetoothPlusLogger.warning("Unable to read rssi: $e", e));
    ref.onDispose(
      () => streamSubscription?.cancel(),
    );
  }

  void listener(OnReadRssiEvent event) {
    _bluetoothPlusLogger.info('${event.device.advName} RSSI:${event.rssi}');
    BaseStatefulDevice? statefulDevice = ref.read(knownDevicesProvider)[event.device.remoteId.str];
    statefulDevice?.rssi.value = event.rssi;
  }
}

@Riverpod(keepAlive: true)
class _OnConnectionStateChanged extends _$OnConnectionStateChanged {
  StreamSubscription<OnConnectionStateChangedEvent>? streamSubscription;

  @override
  void build() {
    streamSubscription = FlutterBluePlus.events.onConnectionStateChanged.listen(listener);
    ref.onDispose(
      () => streamSubscription?.cancel(),
    );
  }

  Future<void> listener(OnConnectionStateChangedEvent event) async {
    _bluetoothPlusLogger.info('${event.device.advName} ${event.connectionState}');
    BuiltMap<String, BaseStatefulDevice> knownDevices = ref.read(knownDevicesProvider);
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
        Future(() => ref.read(knownDevicesProvider.notifier).add(statefulDevice));
      }
    } else {
      baseStoredDevice = BaseStoredDevice(deviceDefinition.uuid, deviceID, deviceDefinition.deviceType.color(ref: ref).toARGB32())..name = getNameFromBTName(deviceDefinition.btName);
      int code = Random().nextInt(899999) + 100000;
      baseStoredDevice.conModePin = code.toString();
      statefulDevice = BaseStatefulDevice(deviceDefinition, baseStoredDevice);
      Future(() => ref.read(knownDevicesProvider.notifier).add(statefulDevice));
    }
    statefulDevice.deviceConnectionState.value = event.connectionState == BluetoothConnectionState.connected ? ConnectivityState.connected : ConnectivityState.disconnected;
    if (bluetoothConnectionState == BluetoothConnectionState.connected) {
      bluetoothDevice.readRssi().catchError((e) => -1).onError(
            (error, stackTrace) => -1,
          );
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
          foregroundTaskOptions: ForegroundTaskOptions(
            eventAction: ForegroundTaskEventAction.repeat(250),
            allowWakeLock: true,
          ),
        );
        FlutterForegroundTask.startService(
          notificationTitle: "Gear Connected",
          notificationText: "Gear is connected to The Tail Company app",
          notificationIcon: const NotificationIcon(
            metaDataName: 'com.codel1417.tailApp.notificationIcon',
          ),
        );
        FlutterForegroundTask.setOnLockScreenVisibility(true);
      }
      await event.device.discoverServices();

      // queue up commands to get gear info
      ref.read(CommandQueueProvider(statefulDevice).notifier)
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
        ref.read(triggerListProvider).where((element) => element.enabled).forEach(
          (element) {
            element.enabled = false;
          },
        );
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
        ref.read(knownDevicesProvider.notifier).remove(bluetoothDevice.remoteId.str);
      }
    }
  }
}

@Riverpod(keepAlive: true)
class _OnCharacteristicReceived extends _$OnCharacteristicReceived {
  StreamSubscription<OnCharacteristicReceivedEvent>? streamSubscription;

  @override
  void build() {
    streamSubscription = FlutterBluePlus.events.onCharacteristicReceived.listen(listener);
    ref.onDispose(
      () => streamSubscription?.cancel(),
    );
  }

  Future<void> listener(OnCharacteristicReceivedEvent event) async {
    _bluetoothPlusLogger.info('onCharacteristicReceived ${event.device.advName} ${event.characteristic.uuid.str128} ${event.value}');

    BluetoothDevice bluetoothDevice = event.device;
    BluetoothCharacteristic bluetoothCharacteristic = event.characteristic;
    List<int> values = event.value;
    BaseStatefulDevice? statefulDevice = ref.read(knownDevicesProvider)[bluetoothDevice.remoteId.str];
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
        ref.read(commandHistoryProvider(statefulDevice).notifier).add(type: MessageHistoryType.receive, message: value);

        statefulDevice.batteryCharging.value = value == "CHARGE ON";
      } catch (e) {
        _bluetoothPlusLogger.warning("Unable to read values: $values", e);
        ref.read(commandHistoryProvider(statefulDevice).notifier).add(type: MessageHistoryType.receive, message: "Unknown: ${values.toString()}");

        return;
      }
    } else if (statefulDevice.bluetoothUartService.value != null &&
        bluetoothCharacteristic.characteristicUuid.str128.toLowerCase() == statefulDevice.bluetoothUartService.value!.bleRxCharacteristic.toLowerCase()) {
      String value = "";
      try {
        value = const Utf8Decoder().convert(values);
      } catch (e) {
        _bluetoothPlusLogger.warning("Unable to read values: $values $e");
        ref.read(commandHistoryProvider(statefulDevice).notifier).add(type: MessageHistoryType.receive, message: "Unknown: ${values.toString()}");
        return;
      }
      ref.read(commandHistoryProvider(statefulDevice).notifier).add(type: MessageHistoryType.receive, message: value);

      // Firmware Version
      if (value.startsWith("VER")) {
        statefulDevice.fwVersion.value = getVersionSemVer(value.substring(value.indexOf(" ")));
        if (statefulDevice.isTailCoNTROL.value == TailControlStatus.tailControl) {
          ref.read(CommandQueueProvider(statefulDevice).notifier).addCommand(
                BluetoothMessage(
                  message: "READNVS",
                  timestamp: DateTime.timestamp(),
                ),
              );
        }
        // Don't check for updates unless both values are set
        if (statefulDevice.hwVersion.value.isNotEmpty && statefulDevice.fwVersion.value != Version()) {
          await ref.read(hasOtaUpdateProvider(statefulDevice).future).catchError((error, stackTrace) => true);
        }
        // Sent after VER message
      } else if (value.startsWith("GLOWTIP")) {
        String substring = value.substring(value.indexOf(" ")).trim();
        if (substring == 'TRUE') {
          statefulDevice.hasGlowtip.value = GlowtipStatus.glowtip;
        } else if (substring == 'FALSE') {
          statefulDevice.hasGlowtip.value = GlowtipStatus.noGlowtip;
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
          await ref.read(hasOtaUpdateProvider(statefulDevice).future).catchError((error, stackTrace) => true);
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
}

@Riverpod(keepAlive: true, dependencies: [InitFlutterBluePlus])
class _KeepGearAwake extends _$KeepGearAwake {
  StreamSubscription? streamSubscription;

  @override
  void build() {
    ref.onDispose(
      () => streamSubscription?.cancel(),
    );
    streamSubscription = Stream.periodic(const Duration(seconds: 15)).listen(listener);
  }

  void listener(dynamic event) {
    BuiltMap<String, BaseStatefulDevice> knownDevices = ref.read(knownDevicesProvider);
    for (var element in FlutterBluePlus.connectedDevices) {
      BaseStatefulDevice? device = knownDevices[element.remoteId.str];
      if (device != null) {
        // required to keep the connection open on IOS, otherwise the app will suspend and walk mode will stop working
        ref.read(commandQueueProvider(device).notifier).addCommand(BluetoothMessage(message: "PING", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
        // Battery characteristic works fine for tailcontrol, so we don't need to manually request the battery level
        if (device.isTailCoNTROL.value != TailControlStatus.tailControl) {
          ref.read(commandQueueProvider(device).notifier).addCommand(BluetoothMessage(message: "BATT", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
        }
        element.readRssi().catchError((e) => -1).onError(
              (error, stackTrace) => -1,
            );

        if (device.fwVersion.value == Version()) {
          ref.read(commandQueueProvider(device).notifier).addCommand(BluetoothMessage(message: "VER", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
        }
        if (device.hwVersion.value.isEmpty) {
          ref.read(commandQueueProvider(device).notifier).addCommand(BluetoothMessage(message: "HWVER", priority: Priority.low, type: CommandType.system, timestamp: DateTime.now()));
        }
      }
    }
  }
}

@Riverpod(keepAlive: true)
class _OnScanResults extends _$OnScanResults {
  StreamSubscription? streamSubscription;

  @override
  void build() {
    ref.onDispose(
      () => streamSubscription?.cancel(),
    );
    streamSubscription = FlutterBluePlus.onScanResults.listen(
      listener,
      onError: (e, s) => _bluetoothPlusLogger.severe("", e, s),
    );
  }

  Future<void> listener(List<ScanResult> results) async {
    if (results.isNotEmpty) {
      ScanResult r = results.last; // the most recently found device
      _bluetoothPlusLogger.info('${r.device.remoteId}: "${r.advertisementData.advName}" found!');
      BuiltMap<String, BaseStatefulDevice> knownDevices = ref.read(knownDevicesProvider);
      if (knownDevices.containsKey(r.device.remoteId.str) &&
          knownDevices[r.device.remoteId.str]?.deviceConnectionState.value == ConnectivityState.disconnected &&
          !knownDevices[r.device.remoteId.str]!.disableAutoConnect) {
        knownDevices[r.device.remoteId.str]?.deviceConnectionState.value = ConnectivityState.connecting;
        await connect(r.device.remoteId.str);
      }
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
            "Failed to connect to ${result.device.advName}. Attempt $retry/${HiveProxy.getOrDefault(settings, gearConnectRetryAttempts, defaultValue: gearConnectRetryAttemptsDefault)}", e);
        await Future.delayed(Duration(milliseconds: 250));
      }
    }
  }
}

@Riverpod(keepAlive: true)
class Scan extends _$Scan {
  StreamSubscription<bool>? isScanningStreamSubscription;
  @override
  ScanReason build() {
    isScanningStreamSubscription = FlutterBluePlus.isScanning.listen(onIsScanningChange);

    ref.listen(isAllKnownGearConnectedProvider, isAllKnownGearConnectedProviderListener);

    Hive.box(settings).listenable(keys: [hasCompletedOnboarding])
      ..removeListener(isAllGearConnectedListener)
      ..addListener(isAllGearConnectedListener);
    isBluetoothEnabled
      ..removeListener(isAllGearConnectedListener)
      ..addListener(isAllGearConnectedListener);
    Future.delayed(
      Duration(milliseconds: 5),
      () => isAllGearConnectedListener(),
    );

    ref.onDispose(
      () {
        isScanningStreamSubscription?.cancel();
        stopScan();
      },
    );
    return ScanReason.notScanning;
  }

  void isAllKnownGearConnectedProviderListener(bool? previous, bool next) {
    isAllGearConnectedListener();
  }

  void onIsScanningChange(bool isScanning) {
    if (state != ScanReason.notScanning && !isScanning) {
      state = ScanReason.notScanning;
    }
  }

  Future<void> beginScan({required ScanReason scanReason, Duration? timeout}) async {
    if (_didInitFlutterBluePlus && !FlutterBluePlus.isScanningNow && isBluetoothEnabled.value) {
      _bluetoothPlusLogger.info("Starting scan");
      state = scanReason;
      await FlutterBluePlus.startScan(withServices: DeviceRegistry.getAllIds().map(Guid.new).toList(), continuousUpdates: timeout == null, androidScanMode: AndroidScanMode.lowPower, timeout: timeout);
    }
  }

  void stopActiveScan() {
    if (state == ScanReason.addGear) {
      state = ScanReason.background;
    }
    isAllGearConnectedListener();
  }

  Future<void> stopScan() async {
    if (!_didInitFlutterBluePlus) {
      return;
    }
    _bluetoothPlusLogger.info("stopScan called");
    await FlutterBluePlus.stopScan();
    state = ScanReason.notScanning;
  }

  void isAllGearConnectedListener() {
    if (!ref.exists(isAllKnownGearConnectedProvider)) {
      return;
    }

    bool allConnected = ref.read(isAllKnownGearConnectedProvider);
    bool isInOnboarding = HiveProxy.getOrDefault(settings, hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault) < hasCompletedOnboardingVersionToAgree;
    if ((!allConnected || isInOnboarding) && isBluetoothEnabled.value) {
      beginScan(scanReason: ScanReason.background);
    } else if ((allConnected && !isInOnboarding && state == ScanReason.background) || !isBluetoothEnabled.value) {
      stopScan();
    }
  }
}

enum ScanReason { background, addGear, notScanning }

Future<void> sendMessage(BaseStatefulDevice device, List<int> message, {bool withoutResponse = false}) async {
  if (!_didInitFlutterBluePlus) {
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
