import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tail_app/Backend/Action/action_registry.dart';
import 'package:tail_app/Backend/Action/base_action.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_message.dart';
import 'package:tail_app/Backend/Device/command/command_runner.dart';
import 'package:tail_app/Backend/Device/device_type_enum.dart';
import 'package:tail_app/Backend/Device/ear_speed_enum.dart';
import 'package:tail_app/Backend/Device/stateful/connected_gear.dart';
import 'package:tail_app/Backend/Device/stored_device.dart';
import 'package:tail_app/Backend/move_lists_backend.dart';
import 'package:tail_app/Backend/utilities/hive.dart';
import 'package:tail_app/constants.dart';

import 'helpers/test_gear.dart';

void main() {
  late StatefulDevice tailDevice;
  late StatefulDevice earsDevice;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'tail_app',
      packageName: 'com.example.tail_app',
      version: '1.5.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await initHive();
    await Hive.openBox<StoredDevice>(devicesBox);
    // Disable action analytics and set matching build number so the config
    // isn't deleted by getDynamicConfigInfo()
    await Hive.box(settings).put(
      dynamicConfigJsonString,
      jsonEncode({
        'featureFlags': {'enableActionAnalytics': false},
      }),
    );
    await Hive.box(settings).put(dynamicConfigStoredBuildNumber, '1');
  });

  setUp(() async {
    await Hive.box<StoredDevice>(devicesBox).clear();
    tailDevice = await TestGear.createConnectedStatefulDevice(
      'AA:BB:CC:DD:EE:20',
    );
    earsDevice = await TestGear.createConnectedStatefulDevice(
      'AA:BB:CC:DD:EE:21',
      deviceName: 'EG2',
    );
  });

  tearDown(() async {
    tailDevice.reset();
    earsDevice.reset();
    await Hive.box<StoredDevice>(devicesBox).clear();
  });

  group('generateMoveCommand', () {
    test('generates TAILHM command for home move on tail device', () {
      final commands = generateMoveCommand(
        Move.home(),
        tailDevice,
        CommandType.move,
      );

      expect(commands, hasLength(1));
      expect(commands.first.message, 'TAILHM');
      expect(commands.first.responseMSG, 'END TAILHM');
      expect(commands.first.type, CommandType.move);
    });

    test('generates EARHOME command for home move on legacy ears device', () {
      final commands = generateMoveCommand(
        Move.home(),
        earsDevice,
        CommandType.move,
      );

      expect(commands, hasLength(1));
      expect(commands.first.message, 'EARHOME');
      expect(commands.first.responseMSG, 'EARHOME END');
      expect(commands.first.type, CommandType.move);
    });

    test('generates DSSP command for move on tail device', () {
      final move = Move.move(
        leftServo: 32,
        rightServo: 64,
        speed: 50,
        easingType: EasingType.linear,
      );
      final commands = generateMoveCommand(move, tailDevice, CommandType.move);

      expect(commands, hasLength(1));
      expect(commands.first.message, 'DSSP E0 F0 A2 B4 L50 M50');
      expect(commands.first.responseMSG, 'OK');
      expect(commands.first.type, CommandType.move);
    });

    test('generates speed + DSSP commands for move on legacy ears device', () {
      final move = Move.move(leftServo: 32, rightServo: 64, speed: 50);
      final commands = generateMoveCommand(move, earsDevice, CommandType.move);

      expect(commands, hasLength(2));
      expect(commands[0].message, EarSpeed.slow.command);
      expect(commands[0].responseMSG, EarSpeed.slow.command);
      expect(commands[1].message, 'DSSP 32 64 000 000');
      expect(commands[1].responseMSG, 'DSSP END');
    });

    test('generates fast speed command for move with speed > 60 on ears', () {
      final move = Move.move(leftServo: 32, rightServo: 64, speed: 80);
      final commands = generateMoveCommand(move, earsDevice, CommandType.move);

      expect(commands, hasLength(2));
      expect(commands[0].message, EarSpeed.fast.command);
      expect(commands[0].responseMSG, EarSpeed.fast.command);
    });

    test('noResponseMsg sets responseMSG to null', () {
      final commands = generateMoveCommand(
        Move.home(),
        tailDevice,
        CommandType.move,
        noResponseMsg: true,
      );

      expect(commands.first.responseMSG, isNull);
    });

    test('respects priority parameter', () {
      final commands = generateMoveCommand(
        Move.home(),
        tailDevice,
        CommandType.move,
        priority: Priority.high,
      );

      expect(commands.first.priority, Priority.high);
    });
  });

  group('generateCommandActionCommands', () {
    test('generates CommandAction command for tail device', () {
      // "Slow Wag 1" tail move
      final action =
          ActionRegistry.getActionFromUUID(
                'c53e980e-899e-4148-a13e-f57a8f9707f4',
              )!
              as CommandAction;

      final commands = generateCommandActionCommands(action, tailDevice);

      expect(commands, hasLength(1));
      expect(commands.first.message, 'TAILS1');
      expect(commands.first.responseMSG, 'TAILS1 END');
      expect(commands.first.type, CommandType.move);
    });

    test('generates CommandAction with RGB brightness command', () async {
      await Hive.box(settings).put(rgbBrightness, 50.0);
      // "LEDs off" RGB command
      final action =
          ActionRegistry.getActionFromUUID(
                '3b40bd70-c90c-4939-a3e8-d3910a54cf9d',
              )!
              as CommandAction;

      final commands = generateCommandActionCommands(action, tailDevice);

      expect(commands, hasLength(1));
      expect(commands.first.message, 'RGBOFF 50');
    });

    test('generates legacy ear commands for CommandAction on ears device', () {
      // "Ears Wide" ear move with legacyEarCommandMoves
      final action =
          ActionRegistry.getActionFromUUID(
                'd8384bcf-31ed-4b5d-a25a-da3a2f96e406',
              )!
              as CommandAction;

      final commands = generateCommandActionCommands(action, earsDevice);

      expect(commands, hasLength(5));
      // Speed command first
      expect(commands[0].message, EarSpeed.fast.command);
      expect(commands[0].responseMSG, EarSpeed.fast.command);
      // Then delay(1)
      expect(commands[1].delay, 1);
      expect(commands[1].message, '');
      // Then BOTWIST 30
      expect(commands[2].message, 'BOTWIST 30');
      expect(commands[2].responseMSG, 'BOTWIST END');
      // Then delay(100)
      expect(commands[3].delay, 100);
      expect(commands[3].message, '');
      // Then EARHOME
      expect(commands[4].message, 'EARHOME');
      expect(commands[4].responseMSG, 'EARHOME END');
    });

    test(
      'generates CommandAction directly for ears device without legacy moves',
      () {
        // "Slow Forward" ear move without legacyEarCommandMoves
        final action =
            ActionRegistry.getActionFromUUID(
                  'a463cdb0-6d23-480b-9478-3db25828e764',
                )!
                as CommandAction;

        final commands = generateCommandActionCommands(action, earsDevice);

        expect(commands, hasLength(1));
        expect(commands.first.message, 'TAILS1');
        expect(commands.first.responseMSG, 'TAILS1 END');
      },
    );
  });

  group('generateMoveListCommand', () {
    test('generates USERMOVE command for short MoveList on tail device', () {
      final moveList = MoveList(
        name: 'Test Sequence',
        uuid: 'test-uuid-1',
        deviceCategory: [DeviceType.tail],
        moves: [
          Move.move(leftServo: 16, rightServo: 32, speed: 50),
          Move.move(leftServo: 32, rightServo: 64, speed: 50),
        ],
      );

      final commands = generateMoveListCommand(moveList, tailDevice);

      expect(commands, hasLength(2));
      expect(
        commands[0].message,
        'USERMOVE U1P2N1 A1A2 B2B4 E0E0 F0F0 L50L50 M50M50 H1',
      );

      expect(commands[0].type, CommandType.move);
      expect(commands[1].message, 'TAILU1');
      expect(commands[1].responseMSG, 'TAILU1 END');
      expect(commands[1].type, CommandType.move);
    });

    test(
      'generates individual move commands for long MoveList on tail device',
      () {
        final moveList = MoveList(
          name: 'Long Sequence',
          uuid: 'test-uuid-2',
          deviceCategory: [DeviceType.tail],
          moves: [
            Move.move(leftServo: 16, rightServo: 32, speed: 50),
            Move.move(leftServo: 32, rightServo: 64, speed: 50),
            Move.move(leftServo: 48, rightServo: 96, speed: 50),
            Move.move(leftServo: 64, rightServo: 128, speed: 50),
            Move.move(leftServo: 80, rightServo: 32, speed: 50),
            Move.move(leftServo: 96, rightServo: 64, speed: 50),
          ],
        );

        final commands = generateMoveListCommand(moveList, tailDevice);

        // 6 DSSP commands + 1 TAILHM home command
        expect(commands, hasLength(7));
        expect(commands[0].message, contains('DSSP'));
        expect(commands.last.message, 'TAILHM');
      },
    );

    test('repeats moves for long MoveList with repeat > 1', () {
      final moveList = MoveList(
        name: 'Repeat Sequence',
        uuid: 'test-uuid-3',
        deviceCategory: [DeviceType.tail],
        moves: [
          Move.move(leftServo: 16, rightServo: 32, speed: 50),
          Move.move(leftServo: 32, rightServo: 64, speed: 50),
          Move.move(leftServo: 48, rightServo: 96, speed: 50),
          Move.move(leftServo: 64, rightServo: 128, speed: 50),
          Move.move(leftServo: 80, rightServo: 32, speed: 50),
          Move.move(leftServo: 96, rightServo: 64, speed: 50),
        ],
        repeat: 2,
      );

      final commands = generateMoveListCommand(moveList, tailDevice);

      // 12 DSSP commands (6 moves x 2 repeats) + 1 TAILHM home command
      expect(commands, hasLength(13));
      expect(commands.last.message, 'TAILHM');
    });

    test('skips first move if it is a delay', () {
      final moveList = MoveList(
        name: 'Delay First',
        uuid: 'test-uuid-4',
        deviceCategory: [DeviceType.tail],
        moves: [
          Move.delay(2),
          Move.move(leftServo: 16, rightServo: 32, speed: 50),
          Move.move(leftServo: 32, rightServo: 64, speed: 50),
        ],
      );

      final commands = generateMoveListCommand(moveList, tailDevice);

      expect(commands, hasLength(2));
      // USERMOVE has 3 moves, first delay is skipped but P3 reflects total moves
      expect(
        commands[0].message,
        'USERMOVE U1P3N1 A1A2 B2B4 E0E0 F0F0 L50L50 M50M50 H1',
      );
      expect(commands[1].message, 'TAILU1');
    });

    test('includes delay commands in move list', () {
      final moveList = MoveList(
        name: 'With Delay',
        uuid: 'test-uuid-5',
        deviceCategory: [DeviceType.tail],
        moves: [
          Move.move(leftServo: 16, rightServo: 32, speed: 50),
          Move.delay(2),
          Move.move(leftServo: 32, rightServo: 64, speed: 50),
        ],
      );

      final commands = generateMoveListCommand(moveList, tailDevice);

      expect(commands, hasLength(2));
      expect(
        commands[0].message,
        'USERMOVE U1P3N1 A1A2A0A2 B2B4B0B4 E0E0E0E0 F0F0F0F0 L50S50L50L50 M50M50M50M50 H1',
      );
      expect(commands[1].message, 'TAILU1');
    });

    test('uses fallback for ears device with long MoveList', () {
      final moveList = MoveList(
        name: 'Long Sequence',
        uuid: 'test-uuid-6',
        deviceCategory: [DeviceType.ears],
        moves: [
          Move.move(leftServo: 16, rightServo: 32, speed: 50),
          Move.move(leftServo: 32, rightServo: 64, speed: 50),
          Move.move(leftServo: 48, rightServo: 96, speed: 50),
          Move.move(leftServo: 64, rightServo: 128, speed: 50),
          Move.move(leftServo: 80, rightServo: 32, speed: 50),
          Move.move(leftServo: 96, rightServo: 64, speed: 50),
        ],
      );

      final commands = generateMoveListCommand(moveList, earsDevice);

      // Speed + DSSP for each of 6 moves + 1 home = 13 commands
      expect(commands, hasLength(13));
      expect(commands.last.message, 'EARHOME');
    });
  });

  group('runAction', () {
    test('queues CommandAction commands on tail device', () async {
      // "Slow Wag 1" tail move
      final action = ActionRegistry.getActionFromUUID(
        'c53e980e-899e-4148-a13e-f57a8f9707f4',
      )!;

      await runAction(tailDevice, action, triggeredBy: 'test');
      await Future<void>.delayed(Duration.zero);

      expect(tailDevice.commandQueue.currentMessage?.message, 'TAILS1');
    });

    test('queues legacy ear commands on ears device', () async {
      // "Ears Wide" ear move with legacyEarCommandMoves
      final action = ActionRegistry.getActionFromUUID(
        'd8384bcf-31ed-4b5d-a25a-da3a2f96e406',
      )!;

      await runAction(earsDevice, action, triggeredBy: 'test');
      await Future<void>.delayed(Duration.zero);

      // Speed command is being processed
      expect(
        earsDevice.commandQueue.currentMessage?.message,
        EarSpeed.fast.command,
      );
    });
  });

  group('runActionOnAllSupportedGear', () {
    test('runs action on all supported gear', () async {
      // "Slow Wag 1" tail move
      final action = ActionRegistry.getActionFromUUID(
        'c53e980e-899e-4148-a13e-f57a8f9707f4',
      )!;

      await runActionOnAllSupportedGear(action, triggeredBy: 'test');
      await Future<void>.delayed(Duration.zero);

      expect(tailDevice.commandQueue.currentMessage?.message, 'TAILS1');
      expect(earsDevice.commandQueue.currentMessage, isNull);
    });

    test('only runs action on matching device type', () async {
      // "Slow Forward" ear move
      final action = ActionRegistry.getActionFromUUID(
        'a463cdb0-6d23-480b-9478-3db25828e764',
      )!;

      await runActionOnAllSupportedGear(action, triggeredBy: 'test');
      await Future<void>.delayed(Duration.zero);

      expect(tailDevice.commandQueue.currentMessage, isNull);
      expect(earsDevice.commandQueue.currentMessage?.message, 'TAILS1');
    });
  });
}
