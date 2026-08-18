import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Backend/Device/bluetooth_uart_services_list.dart';
import 'package:tail_app/Backend/Device/device_definition.dart';
import 'package:tail_app/Backend/Device/device_registry.dart';
import 'package:tail_app/Backend/Device/device_type_enum.dart';
import 'package:tail_app/Backend/Device/stateful/connected_gear.dart';
import 'package:tail_app/Backend/Device/stored_device.dart';
import 'package:tail_app/Backend/utilities/hive.dart';
import 'package:tail_app/constants.dart';
import 'package:universal_ble/universal_ble.dart';

import 'mocks/universal_ble_mock.dart';

void main() {
  late UniversalBleMock mock;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initHive();
    await Hive.openBox<StoredDevice>(devicesBox);

    mock = UniversalBleMock();
    UniversalBle.setInstance(mock);

    // Initialize BLE (registers listeners, creates Scan singleton)
    await initBle(skipPermissionCheck: true);
  });

  setUp(() async {
    mock.reset();
    await Hive.box<StoredDevice>(devicesBox).clear();
    await KnownDevices.instance.reload();
    isBluetoothEnabled.value = true;
    // Mark onboarding as complete to avoid background scan triggers
    await Hive.box(
      settings,
    ).put(hasCompletedOnboarding, hasCompletedOnboardingVersionToAgree);
  });

  tearDown(() async {
    mock.reset();
    await Hive.box<StoredDevice>(devicesBox).clear();
    await KnownDevices.instance.reload();
    isBluetoothEnabled.value = false;
  });

  group('Scan for unpaired gear', () {
    test('beginScan starts scanning with device service filter', () async {
      await Scan.instance.beginScan(scanReason: ScanReason.addGear);

      expect(await UniversalBle.isScanning(), isTrue);
      expect(mock.lastScanFilter, isNotNull);
      expect(
        mock.lastScanFilter!.withServices,
        DeviceRegistry.getAllIds.toList(),
      );
    });

    test('scan results are forwarded to scanStream', () async {
      final device = BleDevice(deviceId: 'AA:BB:CC:DD:EE:01', name: 'MiTail');

      final received = <BleDevice>[];
      final sub = Scan.instance.scanStream.listen(received.add);

      mock.simulateScanResult(device);
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first.deviceId, 'AA:BB:CC:DD:EE:01');
      expect(received.first.name, 'MiTail');

      await sub.cancel();
    });

    test('createAndConnect registers new unpaired gear', () async {
      await createAndConnect('AA:BB:CC:DD:EE:01', 'MiTail');

      expect(
        KnownDevices.instance.state.containsKey('AA:BB:CC:DD:EE:01'),
        isTrue,
      );
      final device = KnownDevices.instance.state['AA:BB:CC:DD:EE:01']!;
      expect(device.deviceDefinition.friendlyName, 'MiTail');
    });

    test('createAndConnect ignores unknown device names', () async {
      await createAndConnect('AA:BB:CC:DD:EE:02', 'UnknownDevice');

      expect(
        KnownDevices.instance.state.containsKey('AA:BB:CC:DD:EE:02'),
        isFalse,
      );
    });

    test(
      '_onScanResultsListener auto-connects known unconnected gear',
      () async {
        // Add a known device
        final deviceDefinition = DeviceRegistry.getByName('MiTail')!;
        final storedDevice = StoredDevice(
          deviceDefinition.uuid,
          'AA:BB:CC:DD:EE:03',
          deviceDefinition.deviceType.color().toARGB32(),
        )..name = deviceDefinition.friendlyName;
        final statefulDevice = StatefulDevice(deviceDefinition, storedDevice);
        await KnownDevices.instance.add(statefulDevice);

        // Simulate scan result for the known device
        mock.simulateScanResult(
          BleDevice(deviceId: 'AA:BB:CC:DD:EE:03', name: 'MiTail'),
        );
        await Future<void>.delayed(Duration.zero);

        // The device should no longer be disconnected (connecting or connected)
        expect(
          KnownDevices
              .instance
              .state['AA:BB:CC:DD:EE:03']!
              .deviceConnectionState
              .value,
          isNot(ConnectivityState.disconnected),
        );
      },
    );

    test(
      '_onScanResultsListener does not auto-connect unknown gear',
      () async {
        // Simulate a scan result for a device that is not in KnownDevices
        mock.simulateScanResult(
          BleDevice(deviceId: 'AA:BB:CC:DD:EE:05', name: 'UnknownDevice'),
        );
        await Future<void>.delayed(Duration.zero);

        // The unknown device should not be registered
        expect(
          KnownDevices.instance.state.containsKey('AA:BB:CC:DD:EE:05'),
          isFalse,
        );
        // And no connection should have been attempted
        expect(mock.getDevice('AA:BB:CC:DD:EE:05'), isNull);
      },
    );

    test(
      '_onScanResultsListener respects disableAutoConnect',
      () async {
        // Add a known device with auto-connect disabled
        final deviceDefinition = DeviceRegistry.getByName('MiTail')!;
        final storedDevice = StoredDevice(
          deviceDefinition.uuid,
          'AA:BB:CC:DD:EE:06',
          deviceDefinition.deviceType.color().toARGB32(),
        )..name = deviceDefinition.friendlyName;
        final statefulDevice = StatefulDevice(deviceDefinition, storedDevice)
          ..disableAutoConnect = true;
        await KnownDevices.instance.add(statefulDevice);

        // Simulate scan result for the known device
        mock.simulateScanResult(
          BleDevice(deviceId: 'AA:BB:CC:DD:EE:06', name: 'MiTail'),
        );
        await Future<void>.delayed(Duration.zero);

        // The device should remain disconnected (no auto-connect attempted)
        expect(
          KnownDevices
              .instance
              .state['AA:BB:CC:DD:EE:06']!
              .deviceConnectionState
              .value,
          ConnectivityState.disconnected,
        );
        // And no connection should have been attempted
        expect(mock.getDevice('AA:BB:CC:DD:EE:06'), isNull);
      },
    );
  });
}
