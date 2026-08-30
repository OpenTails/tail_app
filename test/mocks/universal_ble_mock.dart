import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

/// A stateful, in-memory mock of [UniversalBlePlatform].
///
/// Inject with:
/// ```dart
/// UniversalBle.setInstance(UniversalBleMock());
/// ```
///
/// Tests can seed the mock, drive connection/state changes and simulate
/// incoming characteristic values through the `test*`/`update*` helpers.
///
/// Note: `connect()`/`disconnect()` MUST call `updateConnection(...)` or
/// `UniversalBle.connect()`/`UniversalBle.disconnect()` will hang waiting on
/// their internal connection completer.
class UniversalBleMock extends UniversalBlePlatform {
  /// Default availability reported when there is no configured device.
  AvailabilityState availabilityState = AvailabilityState.poweredOn;

  /// Whether the mock is currently scanning.
  bool _isScanning = false;

  /// Per-device state keyed by lower-cased deviceId.
  final Map<String, MockDevice> _devices = {};

  /// Records subscriptions keyed by `"deviceId/serviceId/characteristicId"`.
  final Map<String, BleInputProperty> subscriptions = {};

  /// Records written values keyed by `"deviceId/serviceId/characteristicId"`.
  final Map<String, Uint8List> writtenValues = {};

  /// Devices returned by [getSystemDevices].
  final List<BleDevice> systemDevices = [];

  /// Devices emitted by [startScan] via [updateScanResult].
  final List<BleDevice> scanResults = [];

  /// The last [ScanFilter] passed to [startScan].
  ScanFilter? lastScanFilter;

  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async =>
      availabilityState;

  /// Enables Bluetooth by setting [availabilityState] to `poweredOn`.
  @override
  Future<bool> enableBluetooth() async {
    updateAvailability(AvailabilityState.poweredOn);
    return true;
  }

  /// Disables Bluetooth by setting [availabilityState] to `poweredOff`.
  @override
  Future<bool> disableBluetooth() async {
    updateAvailability(AvailabilityState.poweredOff);
    return true;
  }

  /// Whether Bluetooth permissions are granted.
  bool hasBluetoothPermissions = true;

  @override
  Future<bool> hasPermissions({bool withAndroidFineLocation = false}) async =>
      hasBluetoothPermissions;

  /// Stores any permission request calls (for assertions in tests).
  final List<bool> requestedPermissions = [];

  @override
  Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {
    requestedPermissions.add(withAndroidFineLocation);
    hasBluetoothPermissions = true;
  }

