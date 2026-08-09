import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:logging/logging.dart' as log;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tail_app/Backend/utilities/demo_gear_helpers.dart';
import 'package:tail_app/Frontend/Widgets/scan_for_new_device.dart';
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
  UniversalBle.onValueChange = onBluetoothCharacteristicValueUpdate;
  UniversalBle.setLogLevel(kDebugMode ? BleLogLevel.debug : BleLogLevel.info);
  Scan.instance;
}

void _adapterStateListener(AvailabilityState state) {
  _logger.info(state);
  isBluetoothEnabled.value = state == AvailabilityState.poweredOn;
}

/// Maps the [UniveUniversalBle] connection state to [StatefulDevice] and fires off [discoverServices]
/// disconnects if [id] doesn't match a [StoredDevice] in [KnownDevices]
Future<void> _onConnectionStateChangedListener(
  String id,
  bool isConnected,
  String? error,
) async {
  Map<String, StatefulDevice> knownDevices = KnownDevices.instance.state;
  StatefulDevice statefulDevice;
  //get existing entry
  if (knownDevices.containsKey(id)) {
    statefulDevice = knownDevices[id]!;
  } else {
    if (isConnected) {
      await disconnect(id);
    }
    return;
  }
  statefulDevice.deviceConnectionState.value = isConnected
      ? ConnectivityState.connected
      : ConnectivityState.disconnected;
  if (isConnected) {
    await discoverServices(id);
    int mtu = await UniversalBle.requestMtu(id, 512);
    statefulDevice.mtu = mtu;
  }
}

/// Create a new Stored/Stateful device entry if it doesn't exist and try to connect
/// if the id is a demo/mock gear, calls [createDemoGear]
Future<void> createAndConnect(String id, String name) async {
  final ISentrySpan? span = Sentry.getSpan()?.startChild('Bluetooth.create');

  Map<String, StatefulDevice> knownDevices = KnownDevices.instance.state;
  StatefulDevice statefulDevice;
  //get existing entry
  if (knownDevices.containsKey(id)) {
    statefulDevice = knownDevices[id]!;
  } else {
    _logger.info("Registering new device $name $id");
    DeviceDefinition? deviceDefinition = DeviceRegistry.getByName(name);
    if (deviceDefinition == null) {
      _logger.severe("Unknown device found: $name");
      return;
    }

    if (isDemoGearMac(id)) {
      createDemoGear(deviceDefinition);
      return;
    }

    StoredDevice storedDevice = StoredDevice(
      deviceDefinition.uuid,
      id,
      deviceDefinition.deviceType.color().toARGB32(),
    )..name = deviceDefinition.friendlyName;

    statefulDevice = StatefulDevice(deviceDefinition, storedDevice);
    await KnownDevices.instance.add(statefulDevice);
  }
  await _connect(id);
  span?.finish();
}

/// Locate and subscribe to all characteristics, and set [StatefulDevice.bluetoothUartService]
/// Disconnects the device if a [BluetoothUartService] is not found.
Future<void> discoverServices(String id) async {
  StatefulDevice? statefulDevice = KnownDevices.instance.state[id];
  if (statefulDevice == null) {
    return;
  }
  final ISentrySpan? span = Sentry.getSpan()?.startChild(
    'Bluetooth.discoverServices',
  );

  List<BleService> services = [];
  int retry = 0;
  while (retry < gearConnectRetryAttemptsDefault) {
    try {
      services = await UniversalBle.discoverServices(id);
    } catch (e) {
      _logger.severe("Error while discovering services for $id.", e);
    }
    retry = retry + 1;
    if (services.isEmpty &&
        await UniversalBle.getConnectionState(id) ==
            BleConnectionState.connected) {
      _logger.warning(
        "Failed to discover services for $id. Attempt $retry/$gearConnectRetryAttemptsDefault",
      );
    } else if (services.isNotEmpty) {
      break;
    }
  }
  if (services.isEmpty) {
    _logger.severe("Failed to discover services for $id.");
  }

  List<BleCharacteristic> characteristics = services
      .map((e) => e.characteristics)
      .flattened
      .toList();

  // Find the RX/TX service
  for (BleService service in services) {
    BluetoothUartService? bluetoothUartService = uartServices.firstWhereOrNull(
      (element) =>
          BleUuidParser.compareStrings(element.bleDeviceService, service.uuid),
    );
    if (bluetoothUartService != null) {
      statefulDevice.bluetoothUartService = bluetoothUartService;
      break;
    }
  }

  if (!statefulDevice.isReady) {
    _logger.severe("Bluetooth uart service not found for $id, Disconnecting");
    await disconnect(id);
  }

  // Subscribe to all notifications
  for (BleCharacteristic characteristic in characteristics) {
    try {
      if (characteristic.notifications.isSupported) {
        await characteristic.notifications.subscribe();
      }
      if (characteristic.indications.isSupported) {
        await characteristic.indications.subscribe();
      }
    } catch (e) {
      _logger.severe(
        "Failed to subscribe to characteristic ${characteristic.uuid}",
        e,
      );
    }
  }
  span?.finish();
}

