import 'package:flutter_test/flutter_test.dart' as flTest;
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/framework.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_message.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/LoggingWrappers.dart';
import 'package:tail_app/Backend/move_lists.dart';

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
  });
}
