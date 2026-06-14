import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:logging/logging.dart' as log;
import 'package:tail_app/Backend/utilities/demo_gear_helpers.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:universal_io/io.dart';

import '../../constants.dart';
import '../Device/bluetooth_uart_services_list.dart';
import '../Device/device_definition.dart';
import '../Device/device_registry.dart';
import '../Device/device_type_enum.dart';
import '../Device/stateful/connected_gear.dart';
import '../Device/stored_device.dart';
import '../logging_wrappers.dart';
import 'bluetooth_issues_check.dart';
import 'bluetooth_stream_helpers.dart';
import 'known_devices.dart';

final _logger = log.Logger('Bluetooth');

ValueNotifier<bool> isBluetoothEnabled = ValueNotifier(false);

bool _didInitBle = false;

Future<void> initBle() async {
  if (_didInitBle) {
    return;
  }
  if (!await BluetoothIssues.instance.hasPermissions()) {
    _logger.info("Bluetooth permission not granted");
    return;
  }

  _didInitBle = true;

  // handle bluetooth on & off
  // note: for iOS the initial state is typically BluetoothAdapterState.unknown
  // note: if you have permissions issues you will get stuck at BluetoothAdapterState.unauthorized
  // starts the listener providers
  UniversalBle.onConnectionChange = _onConnectionStateChangedListener;
  UniversalBle.availabilityStream.listen(_adapterStateListener);
  UniversalBle.queueType = QueueType.perDevice;
  UniversalBle.onScanResult = _onScanResultsListener;
  UniversalBle.onValueChange = valueChanged;
  Scan.instance;
  _KeepGearAwake.instance;
}

void _adapterStateListener(AvailabilityState state) {
  _logger.info(state);
  isBluetoothEnabled.value = state == AvailabilityState.poweredOn;
}

Future<void> _onConnectionStateChangedListener(
  String id,
  bool isConnected,
  String? error,
) async {
  BleDevice? bluetoothDevice = await getBleDeviceByID(id);
  _logger.info('name: ${bluetoothDevice?.name} connected: $isConnected');
  if (isConnected &&
      bluetoothDevice != null &&
      bluetoothDevice.name != null &&
      bluetoothDevice.name!.trim().isEmpty) {
    _logger.warning("Disconnecting from BLE device with blank platform name");
    disconnect(id);
  }
  Map<String, StatefulDevice> knownDevices = KnownDevices.instance.state;

  StoredDevice storedDevice;
  StatefulDevice statefulDevice;
  //get existing entry
  if (knownDevices.containsKey(id)) {
    statefulDevice = knownDevices[id]!;
    storedDevice = statefulDevice.storedDevice;
  } else {
    // Don't create a new entry on device disconnect if the stored device
    // doesn't exist. Stops forgotten gear from immediately being repaired
    if (!isConnected) {
      return;
    }
    if (bluetoothDevice == null) {
      _logger.severe("BLEDevice not found for ID: $id");
      return;
    }
    DeviceDefinition? deviceDefinition = DeviceRegistry.getByName(
      bluetoothDevice.name!,
    );
    if (deviceDefinition == null) {
      _logger.severe("Unknown device found: ${bluetoothDevice.name}");
      return;
    }
    storedDevice = StoredDevice(
      deviceDefinition.uuid,
      id,
      deviceDefinition.deviceType.color().toARGB32(),
    )..name = deviceDefinition.friendlyName;

    statefulDevice = StatefulDevice(deviceDefinition, storedDevice);
    await KnownDevices.instance.add(statefulDevice);
  }
  statefulDevice.deviceConnectionState.value = isConnected
      ? ConnectivityState.connected
      : ConnectivityState.disconnected;
  if (isConnected && bluetoothDevice != null) {
    await discoverServices(bluetoothDevice);
    int mtu = await bluetoothDevice.requestMtu(512);
    statefulDevice.mtu.value = mtu;
  }
}

Future<void> discoverServices(BleDevice device) async {
  List<BleService> services = await device.discoverServices();
  List<BleCharacteristic> characteristics = services
      .map((e) => e.characteristics)
      .flattened
      .toList();

  // Find the RX/TX service
  for (BleService service in services) {
    BluetoothUartService? bluetoothUartService = uartServices.firstWhereOrNull(
      (element) =>
          element.bleDeviceService.toLowerCase() == service.uuid.toLowerCase(),
    );
    if (bluetoothUartService != null) {
      StatefulDevice? statefulDevice =
          KnownDevices.instance.state[device.deviceId];
      statefulDevice?.bluetoothUartService.value = bluetoothUartService;
    }
  }

  // Subscribe to all notifications
  for (BleCharacteristic characteristic in characteristics) {
    if (characteristic.notifications.isSupported) {
      await characteristic.notifications.subscribe();
    }
    if (characteristic.indications.isSupported) {
      await characteristic.indications.subscribe();
    }
  }
}

class _KeepGearAwake {
  StreamSubscription? _streamSubscription;
  static final _KeepGearAwake instance = _KeepGearAwake._internal();

  _KeepGearAwake._internal() {
    _logger.info("Starting _KeepGearAwake timer");
    // The stream/app should pause in the background, so this should be fine
    _streamSubscription ??= Stream.periodic(
      const Duration(seconds: 15),
    ).listen(_periodicListener);
  }

