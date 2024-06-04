import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' as flTest;
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Definitions/Action/base_action.dart';
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
  group('Test getting gear by id', () {
    test('verify number of device definitions', () {
      expect(DeviceRegistry.allDevices.length, 6);
    });
    test('Test getting MiTail by id', () async {
      BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.getByUUID("798e1528-2832-4a87-93d7-4d1b25a2f418");
      expect(baseDeviceDefinition.uuid, "798e1528-2832-4a87-93d7-4d1b25a2f418");
    });
    test('Test getting (!)Tail1 by id', () async {
      BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.getByUUID("9c5f3692-1c6e-4d46-b607-4f6f4a6e28ee");
      expect(baseDeviceDefinition.uuid, "9c5f3692-1c6e-4d46-b607-4f6f4a6e28ee");
    });
    test('Test getting minitail by id', () async {
      BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.getByUUID("5fb21175-fef4-448a-a38b-c472d935abab");
      expect(baseDeviceDefinition.uuid, "5fb21175-fef4-448a-a38b-c472d935abab");
    });
    test('Test getting flutter by id', () async {
      BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.getByUUID("e790f509-f95b-4eb4-b649-5b43ee1eee9c");
      expect(baseDeviceDefinition.uuid, "e790f509-f95b-4eb4-b649-5b43ee1eee9c");
    });
    test('Test getting EG2 by id', () async {
      BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.getByUUID("927dee04-ddd4-4582-8e42-69dc9fbfae66");
      expect(baseDeviceDefinition.uuid, "927dee04-ddd4-4582-8e42-69dc9fbfae66");
    });
    test('Test getting EarGear by id', () async {
      BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.getByUUID("ba2f2b00-8f65-4cc3-afad-58ba1fccd62d");
      expect(baseDeviceDefinition.uuid, "ba2f2b00-8f65-4cc3-afad-58ba1fccd62d");
    });
  });
  group('Get known gear by action', () {
    test('Get Tail from action', () async {
      final container = ProviderContainer(
        overrides: [],
      );
      String name = 'MiTail';
      String name2 = 'EG2';
      expect(container.read(knownDevicesProvider).length, 0);
      expect(HiveProxy.getAll<BaseStoredDevice>('devices').length, 0);
      BaseStatefulDevice baseStatefulDevice = await createAndStoreGear(name, container);
      expect(baseStatefulDevice.baseDeviceDefinition.btName, name);
      expect(container.read(knownDevicesProvider).length, 1);
      expect(container.read(knownDevicesProvider).values.first, baseStatefulDevice);
      expect(HiveProxy.getAll<BaseStoredDevice>('devices').length, 1);
      expect(HiveProxy.getAll<BaseStoredDevice>('devices').first, baseStatefulDevice.baseStoredDevice);

      BaseStatefulDevice baseStatefulDevice2 = await createAndStoreGear(name2, container);
      expect(baseStatefulDevice2.baseDeviceDefinition.btName, name2);
      expect(container.read(knownDevicesProvider).length, 2);
      expect(container.read(knownDevicesProvider).values.contains(baseStatefulDevice2), true);
      expect(HiveProxy.getAll<BaseStoredDevice>('devices').length, 2);
      expect(HiveProxy.getAll<BaseStoredDevice>('devices').contains(baseStatefulDevice2.baseStoredDevice), true);

      BaseAction baseAction = BaseAction(name: "name", deviceCategory: [DeviceType.tail], actionCategory: ActionCategory.hidden, uuid: "uuid");
      BaseAction baseAction2 = BaseAction(name: "name1", deviceCategory: [DeviceType.ears], actionCategory: ActionCategory.hidden, uuid: "uuid1");
      BaseAction baseAction3 = BaseAction(name: "name2", deviceCategory: [DeviceType.tail, DeviceType.ears], actionCategory: ActionCategory.hidden, uuid: "uuid2");

      Set<BaseStatefulDevice> devices = container.read(getByActionProvider(baseAction));
      expect(devices.length, 1);
      expect(devices.first, baseStatefulDevice);

      devices = {};
      devices = container.read(getByActionProvider(baseAction2));
      expect(devices.length, 1);
      expect(devices.first, baseStatefulDevice2);

      devices = {};
      devices = container.read(getByActionProvider(baseAction3));
      expect(devices.length, 2);
      expect(devices.contains(baseStatefulDevice), true);
      expect(devices.contains(baseStatefulDevice2), true);
    });
  });
  test('Get all service IDs', () {
    List<String> allIds = DeviceRegistry.getAllIds();
    expect(allIds.length, 2);
    String itemsAsList = allIds.toString();
    expect(itemsAsList, "[3af2108b-d066-42da-a7d4-55648fa0a9b6, 927dee04-ddd4-4582-8e42-69dc9fbfae66]");
  });
}