/// checks for [KnownDevices] with the same mac address([StoredDevice.btMACAddress]) and try to connect
/// Skips devices with [StatefulDevice.disableAutoConnect] set to true
Future<void> _onScanResultsListener(BleDevice scanResult) async {
  _logger.info('${scanResult.deviceId}: "${scanResult.name}" found!');
  Map<String, StatefulDevice> knownDevices = KnownDevices.instance.state;
  if (knownDevices.containsKey(scanResult.deviceId) &&
      !knownDevices[scanResult.deviceId]!.isConnected &&
      !knownDevices[scanResult.deviceId]!.disableAutoConnect) {
    knownDevices[scanResult.deviceId]?.deviceConnectionState.value =
        ConnectivityState.connecting;
    await _connect(scanResult.deviceId);
  }
}

/// Disconnects connected real and demo/mock gear.
Future<void> disconnect(String id) async {
  if (!_didInitBle) {
    return;
  }
  final ISentrySpan? span = Sentry.getSpan()?.startChild(
    'Bluetooth.disconnect',
  );
  try {
    StatefulDevice? statefulDevice = KnownDevices.instance.state[id];
    statefulDevice?.deviceConnectionState.value =
        ConnectivityState.disconnected;

    if (statefulDevice != null && isDemoGear(statefulDevice)) {
      return;
    }
    _logger.info("disconnecting from $id");
    await UniversalBle.disconnect(id);
  } finally {
    span?.finish();
  }
}

Future<void> forgetBond(String id) async {
  if (!_didInitBle) {
    return;
  }
  // removing bonds is supported on android
  if (!Platform.isAndroid) {
    return;
  }
  _logger.info("forgetting $id");
  await UniversalBle.unpair(id);
}

/// Attempt to connect to the ble mac address, tries a few times
/// Only used for real devices
Future<void> _connect(String id) async {
  if (!_didInitBle) {
    return;
  }
  final ISentrySpan? span = Sentry.getSpan()?.startChild('Bluetooth.connect');
  try {
    int retry = 0;
    while (retry < gearConnectRetryAttemptsDefault) {
      try {
        await UniversalBle.connect(id, timeout: Duration(seconds: 20));
        break;
      } on ConnectionException catch (e) {
        retry = retry + 1;
        _logger.warning(
          "Failed to connect to $id. Attempt $retry/$gearConnectRetryAttemptsDefault",
          e,
        );
        await Future.delayed(Duration(milliseconds: 250));
      }
    }
  } finally {
    span?.finish();
  }
}

class Scan with ChangeNotifier {
  StreamSubscription<bool>? isScanningStreamSubscription;

  ScanReason get state => _state;
  ScanReason _state = ScanReason.notScanning;
  static final Scan instance = Scan._internal();
  final StreamController<BleDevice> _scanStreamController = StreamController();
  late final Stream<BleDevice> scanStream;
  late final StreamSubscription<BleDevice> streamSubscription;

  Scan._internal() {
    // isScanningStreamSubscription = FlutterBluePlus.isScanning.listen(
    //   onIsScanningChange,
    // );
    scanStream = _scanStreamController.stream.asBroadcastStream();
    streamSubscription = UniversalBle.scanStream.listen(
      _universalBleScanStreamListener,
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
              (bluetoothDevice) => !KnownDevices
                  .instance
                  .state[bluetoothDevice.deviceId]!
                  .isConnected,
            )
            .where(
              (bluetoothDevice) => !KnownDevices
                  .instance
                  .state[bluetoothDevice.deviceId]!
                  .disableAutoConnect,
            )
            .where((element) => element.isSystemDevice == true)
            .forEach((bluetoothDevice) => _connect(bluetoothDevice.deviceId)),
      );
      // Or optionally add a scan filter
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: DeviceRegistry.getAllIds.toList()),
      );
    }
  }

  /// Stops an active scan and transitions to background scan.
  /// An active scan is for pairing new gear or during an OTA reboot
  void stopActiveScan() {
    if (_state == ScanReason.addGear) {
      _state = ScanReason.background;
    }
    isAllGearConnectedListener();
  }

  /// Stop all bluetooth scanning
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

  /// Checks if scanning should start/stop
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

  void _universalBleScanStreamListener(BleDevice device) {
    if (!_scanStreamController.hasListener) {
      return;
    }
    _scanStreamController.sink.add(device);
  }

  /// allows injecting mock/demo gear into the scan results. Used for the demo gear option in [DemoGearDropdown]
  Future<void> addDemoGear(DeviceDefinition deviceDefinition) async {
    if (isDemoGearExists(deviceDefinition)) {
      return;
    }
    _scanStreamController.sink.add(
      BleDevice(
        deviceId: getDemoGearBleMac(deviceDefinition),
        name: deviceDefinition.btName,
      ),
    );
  }
}

enum ScanReason { background, addGear, notScanning }

/// Sends a BLE message to a [StatefulDevice]. No-Op for demo/mock gear.
Future<void> sendMessage(StatefulDevice device, List<int> message) async {
  if (!_didInitBle || isDemoGear(device)) {
    return;
  }
  if (device.isReady) {
    Future<void> future =
        UniversalBle.write(
              device.storedDevice.btMACAddress,
              device.bluetoothUartService!.bleDeviceService,
              device.bluetoothUartService!.bleTxCharacteristic,
              Uint8List.fromList(message),
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
