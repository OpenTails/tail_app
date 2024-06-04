import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' as flTest;
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/LoggingWrappers.dart';
import 'package:tail_app/Backend/device_registry.dart';
import 'package:test/test.dart';

import '../testing_utils/gear_utils.dart';
import '../testing_utils/hive_utils.dart';

Future<void> testGearAdd(String name) async {
  final container = ProviderContainer(
    overrides: [],
  );
  expect(container.read(knownDevicesProvider).length, 0);
  expect(HiveProxy.getAll<BaseStoredDevice>('devices').length, 0);
  BaseStatefulDevice baseStatefulDevice = await createAndStoreGear(name, container);
  expect(baseStatefulDevice.baseDeviceDefinition.btName, name);
  expect(container.read(knownDevicesProvider).length, 1);
  expect(container.read(knownDevicesProvider).values.first, baseStatefulDevice);
  expect(HiveProxy.getAll<BaseStoredDevice>('devices').length, 1);
  expect(HiveProxy.getAll<BaseStoredDevice>('devices').first, baseStatefulDevice.baseStoredDevice);
}

void main() {
  setUp(() async {
    flTest.TestWidgetsFlutterBinding.ensureInitialized();
    await setupHive();
  });
  tearDown(() async {
    await deleteHive();
  });
  group('Test creating gear', () {
    test('Test storing MiTail to ref', () async {
      await testGearAdd('MiTail');
    });
    test('Test storing (!)Tail1 to ref', () async {
      await testGearAdd('(!)Tail1');
    });
    test('Test storing minitail to ref', () async {
      await testGearAdd('minitail');
    });
    test('Test storing flutter to ref', () async {
      await testGearAdd('flutter');
    });
    test('Test storing EG2 to ref', () async {
      await testGearAdd('EG2');
    });
    test('Test storing EarGear to ref', () async {
      await testGearAdd('EarGear');
    });
  });
  test('Get all service IDs', () {
    List<String> allIds = DeviceRegistry.getAllIds();
    String itemsAsList = allIds.toString();
    expect(itemsAsList, "[3af2108b-d066-42da-a7d4-55648fa0a9b6, 927dee04-ddd4-4582-8e42-69dc9fbfae66]");
  });
}
