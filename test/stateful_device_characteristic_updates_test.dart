import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Backend/Device/stored_device.dart';
import 'package:tail_app/Backend/utilities/hive.dart';
import 'package:tail_app/Backend/utilities/version.dart';
import 'package:tail_app/constants.dart';
import 'package:universal_ble/universal_ble.dart';

import 'helpers/test_gear.dart';
import 'mocks/universal_ble_mock.dart';

void main() {
  late UniversalBleMock mock;
  const testMac = 'AA:BB:CC:DD:EE:10';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initHive();
    await Hive.openBox<StoredDevice>(devicesBox);

    mock = UniversalBleMock();
    UniversalBle.setInstance(mock);

    // Registers UniversalBle.onValueChange → onBluetoothCharacteristicValueUpdate
    await initBle(skipPermissionCheck: true);
  });

  setUp(() async {
    mock.reset();
    await Hive.box<StoredDevice>(devicesBox).clear();
    await KnownDevices.instance.reload();
    isBluetoothEnabled.value = true;
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

  group('StatefulDevice characteristic updates', () {
    test('receives battery level updates via RX characteristic', () async {
      final statefulDevice = await TestGear.createConnectedStatefulDevice(
        testMac,
      );

      // Simulate a BATT response with an initial battery level
      mock.simulateValue(
        testMac,
        statefulDevice.bluetoothUartService!.bleDeviceService,
        statefulDevice.bluetoothUartService!.bleRxCharacteristic,
        const Utf8Encoder().convert('85'),
      );

      await Future<void>.delayed(Duration.zero);
      expect(statefulDevice.battery.level, 85.0);

      // Simulate a new battery level mid-way
      mock.simulateValue(
        testMac,
        statefulDevice.bluetoothUartService!.bleDeviceService,
        statefulDevice.bluetoothUartService!.bleRxCharacteristic,
        const Utf8Encoder().convert('50'),
      );

      await Future<void>.delayed(Duration.zero);
      expect(statefulDevice.battery.level, 50.0);

      // Simulate a battery level drop below 20%
      mock.simulateValue(
        testMac,
        statefulDevice.bluetoothUartService!.bleDeviceService,
        statefulDevice.bluetoothUartService!.bleRxCharacteristic,
        const Utf8Encoder().convert('15'),
      );

      await Future<void>.delayed(Duration.zero);
      expect(statefulDevice.battery.level, 15.0);

      statefulDevice.reset();
    });

    test('receives firmware version updates via RX characteristic', () async {
      final statefulDevice = await TestGear.createConnectedStatefulDevice(
        testMac,
      );

      // Simulate a VER response
      mock.simulateValue(
        testMac,
        statefulDevice.bluetoothUartService!.bleDeviceService,
        statefulDevice.bluetoothUartService!.bleRxCharacteristic,
        const Utf8Encoder().convert('VER 5.0.4'),
      );

      await Future<void>.delayed(Duration.zero);

      expect(
        statefulDevice.firmwareStatus.firmwareVersion,
        const Version(major: 5, minor: 0, patch: 4),
      );

      statefulDevice.reset();
    });

    test('receives hardware version updates via RX characteristic', () async {
      final statefulDevice = await TestGear.createConnectedStatefulDevice(
        testMac,
      );

      // Simulate an HWVER response
      mock.simulateValue(
        testMac,
        statefulDevice.bluetoothUartService!.bleDeviceService,
        statefulDevice.bluetoothUartService!.bleRxCharacteristic,
        const Utf8Encoder().convert('HWVER 2.1'),
      );

      await Future<void>.delayed(Duration.zero);

      expect(statefulDevice.firmwareStatus.hardwareVersion, ' 2.1');

      statefulDevice.reset();
    });

    test('receives charging status updates via charging characteristic',
        () async {
      final statefulDevice = await TestGear.createConnectedStatefulDevice(
        testMac,
      );

      // Simulate the charging characteristic notification
      mock.simulateValue(
        testMac,
        statefulDevice.bluetoothUartService!.bleDeviceService,
        '5073792e-4fc0-45a0-b0a5-78b6c1756c91',
        const Utf8Encoder().convert('CHARGE ON'),
      );

      await Future<void>.delayed(Duration.zero);
      expect(statefulDevice.battery.isCharging, isTrue);

      // Simulate charging stopping
      mock.simulateValue(
        testMac,
        statefulDevice.bluetoothUartService!.bleDeviceService,
        '5073792e-4fc0-45a0-b0a5-78b6c1756c91',
        const Utf8Encoder().convert('CHARGE OFF'),
      );

      await Future<void>.delayed(Duration.zero);
      expect(statefulDevice.battery.isCharging, isFalse);

      statefulDevice.reset();
    });
  });
}