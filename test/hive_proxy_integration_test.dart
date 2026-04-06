import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:tail_app/Backend/logging_wrappers.dart';
import 'package:tail_app/constants.dart';
import 'package:tail_app/main.dart';

// Import adapters used in the app

void main() {
  group('HiveProxy Integration Tests, No <> type', () {
    late String testBoxName;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Initialize Hive before running tests using the app's initHive function
      await initHive();

      // "dynamic" boxes are limited to settings as there is no reliable way to dynamically check if a <Type> is specified or not.
      testBoxName = settings;

      // Open the box
      await Hive.openBox(testBoxName);
    });

    tearDown(() async {
      // Clean up by closing the test box
      final box = Hive.box(testBoxName);
      await box.clear();
      await box.close();
      await Hive.openBox(testBoxName);
    });

    test('HiveProxy should initialize successfully', () async {
      // Verify Hive is initialized and can open a box
      expect(() => Hive.box(testBoxName), returnsNormally);
    });

    test('HiveProxy.put should store a value', () async {
      final key = 'test_key';
      final value = 'test_value';

      await HiveProxy.put(testBoxName, key, value);

      final retrievedValue = HiveProxy.getOrDefault(
        testBoxName,
        key,
        defaultValue: "stored",
      );
      expect(retrievedValue, equals(value));
    });

    test(
      'HiveProxy.getOrDefault should return default when key not found',
      () async {
        final nonExistentKey = 'non_existent_key';
        final defaultValue = 'default_value';

        final retrievedValue = HiveProxy.getOrDefault(
          testBoxName,
          nonExistentKey,
          defaultValue: defaultValue,
        );
        expect(retrievedValue, equals(defaultValue));
      },
    );

    test('HiveProxy.deleteKey should remove a value', () async {
      final key = 'key_to_delete';
      final value = 'value_to_delete';

      await HiveProxy.put(testBoxName, key, value);
      expect(
        HiveProxy.getOrDefault(testBoxName, key, defaultValue: ""),
        equals(value),
      );

      await HiveProxy.deleteKey(testBoxName, key);
      final retrievedValue = HiveProxy.getOrDefault(
        testBoxName,
        key,
        defaultValue: "deleted",
      );
      expect(retrievedValue, equals("deleted"));
    });
  });
}
