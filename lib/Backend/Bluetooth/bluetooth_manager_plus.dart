import 'dart:async';
import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:logging/logging.dart' as log;
import 'package:tail_app/Backend/BluetoothIssuesCheck.dart';

import '../../constants.dart';
import '../Definitions/Device/device_definition.dart';
import '../device_registry.dart';
import '../logging_wrappers.dart';
import 'known_devices.dart';

final _bluetoothPlusLogger = log.Logger('BluetoothPlus');

ValueNotifier<bool> isBluetoothEnabled = ValueNotifier(false);

bool _didInitFlutterBluePlus = false;

Future<void> initFlutterBluePlus() async {
  if (_didInitFlutterBluePlus) {
    return;
  }
  if (!await BluetoothIssues.instance.hasPermissions()) {
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
  FlutterBluePlus.events.onConnectionStateChanged.listen(
    _onConnectionStateChangedListener,
  );
  FlutterBluePlus.events.onReadRssi.listen(
    _onReadRssiListener,
    onError: (e) => _bluetoothPlusLogger.warning("Unable to read rssi: $e", e),
  );
  FlutterBluePlus.events.onDiscoveredServices.listen(
    _onDiscoveredServicesListener,
    onError: (e) =>
        _bluetoothPlusLogger.warning("Unable to discover services: $e", e),
  );
  FlutterBluePlus.onScanResults.listen(
    _onScanResultsListener,
    onError: (e, s) => _bluetoothPlusLogger.severe("", e, s),
  );
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
  BaseStatefulDevice? statefulDevice =
      KnownDevices.instance.state[event.device.remoteId.str];
  statefulDevice?.mtu.value = event.mtu;
}

Future<void> _onDiscoveredServicesListener(
  OnDiscoveredServicesEvent event,
) async {
  //_bluetoothPlusLogger.info('${event.device} ${event.services}');
  //Subscribes to all characteristics
  for (BluetoothService service in event.services) {
    BluetoothUartService? bluetoothUartService = uartServices.firstWhereOrNull(
      (element) =>
          element.bleDeviceService.toLowerCase() ==
          service.serviceUuid.str128.toLowerCase(),
    );
    if (bluetoothUartService != null) {
      BaseStatefulDevice? statefulDevice =
          KnownDevices.instance.state[event.device.remoteId.str];
      statefulDevice?.bluetoothUartService.value = bluetoothUartService;
    }
    for (BluetoothCharacteristic characteristic in service.characteristics) {
      try {
        await characteristic.setNotifyValue(true);
      } on Exception {
        bluetoothLog.warning(
          "Unable to set notify on characteristic "
          "${characteristic.characteristicUuid}",
        );
      }
    }
  }
}

void _onReadRssiListener(OnReadRssiEvent event) {
  _bluetoothPlusLogger.info('${event.device.advName} RSSI:${event.rssi}');
  BaseStatefulDevice? statefulDevice =
      KnownDevices.instance.state[event.device.remoteId.str];
  statefulDevice?.rssi.value = event.rssi;
}

Future<void> _onConnectionStateChangedListener(
  OnConnectionStateChangedEvent event,
) async {
  _bluetoothPlusLogger.info('${event.device.advName} ${event.connectionState}');
  BuiltMap<String, BaseStatefulDevice> knownDevices =
      KnownDevices.instance.state;
  BluetoothDevice bluetoothDevice = event.device;
  BluetoothConnectionState bluetoothConnectionState = event.connectionState;
  String deviceID = bluetoothDevice.remoteId.str;

  BaseDeviceDefinition? deviceDefinition = DeviceRegistry.getByName(
    bluetoothDevice.advName,
  );
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
  } else {
    baseStoredDevice = BaseStoredDevice(
      deviceDefinition.uuid,
      deviceID,
      deviceDefinition.deviceType.color().toARGB32(),
    )..name = getNameFromBTName(deviceDefinition.btName);

    statefulDevice = BaseStatefulDevice(deviceDefinition, baseStoredDevice);
  }
  statefulDevice.deviceConnectionState.value =
      event.connectionState == BluetoothConnectionState.connected
      ? ConnectivityState.connected
      : ConnectivityState.disconnected;
  if (bluetoothConnectionState == BluetoothConnectionState.connected) {
    await event.device.discoverServices();
    KnownDevices.instance.add(statefulDevice);
  }
}

class _KeepGearAwake {
  StreamSubscription? _streamSubscription;
  static final _KeepGearAwake instance = _KeepGearAwake._internal();

  _KeepGearAwake._internal() {
    _bluetoothPlusLogger.info("Starting _KeepGearAwake timer");
    // The stream/app should pause in the background, so this should be fine
    _streamSubscription ??= Stream.periodic(
      const Duration(seconds: 15),
    ).listen(_periodicListener);
  }

  void _periodicListener(dynamic event) {
    BuiltMap<String, BaseStatefulDevice> knownDevices =
        KnownDevices.instance.state;
    for (var element in FlutterBluePlus.connectedDevices) {
      element
          .readRssi()
          .catchError((e) => -1)
          .onError((error, stackTrace) => -1);
    }
  }
}

