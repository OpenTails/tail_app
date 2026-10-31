import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

Future<void> initBle({bool skipPermissionCheck = false}) async {
  if (_didInitBle) {
    return;
  }
  if (!skipPermissionCheck &&
      !await BluetoothIssues.instance.hasPermissions()) {
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
  BleConnectionChange onConnectionChanged,
) async {
  Map<String, StatefulDevice> knownDevices = KnownDevices.instance.state;
  StatefulDevice statefulDevice;
  //get existing entry
  if (knownDevices.containsKey(onConnectionChanged.deviceId)) {
    statefulDevice = knownDevices[onConnectionChanged.deviceId]!;
  } else {
    if (onConnectionChanged.isConnected) {
      await disconnect(
        onConnectionChanged.deviceId,
        "Gear not in known gear list",
      );
    }
    return;
  }
  statefulDevice.deviceConnectionState.value = onConnectionChanged.isConnected
      ? ConnectivityState.connected
      : ConnectivityState.disconnected;
  if (onConnectionChanged.isConnected) {
    await discoverServices(onConnectionChanged.deviceId);
    // gear can be disconnected during discoverServices
    if (statefulDevice.isConnected) {
      int mtu = await UniversalBle.requestMtu(
        onConnectionChanged.deviceId,
        512,
      );
      statefulDevice.mtu = mtu;
    }
  } else {
    if (statefulDevice.forgetBondOnDisconnect) {
      statefulDevice.forgetBondOnDisconnect = false;
      await forgetBond(onConnectionChanged.deviceId);
    }
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
  BluetoothUartService? bluetoothUartService;
  for (BleService service in services) {
    bluetoothUartService = uartServices.firstWhereOrNull(
      (element) =>
          BleUuidParser.compareStrings(element.bleDeviceService, service.uuid),
    );
    if (bluetoothUartService != null) {
      break;
    }
  }
  if (bluetoothUartService == null) {
    _logger.severe("Bluetooth uart service not found for $id, Disconnecting");
    await disconnect(id, "Bluetooth uart service not found");
    return;
  }

  // Convention Mode
  BleCharacteristic? conModeStatusCharacteristic = characteristics
      .where(
        (characteristic) =>
            BleUuidParser.compareStrings(characteristic.uuid, "0x2A28"),
      )
      .firstOrNull;

  if (conModeStatusCharacteristic != null) {
    Uint8List conModeStatusRaw = await conModeStatusCharacteristic.read();
    String conModeStatus = const Utf8Decoder().convert(conModeStatusRaw);
    _logger.info("Convention mode status for device id $id: $conModeStatus");
    if (conModeStatus == "CONMODE ENABLED") {
      // con mode enabled on tail but not app
      if (!statefulDevice.storedDevice.conModeEnabled) {
        statefulDevice.disableAutoConnect = DisableReconnectReason.missingBond;
        await disconnect(id, "con mode enabled on tail but not app");
        return;
      }
      // Verify the bond exists. May sadly trigger pairing if bond doesn't exist
      bool isPaired = Platform.isAndroid
          ? await UniversalBle.isPaired(id) ?? false
          : await UniversalBle.isPaired(
                  id,
                  pairingCommand: BleCommand(
                    service: bluetoothUartService.bleDeviceService,
                    characteristic: bluetoothUartService.bleTxCharacteristic,
                    writeValue: const Utf8Encoder().convert("PING"),
                  ),
                ) ??
                false;

      // Con mode enabled on gear and app, but no bond
      if (!isPaired) {
        if (statefulDevice.attemptBondingOnConnect) {
          statefulDevice.attemptBondingOnConnect = false;

          await Clipboard.setData(
            ClipboardData(text: statefulDevice.storedDevice.conModePin),
          );

          Platform.isAndroid
              ? await UniversalBle.pair(id).onError((error, stackTrace) {
                  _logger.warning("Failed to pair to $id:$error");
                })
              : await UniversalBle.pair(
                  id,
                  pairingCommand: BleCommand(
                    service: bluetoothUartService.bleDeviceService,
                    characteristic: bluetoothUartService.bleTxCharacteristic,
                    writeValue: const Utf8Encoder().convert("PING"),
                  ),
                ).onError((error, stackTrace) {
                  _logger.warning("Failed to pair to $id:$error");
                });
          isPaired = Platform.isAndroid
              ? await UniversalBle.isPaired(id) ?? false
              : await UniversalBle.isPaired(
                      id,
                      pairingCommand: BleCommand(
                        service: bluetoothUartService.bleDeviceService,
                        characteristic:
                            bluetoothUartService.bleTxCharacteristic,
                        writeValue: const Utf8Encoder().convert("PING"),
                      ),
                    ) ??
                    false;
          if (!isPaired) {
            statefulDevice.disableAutoConnect =
                DisableReconnectReason.missingBond;
            await disconnect(
              id,
              "Con mode enabled on gear and app, Failed to create new bond",
            );
            return;
          }
        } else {
          statefulDevice.disableAutoConnect =
              DisableReconnectReason.missingBond;
          await disconnect(id, "Con mode enabled on gear and app, but no bond");
          return;
        }
      }
      // con mode disabled in gear but enabled in app
    } else if (statefulDevice.storedDevice.conModeEnabled) {
      statefulDevice.storedDevice.conModeEnabled = false;
      await forgetBond(id);
    }
  }

  // Don't set immediately to avoid writes while con mode status is verified
  statefulDevice.bluetoothUartService = bluetoothUartService;
  if (!statefulDevice.isReady) {
    _logger.severe("Bluetooth uart service not found for $id, Disconnecting");
    await disconnect(id, "Bluetooth uart service not found");
    return;
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
/// Skips devices with [StatefulDevice.disableAutoConnect] is not set to [DisableReconnectReason.canReconnect]
Future<void> _onScanResultsListener(BleDevice scanResult) async {
  _logger.info('${scanResult.deviceId}: "${scanResult.name}" found!');
  Map<String, StatefulDevice> knownDevices = KnownDevices.instance.state;
  if (knownDevices.containsKey(scanResult.deviceId) &&
      !knownDevices[scanResult.deviceId]!.isConnected &&
      knownDevices[scanResult.deviceId]!.disableAutoConnect ==
          DisableReconnectReason.canReconnect) {
    knownDevices[scanResult.deviceId]?.deviceConnectionState.value =
        ConnectivityState.connecting;
    await _connect(scanResult.deviceId);
  }
}

/// Disconnects connected real and demo/mock gear.
Future<void> disconnect(String id, String reason) async {
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
    _logger.info("disconnecting from $id. Reason: $reason");
    int retry = 0;
    while (retry < 3) {
      retry = retry + 1;
      await UniversalBle.disconnect(id);
      BleConnectionState bleConnectionState =
          await UniversalBle.getConnectionState(id);
      if (bleConnectionState == BleConnectionState.disconnected) {
        return;
      }
    }
  } finally {
    span?.finish();
  }
}

Future<void> forgetBond(String id) async {
  if (!_didInitBle) {
    return;
  }
  // removing bonds is supported on android
  _logger.info("forgetting $id");
  await UniversalBle.unpair(id).onError(
    (error, stackTrace) =>
        _logger.warning("Failed to remove bond for device $id"),
  );
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
              (bluetoothDevice) =>
                  KnownDevices
                      .instance
                      .state[bluetoothDevice.deviceId]!
                      .disableAutoConnect ==
                  DisableReconnectReason.canReconnect,
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
      //stopScan();
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
