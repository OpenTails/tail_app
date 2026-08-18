import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'universal_ble_mock.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  group('UniversalBleMock', () {
    late UniversalBleMock mock;

    setUp(() {
      mock = UniversalBleMock();
      UniversalBle.setInstance(mock);
    });

    tearDown(() {
      mock.reset();
    });

    test('getBluetoothAvailabilityState returns configured state', () async {
      expect(
        await UniversalBle.getBluetoothAvailabilityState(),
        AvailabilityState.poweredOn,
      );
      mock.availabilityState = AvailabilityState.poweredOff;
      expect(
        await UniversalBle.getBluetoothAvailabilityState(),
        AvailabilityState.poweredOff,
      );
    });

    test('connect resolves and updates connection state', () async {
      mock.mockServices('AA:BB:CC:DD:EE:FF', []);
      await UniversalBle.connect('AA:BB:CC:DD:EE:FF');
      expect(
        await UniversalBle.getConnectionState('AA:BB:CC:DD:EE:FF'),
        BleConnectionState.connected,
      );
    });

    test('disconnect updates connection state', () async {
      mock.mockServices('AA:BB:CC:DD:EE:FF', []);
      await UniversalBle.connect('AA:BB:CC:DD:EE:FF');
      await UniversalBle.disconnect('AA:BB:CC:DD:EE:FF');
      expect(
        await UniversalBle.getConnectionState('AA:BB:CC:DD:EE:FF'),
        BleConnectionState.disconnected,
      );
    });

    test('discoverServices returns mocked services', () async {
      final service = BleService('0000ffe0-0000-1000-8000-00805f9b34fb', [
        BleCharacteristic(
          '0000ffe1-0000-1000-8000-00805f9b34fb',
          [CharacteristicProperty.write, CharacteristicProperty.notify],
          [],
        ),
      ]);
      mock.mockServices('AA:BB:CC:DD:EE:FF', [service]);

      final services = await UniversalBle.discoverServices('AA:BB:CC:DD:EE:FF');
      expect(services, hasLength(1));
      expect(services.first.uuid, service.uuid);
      expect(services.first.characteristics, hasLength(1));
    });

    test('write stores value and read returns it', () async {
      mock.mockServices('AA:BB:CC:DD:EE:FF', []);
      final value = Uint8List.fromList([1, 2, 3, 4]);
      await UniversalBle.write(
        'AA:BB:CC:DD:EE:FF',
        '0000ffe0-0000-1000-8000-00805f9b34fb',
        '0000ffe1-0000-1000-8000-00805f9b34fb',
        value,
      );
      expect(
        mock.writtenValues[
            'aa:bb:cc:dd:ee:ff/0000ffe0-0000-1000-8000-00805f9b34fb/0000ffe1-0000-1000-8000-00805f9b34fb'],
        value,
      );
    });

    test('simulateValue triggers onValueChange', () async {
      Uint8List? received;
      UniversalBle.onValueChange = (id, characteristic, value, timestamp) {
        received = value;
      };
      final value = Uint8List.fromList([9, 8, 7]);
      mock.simulateValue(
        'AA:BB:CC:DD:EE:FF',
        '0000ffe0-0000-1000-8000-00805f9b34fb',
        '0000ffe1-0000-1000-8000-00805f9b34fb',
        value,
      );
      expect(received, value);
    });

    test('requestMtu returns expected value', () async {
      mock.mockServices('AA:BB:CC:DD:EE:FF', []);
      final mtu = await UniversalBle.requestMtu('AA:BB:CC:DD:EE:FF', 512);
      expect(mtu, 512);
    });

    test('pair/unpair updates state', () async {
      mock.mockServices('AA:BB:CC:DD:EE:FF', []);
      expect(await UniversalBle.isPaired('AA:BB:CC:DD:EE:FF'), false);
      await UniversalBle.pair('AA:BB:CC:DD:EE:FF');
      expect(await UniversalBle.isPaired('AA:BB:CC:DD:EE:FF'), true);
      await UniversalBle.unpair('AA:BB:CC:DD:EE:FF');
      expect(await UniversalBle.isPaired('AA:BB:CC:DD:EE:FF'), false);
    });

    test('getSystemDevices returns mocked devices', () async {
      mock.addSystemDevice(
        BleDevice(
          deviceId: 'AA:BB:CC:DD:EE:FF',
          name: 'Test Device',
          isSystemDevice: true,
        ),
      );
      final devices = await UniversalBle.getSystemDevices();
      expect(devices, hasLength(1));
      expect(devices.first.deviceId, 'AA:BB:CC:DD:EE:FF');
    });

    test('startScan/stopScan/isScanning', () async {
      await UniversalBle.startScan();
      expect(await UniversalBle.isScanning(), true);
      await UniversalBle.stopScan();
      expect(await UniversalBle.isScanning(), false);
    });
  });
}