Future<void> _onScanResultsListener(List<ScanResult> results) async {
  if (results.isNotEmpty) {
    ScanResult r = results.last; // the most recently found device
    _bluetoothPlusLogger.info(
      '${r.device.remoteId}: "${r.advertisementData.advName}" found!',
    );
    BuiltMap<String, BaseStatefulDevice> knownDevices =
        KnownDevices.instance.state;

    // check for known gear with the same mac address and try to connect
    if (knownDevices.containsKey(r.device.remoteId.str) &&
        knownDevices[r.device.remoteId.str]?.deviceConnectionState.value ==
            ConnectivityState.disconnected &&
        !knownDevices[r.device.remoteId.str]!.disableAutoConnect) {
      knownDevices[r.device.remoteId.str]?.deviceConnectionState.value =
          ConnectivityState.connecting;
      await connect(r.device.remoteId.str);
    }
  }
}

Future<void> disconnect(String id) async {
  if (!_didInitFlutterBluePlus) {
    return;
  }
  BluetoothDevice? device = FlutterBluePlus.connectedDevices.firstWhereOrNull(
    (element) => element.remoteId.str == id,
  );
  KnownDevices.instance.state[id]?.deviceConnectionState.value =
      ConnectivityState.disconnected;

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
  BluetoothDevice? device = FlutterBluePlus.connectedDevices.firstWhereOrNull(
    (element) => element.remoteId.str == id,
  );
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
  ScanResult? result = results
      .where((element) => element.device.remoteId.str == id)
      .firstOrNull;
  if (result != null) {
    int retry = 0;
    while (retry <
        HiveProxy.getOrDefault(
          settings,
          gearConnectRetryAttempts,
          defaultValue: gearConnectRetryAttemptsDefault,
        )) {
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
    isScanningStreamSubscription = FlutterBluePlus.isScanning.listen(
      onIsScanningChange,
    );

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
    Future.delayed(
      Duration(milliseconds: 1),
      () => isAllGearConnectedListener(),
    );
  }

  void onIsScanningChange(bool isScanning) {
    if (_state != ScanReason.notScanning && !isScanning) {
      _state = ScanReason.notScanning;
    }
  }

  Future<void> beginScan({
    required ScanReason scanReason,
    Duration? timeout,
  }) async {
    if (_didInitFlutterBluePlus &&
        !FlutterBluePlus.isScanningNow &&
        isBluetoothEnabled.value) {
      _bluetoothPlusLogger.info("Starting scan");
      _state = scanReason;
      await FlutterBluePlus.startScan(
        withServices: DeviceRegistry.getAllIds().map(Guid.new).toList(),
        continuousUpdates: timeout == null,
        androidScanMode: AndroidScanMode.lowPower,
        timeout: timeout,
      );
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
    bool isInOnboarding =
        HiveProxy.getOrDefault(
          settings,
          hasCompletedOnboarding,
          defaultValue: hasCompletedOnboardingDefault,
        ) <
        hasCompletedOnboardingVersionToAgree;
    if ((!allConnected || isInOnboarding) && isBluetoothEnabled.value) {
      beginScan(scanReason: ScanReason.background);
    } else if ((allConnected &&
            !isInOnboarding &&
            _state == ScanReason.background) ||
        !isBluetoothEnabled.value) {
      stopScan();
    }
  }
}

enum ScanReason { background, addGear, notScanning }

Future<void> sendMessage(
  BaseStatefulDevice device,
  List<int> message, {
  bool withoutResponse = false,
}) async {
  if (!_didInitFlutterBluePlus ||
      device.baseStoredDevice.btMACAddress.startsWith(demoGearPrefix)) {
    return;
  }
  BluetoothDevice? bluetoothDevice = FlutterBluePlus.connectedDevices
      .firstWhereOrNull(
        (element) =>
            element.remoteId.str == device.baseStoredDevice.btMACAddress,
      );
  if (bluetoothDevice != null && device.bluetoothUartService.value != null) {
    BluetoothCharacteristic? bluetoothCharacteristic = bluetoothDevice
        .servicesList
        .firstWhereOrNull(
          (element) =>
              element.uuid.str128.toLowerCase() ==
              device.bluetoothUartService.value!.bleDeviceService.toLowerCase(),
        )
        ?.characteristics
        .firstWhereOrNull(
          (element) =>
              element.characteristicUuid.str128.toLowerCase() ==
              device.bluetoothUartService.value!.bleTxCharacteristic
                  .toLowerCase(),
        );
    if (bluetoothCharacteristic == null) {
      _bluetoothPlusLogger.warning(
        "Unable to find bluetooth characteristic to send command to",
      );
      return;
    }

    Future<void> future = bluetoothCharacteristic
        .write(
          message,
          withoutResponse:
              withoutResponse &&
              bluetoothCharacteristic.properties.writeWithoutResponse,
        )
        .catchError(
          (e) => _bluetoothPlusLogger.warning(
            "Unable to send message to ${device.baseDeviceDefinition.btName} $e",
            e,
          ),
        )
        .onError(
          (e, s) => _bluetoothPlusLogger.severe(
            "Unable to send message to ${device.baseDeviceDefinition.btName} $e",
            e,
          ),
        );
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