  Future<void> _periodicListener(dynamic event) async {
    for (BleDevice element in await UniversalBle.getSystemDevices()) {
      if (element.isSystemDevice == true || await element.isConnected != true) {
        continue;
      }
      StatefulDevice? statefulDevice =
          KnownDevices.instance.state[element.deviceId];

      statefulDevice?.rssi.value = await element
          .readRssi()
          .catchError((e) => -1)
          .onError((error, stackTrace) => -1);
    }
  }
}

// check for known gear with the same mac address and try to connect
Future<void> _onScanResultsListener(BleDevice scanResult) async {
  _logger.info('${scanResult.deviceId}: "${scanResult.name}" found!');
  Map<String, StatefulDevice> knownDevices = KnownDevices.instance.state;
  if (knownDevices.containsKey(scanResult.deviceId) &&
      knownDevices[scanResult.deviceId]?.deviceConnectionState.value ==
          ConnectivityState.disconnected &&
      !knownDevices[scanResult.deviceId]!.disableAutoConnect) {
    knownDevices[scanResult.deviceId]?.deviceConnectionState.value =
        ConnectivityState.connecting;
    await connect(scanResult.deviceId);
  }
}

Future<void> disconnect(String id) async {
  if (!_didInitBle) {
    return;
  }
  BleDevice? device = await getBleDeviceByID(id);
  KnownDevices.instance.state[id]?.deviceConnectionState.value =
      ConnectivityState.disconnected;

  if (device != null) {
    _logger.info("disconnecting from ${device.name}");
    await device.disconnect();
  }
}

Future<BleDevice?> getBleDeviceByID(String id) async {
  List<BleDevice> connectedDevices = await UniversalBle.getSystemDevices();
  BleDevice? device = connectedDevices.firstWhereOrNull(
    (element) => element.deviceId == id,
  );
  return device;
}

Future<void> forgetBond(String id) async {
  if (!_didInitBle) {
    return;
  }
  // removing bonds is supported on android
  if (!Platform.isAndroid) {
    return;
  }
  BleDevice? device = await getBleDeviceByID(id);
  if (device != null) {
    _logger.info("forgetting ${device.name}");
    await device.unpair();
  }
}

Future<void> connect(String id) async {
  if (!_didInitBle) {
    return;
  }
  int retry = 0;
  while (retry <
      HiveProxy.getOrDefault(
        settings,
        gearConnectRetryAttempts,
        defaultValue: gearConnectRetryAttemptsDefault,
      )) {
    try {
      await UniversalBle.connect(id, timeout: Duration(seconds: 20));
      break;
    } on ConnectionException catch (e) {
      retry = retry + 1;
      _logger.warning(
        "Failed to connect to $id. Attempt $retry/${HiveProxy.getOrDefault(settings, gearConnectRetryAttempts, defaultValue: gearConnectRetryAttemptsDefault)}",
        e,
      );
      await Future.delayed(Duration(milliseconds: 250));
    }
  }
}

class Scan with ChangeNotifier {
  StreamSubscription<bool>? isScanningStreamSubscription;

  ScanReason get state => _state;
  ScanReason _state = ScanReason.notScanning;
  static final Scan instance = Scan._internal();

  Scan._internal() {
    // isScanningStreamSubscription = FlutterBluePlus.isScanning.listen(
    //   onIsScanningChange,
    // );

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
    if (_didInitBle &&
        !(await UniversalBle.isScanning()) &&
        isBluetoothEnabled.value) {
      _logger.info("Starting scan");

      _state = scanReason;

      //Pull in paired & connected gear that isn't connected to the app
      await UniversalBle.getSystemDevices(
        withServices: DeviceRegistry.getAllIds.toList(),
      ).then(
        (value) => value
            .where(
              (bluetoothDevice) => KnownDevices.instance.state.containsKey(
                bluetoothDevice.deviceId,
              ),
            )
            .where(
              (bluetoothDevice) =>
                  KnownDevices
                      .instance
                      .state[bluetoothDevice.deviceId]!
                      .deviceConnectionState
                      .value ==
                  ConnectivityState.disconnected,
            )
            .where(
              (bluetoothDevice) => !KnownDevices
                  .instance
                  .state[bluetoothDevice.deviceId]!
                  .disableAutoConnect,
            )
            .where((element) => element.isSystemDevice == true)
            .forEach((bluetoothDevice) => connect(bluetoothDevice.deviceId)),
      );
      // Or optionally add a scan filter
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: DeviceRegistry.getAllIds.toList()),
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
    if (!_didInitBle) {
      return;
    }
    if (_state == ScanReason.notScanning) {
      return;
    }
    _logger.info("stopScan called");
    await UniversalBle.stopScan();
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
  StatefulDevice device,
  List<int> message, {
  bool withoutResponse = false,
}) async {
  if (!_didInitBle || isDemoGear(device)) {
    return;
  }
  if (device.bluetoothUartService.value != null) {
    Future<void> future =
        UniversalBle.write(
              device.storedDevice.btMACAddress,
              device.bluetoothUartService.value!.bleDeviceService,
              device.bluetoothUartService.value!.bleTxCharacteristic,
              Uint8List.fromList(message),
              withoutResponse: withoutResponse,
            )
            .catchError(
              (e) => _logger.warning(
                "Unable to send message to ${device.deviceDefinition.btName} $e",
                e,
              ),
            )
            .onError(
              (e, s) => _logger.severe(
                "Unable to send message to ${device.deviceDefinition.btName} $e",
                e,
              ),
            );
    await future;
  }
}
