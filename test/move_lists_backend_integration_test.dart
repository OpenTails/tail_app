import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:tail_app/Backend/Definitions/Action/base_action.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/move_lists_backend.dart';
import 'package:tail_app/main.dart';
import 'package:tail_app/constants.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('MoveLists Integration Tests', () {
    late MoveLists moveLists;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Initialize Hive before running tests using the app's initHive function
      await initHive();

      // Clear any existing data in sequencesBox to ensure clean state
      final box = Hive.box<MoveList>(sequencesBox);
      await box.clear();

      // Initialize the MoveLists instance
      moveLists = MoveLists.instance;

      // reload instance incase data still exists
      moveLists.reload();
    });

    tearDown(() async {
      await Hive.box<MoveList>(sequencesBox).clear();
    });

    test('MoveLists should initialize with empty list', () async {
      expect(moveLists.state.length, equals(0));
    });

    test('MoveLists.add should add a new move list', () async {
      final moveList = MoveList(name: 'Test List', moves: [Move.move(leftServo: 50, rightServo: 60)], uuid: const Uuid().v4(), deviceCategory: [DeviceType.wings]);

      await moveLists.add(moveList);

      expect(moveLists.state.length, equals(1));
      expect(moveLists.state.first.name, equals('Test List'));
    });

    test('MoveLists.replace should update an existing move list', () async {
      final originalList = MoveList(name: 'Original List', moves: [Move.move(leftServo: 50, rightServo: 60)], uuid: const Uuid().v4(), deviceCategory: [DeviceType.wings]);
      await moveLists.add(originalList);

      final updatedList = MoveList(name: 'Updated List', moves: [Move.move(leftServo: 70, rightServo: 80)], uuid: const Uuid().v4(), deviceCategory: [DeviceType.wings]);

      await moveLists.replace(originalList, updatedList);

      expect(moveLists.state.length, equals(1));
      expect(moveLists.state.first.name, equals('Updated List'));
    });

    test('MoveLists.remove should delete a move list', () async {
      final moveList = MoveList(name: 'To Be Deleted', moves: [Move.move(leftServo: 50, rightServo: 60)], uuid: const Uuid().v4(), deviceCategory: [DeviceType.wings]);
      await moveLists.add(moveList);

      expect(moveLists.state.length, equals(1));

      await moveLists.remove(moveList);

      expect(moveLists.state.length, equals(0));
    });

    test('MoveLists.store should persist data to Hive', () async {
      final moveList = MoveList(name: 'Persisted List', moves: [Move.move(leftServo: 50, rightServo: 60)], uuid: const Uuid().v4(), deviceCategory: [DeviceType.wings]);
      await moveLists.add(moveList);

      //force reloading data from hive
      moveLists.reload();

      expect(moveLists.state.length, equals(1));
      expect(moveLists.state.first.name, equals('Persisted List'));
    });
  });
}