  /// Begins scanning. Emits each device in [scanResults] via
  /// [updateScanResult].
  ///
  /// If you need to emit specific devices, add them to [scanResults] (or call
  /// [simulateScanResult]) before/after calling [startScan].
  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    _isScanning = true;
    lastScanFilter = scanFilter;
    for (final device in scanResults) {
      updateScanResult(device);
    }
  }

  /// Stops scanning.
  @override
  Future<void> stopScan() async {
    _isScanning = false;
  }

  /// Returns whether scanning is currently active.
  @override
  Future<bool> isScanning() async => _isScanning;

  /// Connects to the device, marking it connected and emitting
  /// [updateConnection] so the framework completer resolves.
  ///
  /// Throws a [ConnectionException] if [shouldFailConnect] is true for the
  /// device.
  @override
  Future<void> connect(
    String deviceId, {
    Duration? connectionTimeout,
    bool autoConnect = false,
    ConnectionPlatformConfig? platformConfig,
  }) async {
    final id = deviceId.toLowerCase();
    final device = _getOrCreateDevice(id);
    if (device.shouldFailConnect) {
      updateConnection(id, false, 'Mock connection failed');
      throw ConnectionException('Mock connection failed for $id');
    }
    device.connectionState = BleConnectionState.connected;
    updateConnection(id, true);
  }

  /// Disconnects the device, marking it as disconnected and emitting
  /// [updateConnection].
  @override
  Future<void> disconnect(String deviceId) async {
    final id = deviceId.toLowerCase();
    final device = _getOrCreateDevice(id);
    device.connectionState = BleConnectionState.disconnected;
    updateConnection(id, false);
  }

  /// Returns the configured services for the device, or an empty list if the
  /// device does not exist.
  @override
  Future<List<BleService>> discoverServices(
    String deviceId,
    bool withDescriptors,
  ) async {
    final device = _devices[deviceId.toLowerCase()];
    if (device == null) return <BleService>[];
    return device.services;
  }

  /// Tracks notification/indication subscription state.
  @override
  Future<void> setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty bleInputProperty,
  ) async {
    subscriptions[_key(deviceId, service, characteristic)] = bleInputProperty;
  }

  /// Reads from the per-device characteristic value cache.
  @override
  Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
  }) async {
    final device = _getOrCreateDevice(deviceId.toLowerCase());
    return device.characteristicValues[_key(
          deviceId,
          service,
          characteristic,
        )] ??
        Uint8List(0);
  }

  /// Stores the written value (and optionally echoes it back).
  ///
  /// If [autoEchoWrites] is enabled for the device, the value is also pushed
  /// through [updateCharacteristicValue] so tests can observe the write in
  /// the streams.
  @override
  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  ) async {
    final id = deviceId.toLowerCase();
    final device = _getOrCreateDevice(id);
    writtenValues[_key(deviceId, service, characteristic)] = value;
    if (device.autoEchoWrites) {
      updateCharacteristicValue(
        id,
        BleUuidParser.string(characteristic),
        value,
        null,
      );
    }
  }

  /// Requests an MTU, recording it and returning it.
  ///
  /// By default the mock returns `expectedMtu`. If [overrideMtu] is set for
  /// the device, that value is returned instead (to simulate OS negotiation).
  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async {
    final device = _getOrCreateDevice(deviceId.toLowerCase());
    device.requestedMtu = expectedMtu;
    return device.overrideMtu ?? expectedMtu;
  }

  /// Reads the RSSI. Returns the configured [defaultRssi] for the device.
  @override
  Future<int> readRssi(String deviceId) async {
    return _getOrCreateDevice(deviceId.toLowerCase()).defaultRssi;
  }

  /// Records connection priority requests for assertions.
  final List<({String deviceId, BleConnectionPriority priority})>
  requestedConnectionPriorities = [];

  @override
  Future<void> requestConnectionPriority(
    String deviceId,
    BleConnectionPriority priority,
  ) async {
    requestedConnectionPriorities.add((
      deviceId: deviceId.toLowerCase(),
      priority: priority,
    ));
  }

  @override
  Future<bool> isPaired(String deviceId) async {
    return _getOrCreateDevice(deviceId.toLowerCase()).paired;
  }

  /// Pairs the device.
  @override
  Future<bool> pair(String deviceId) async {
    final id = deviceId.toLowerCase();
    _getOrCreateDevice(id).paired = true;
    updatePairingState(id, true);
    return true;
  }

  /// Unpairs the device.
  @override
  Future<void> unpair(String deviceId) async {
    final id = deviceId.toLowerCase();
    _getOrCreateDevice(id).paired = false;
    updatePairingState(id, false);
  }

  /// Returns the connection state of the device.
  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async {
    return _getOrCreateDevice(deviceId.toLowerCase()).connectionState;
  }

  /// Returns [systemDevices] filtered to the given service UUIDs if any.
  @override
  Future<List<BleDevice>> getSystemDevices(List<String>? withServices) async {
    if (withServices == null || withServices.isEmpty) {
      return List.of(systemDevices);
    }
    final serviceSet = withServices.map(BleUuidParser.string).toSet();
    return systemDevices
        .where(
          (device) => device.services.any(
            (service) => serviceSet.contains(BleUuidParser.string(service)),
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Test helpers
  // ---------------------------------------------------------------------------

  static String _key(String deviceId, String service, String characteristic) =>
      '${deviceId.toLowerCase()}/${BleUuidParser.string(service)}/${BleUuidParser.string(characteristic)}';

  MockDevice _getOrCreateDevice(String id) =>
      _devices.putIfAbsent(id, () => MockDevice());

  /// Returns the internal device state for a device if it has been created.
  /// Useful for assertions in tests.
  MockDevice? getDevice(String deviceId) => _devices[deviceId.toLowerCase()];

  /// Removes all configured mock state.
  void reset() {
    _devices.clear();
    subscriptions.clear();
    writtenValues.clear();
    systemDevices.clear();
    scanResults.clear();
    requestedConnectionPriorities.clear();
    lastScanFilter = null;
    _isScanning = false;
    availabilityState = AvailabilityState.poweredOn;
    hasBluetoothPermissions = true;
  }

  /// Adds (or replaces) the services returned by [discoverServices] for a
  /// device. Services are keyed by lower-cased deviceId.
  void mockServices(String deviceId, List<BleService> services) {
    _getOrCreateDevice(deviceId.toLowerCase()).services = services;
  }

  /// Adds a characteristic value to the read cache for a device.
  void mockCharacteristicValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
  ) {
    _getOrCreateDevice(
      deviceId.toLowerCase(),
    ).characteristicValues[_key(deviceId, service, characteristic)] = value;
  }

  /// Sets the connection state directly (without emitting an event).
  void mockConnectionState(String deviceId, BleConnectionState state) {
    _getOrCreateDevice(deviceId.toLowerCase()).connectionState = state;
  }

  /// Marks a device as paired.
  void mockPaired(String deviceId, [bool paired = true]) {
    _getOrCreateDevice(deviceId.toLowerCase()).paired = paired;
  }

  /// Makes [connect] throw for the given device.
  void mockConnectFailure(String deviceId) {
    _getOrCreateDevice(deviceId.toLowerCase()).shouldFailConnect = true;
  }

  /// Sets the MTU override for a device (simulating OS negotiation).
  void mockMtu(String deviceId, int mtu) {
    _getOrCreateDevice(deviceId.toLowerCase()).overrideMtu = mtu;
  }

  /// Sets the RSSI value returned by [readRssi].
  void mockRssi(String deviceId, int rssi) {
    _getOrCreateDevice(deviceId.toLowerCase()).defaultRssi = rssi;
  }

  /// Enables echo-back of writes for a device (writes trigger
  /// [updateCharacteristicValue]).
  void mockEchoWrites(String deviceId, {bool enabled = true}) {
    _getOrCreateDevice(deviceId.toLowerCase()).autoEchoWrites = enabled;
  }

  /// Adds a device to the scan/system device list.
  void addScanDevice(BleDevice device) {
    scanResults.add(device);
  }

  /// Simulates a scan result arriving for a device via [updateScanResult].
  void simulateScanResult(BleDevice device) {
    updateScanResult(device);
  }

  /// Adds a device to the [systemDevices] list returned by
  /// [getSystemDevices].
  void addSystemDevice(BleDevice device) {
    systemDevices.add(device);
  }

  /// Simulates an incoming characteristic value, pushing it to
  /// [onValueChange] and the characteristic value stream.
  void simulateValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
  ) {
    updateCharacteristicValue(
      deviceId,
      BleUuidParser.string(characteristic),
      value,
      null,
    );
  }

  /// Simulates a connection event for a device.
  void simulateConnection(String deviceId, bool isConnected) {
    updateConnection(deviceId, isConnected);
  }

  /// Simulates an availability change event.
  void simulateAvailability(AvailabilityState state) {
    updateAvailability(state);
  }

  @override
  Future<Uint8List> readDescriptorValue(
    String deviceId,
    String service,
    String characteristic,
    String descriptor, {
    Duration? timeout,
  }) {
    // TODO: implement readDescriptorValue
    throw UnimplementedError();
  }

  @override
  Future<void> writeDescriptorValue(
    String deviceId,
    String service,
    String characteristic,
    String descriptor,
    Uint8List value,
  ) {
    // TODO: implement writeDescriptorValue
    throw UnimplementedError();
  }
}

/// Internal per-device state used by [UniversalBleMock].
class MockDevice {
  List<BleService> services = [];
  BleConnectionState connectionState = BleConnectionState.disconnected;
  bool paired = false;
  bool shouldFailConnect = false;
  bool autoEchoWrites = false;
  int? overrideMtu;
  int? requestedMtu;
  int defaultRssi = -50;
  final Map<String, Uint8List> characteristicValues = {};
}
