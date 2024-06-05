import 'package:flutter_test/flutter_test.dart' as flTest;
import 'package:riverpod/src/framework.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_message.dart';
import 'package:tail_app/Backend/Definitions/Action/base_action.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/LoggingWrappers.dart';
import 'package:tail_app/Backend/move_lists.dart';
import 'package:tail_app/Backend/sensors.dart';
import 'package:tail_app/main.dart';
import 'package:test/test.dart';

import '../testing_utils/bluetooth_test_utils.dart';
import '../testing_utils/gear_utils.dart';
import '../testing_utils/hive_utils.dart';

void main() {
  setUp(() async {
    flTest.TestWidgetsFlutterBinding.ensureInitialized();
    await setupHive();
  });
  tearDown(() async {
    await deleteHive();
  });
  group('GenerateMoveCommands', () {
    test('Tail DSSP', () async {
      ProviderContainer providerContainer = await testGearAdd('MiTail');
      BaseStatefulDevice baseStatefulDevice = providerContainer.read(knownDevicesProvider).values.first;
      Move move = Move.move(leftServo: 50, rightServo: 100);
      CommandType type = CommandType.move;
      List<BluetoothMessage> commands = generateMoveCommand(move, baseStatefulDevice, type);
      expect(commands.length, 1);
      expect(commands.first.message, 'DSSP E0 F0 A3 B6 L50 M50');
      expect(commands.first.responseMSG, 'OK');
      expect(commands.first.device, baseStatefulDevice);
      expect(commands.first.type, type);
    });
    test('Tail Home', () async {
      ProviderContainer providerContainer = await testGearAdd('MiTail');
      BaseStatefulDevice baseStatefulDevice = providerContainer.read(knownDevicesProvider).values.first;
      Move move = Move.home();
      CommandType type = CommandType.move;
      List<BluetoothMessage> commands = generateMoveCommand(move, baseStatefulDevice, type);
      expect(commands.length, 1);
      expect(commands.first.message, 'TAILHM');
      expect(commands.first.responseMSG, 'END TAILHM');
      expect(commands.first.device, baseStatefulDevice);
      expect(commands.first.type, type);
    });
    test('EAR DSSP', () async {
      ProviderContainer providerContainer = await testGearAdd('EG2');
      BaseStatefulDevice baseStatefulDevice = providerContainer.read(knownDevicesProvider).values.first;
      Move move = Move.move(leftServo: 50, rightServo: 100);
      CommandType type = CommandType.move;
      List<BluetoothMessage> commands = generateMoveCommand(move, baseStatefulDevice, type);
      expect(commands.length, 2);
      expect(commands[0].message, 'SPEED SLOW');
      expect(commands[0].responseMSG, 'SPEED SLOW');
      expect(commands[0].device, baseStatefulDevice);
      expect(commands[0].type, type);

      expect(commands[1].message, 'DSSP 50 100 000 000');
      expect(commands[1].responseMSG, 'DSSP END');
      expect(commands[1].device, baseStatefulDevice);
      expect(commands[1].type, type);
    });
    test('Ear Home', () async {
      ProviderContainer providerContainer = await testGearAdd('EG2');
      BaseStatefulDevice baseStatefulDevice = providerContainer.read(knownDevicesProvider).values.first;
      Move move = Move.home();
      CommandType type = CommandType.move;
      List<BluetoothMessage> commands = generateMoveCommand(move, baseStatefulDevice, type);
      expect(commands.length, 1);
      expect(commands.first.message, 'EARHOME');
      expect(commands.first.responseMSG, 'EARHOME END');
      expect(commands.first.device, baseStatefulDevice);
      expect(commands.first.type, type);
    });

    group('Storing Movelists', () {
      test('Create Move List', () async {
        MoveList moveList = MoveList(name: 'Test', deviceCategory: DeviceType.values, uuid: 'test');
        final container = ProviderContainer(
          overrides: [],
        );
        expect(container.read(moveListsProvider).isEmpty, true);
        await container.read(moveListsProvider.notifier).add(moveList);
        expect(container.read(moveListsProvider).length, 1);
        expect(container.read(moveListsProvider).first, moveList);
        expect(HiveProxy.getAll<MoveList>('sequences').length, 1);
        //verify movelists are read again from hive
        container.invalidate(moveListsProvider);
        expect(container.read(moveListsProvider).length, 1);
        expect(container.read(moveListsProvider).first, moveList);

        await container.read(moveListsProvider.notifier).remove(moveList);
        expect(container.read(moveListsProvider).isEmpty, true);
        expect(HiveProxy.getAll<MoveList>('sequences').isEmpty, true);
      });
    });
    test('Editing Move List record', () {
      MoveList moveList = MoveList(name: "Test", deviceCategory: DeviceType.values, uuid: 'uuid');
      expect(moveList.moves.isEmpty, true);
      Move move = Move.move(leftServo: 50, rightServo: 100, easingType: EasingType.cubic, speed: 5);
      moveList.moves.add(move);
      expect(moveList.moves.length, 1);
    });
    group('runAction', () {
      //TODO: Mock CommandQueue;
      setUpAll(() {
        initPlausible(enabled: false);
      });
      test('run Ear Move', () async {
        setupBTMock('EG2', 'TestEG2');
        ProviderContainer container = await testGearAdd('EG2', gearMacPrefix: 'Test');
        expect(container.read(knownDevicesProvider).values.length, 1);
        expect(container.read(knownDevicesProvider).values.first.baseDeviceDefinition.btName, 'EG2');
        BaseAction? baseAction = container.read(getActionFromUUIDProvider("9a6be63e-36f5-4f50-88b6-7adf2680aa5c"));
        expect(baseAction != null, true);
        BaseStatefulDevice baseStatefulDevice = container.read(knownDevicesProvider).values.first;
        runAction(baseAction!, baseStatefulDevice);
      });
      test('run Tail Move', () async {
        setupBTMock('MiTail', 'TestMiTail');
        ProviderContainer container = await testGearAdd('MiTail', gearMacPrefix: 'Test');
        expect(container.read(knownDevicesProvider).values.length, 1);
        expect(container.read(knownDevicesProvider).values.first.baseDeviceDefinition.btName, 'MiTail');
        BaseAction? baseAction = container.read(getActionFromUUIDProvider("c53e980e-899e-4148-a13e-f57a8f9707f4"));
        expect(baseAction != null, true);
        BaseStatefulDevice baseStatefulDevice = container.read(knownDevicesProvider).values.first;
        runAction(baseAction!, baseStatefulDevice);
      });

      test('run Ear Custom Move', () async {
        setupBTMock('EG2', 'TestEG2');
        ProviderContainer container = await testGearAdd('EG2', gearMacPrefix: 'Test');
        expect(container.read(knownDevicesProvider).values.length, 1);
        expect(container.read(knownDevicesProvider).values.first.baseDeviceDefinition.btName, 'EG2');
        MoveList moveList = MoveList(name: 'Test', uuid: 'test', deviceCategory: DeviceType.values);
        moveList.moves.add(Move.move(leftServo: 50, rightServo: 50));
        moveList.moves.add(Move.delay(50));
        moveList.moves.add(Move.move(leftServo: 50, rightServo: 50));
        moveList.repeat = 2;
        BaseStatefulDevice baseStatefulDevice = container.read(knownDevicesProvider).values.first;
        runAction(moveList, baseStatefulDevice);
      });
      test('run Tail Custom Move', () async {
        setupBTMock('MiTail', 'TestMiTail');
        ProviderContainer container = await testGearAdd('MiTail', gearMacPrefix: 'Test');
        expect(container.read(knownDevicesProvider).values.length, 1);
        expect(container.read(knownDevicesProvider).values.first.baseDeviceDefinition.btName, 'MiTail');
        MoveList moveList = MoveList(name: 'Test', uuid: 'test', deviceCategory: DeviceType.values);
        moveList.moves.add(Move.move(leftServo: 50, rightServo: 50, easingType: EasingType.cubic));
        moveList.moves.add(Move.delay(50));
        moveList.moves.add(Move.move(leftServo: 50, rightServo: 50));
        moveList.repeat = 2;
        BaseStatefulDevice baseStatefulDevice = container.read(knownDevicesProvider).values.first;
        runAction(moveList, baseStatefulDevice);
      });
    });
  });
}
