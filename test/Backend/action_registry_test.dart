import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' as flTest;
import 'package:flutter_test/flutter_test.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Definitions/Action/base_action.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/action_registry.dart';

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
  test('All actions count', () {
    expect(ActionRegistry.allCommands.length, 26);
  });

  group('GetAvailableActions', () {
    test('Tail Actions', () async {
      ProviderContainer providerContainer = await testGearAdd('MiTail');
      BuiltMap<ActionCategory, BuiltSet<BaseAction>> actions = providerContainer.read(getAvailableActionsProvider);
      expect(actions.length, 3);
      expect(actions[ActionCategory.calm]?.length, 3);
      expect(actions[ActionCategory.fast]?.length, 4);
      expect(actions[ActionCategory.tense]?.length, 4);

      providerContainer.read(knownDevicesProvider).values.first.hasGlowtip.value = GlowtipStatus.glowtip;
      providerContainer.invalidate(getAvailableActionsProvider);
      BuiltMap<ActionCategory, BuiltSet<BaseAction>> actions2 = providerContainer.read(getAvailableActionsProvider);
      expect(actions2.length, 4);
      expect(actions2[ActionCategory.calm]?.length, 3);
      expect(actions2[ActionCategory.fast]?.length, 4);
      expect(actions2[ActionCategory.tense]?.length, 4);
      expect(actions2[ActionCategory.glowtip]?.length, 7);
    });
    test('Ear Actions', () async {
      ProviderContainer providerContainer = await testGearAdd('EG2');
      BuiltMap<ActionCategory, BuiltSet<BaseAction>> actions = providerContainer.read(getAvailableActionsProvider);
      expect(actions.length, 1);
      expect(actions[ActionCategory.ears]?.length, 8);
    });
    test('Mini Tail Actions', () async {
      ProviderContainer providerContainer = await testGearAdd('minitail');
      BuiltMap<ActionCategory, BuiltSet<BaseAction>> actions = providerContainer.read(getAvailableActionsProvider);
      expect(actions.length, 2);
      expect(actions[ActionCategory.calm]?.length, 3);
      expect(actions[ActionCategory.fast]?.length, 1);
    });
    test('Wings Actions', () async {
      ProviderContainer providerContainer = await testGearAdd('flutter');
      BuiltMap<ActionCategory, BuiltSet<BaseAction>> actions = providerContainer.read(getAvailableActionsProvider);
      expect(actions.length, 3);
      expect(actions[ActionCategory.calm]?.length, 3);
      expect(actions[ActionCategory.fast]?.length, 4);
      expect(actions[ActionCategory.tense]?.length, 4);
    });
    test('No Actions', () async {
      final providerContainer = ProviderContainer(
        overrides: [],
      );
      BuiltMap<ActionCategory, BuiltSet<BaseAction>> actions = providerContainer.read(getAvailableActionsProvider);
      expect(actions.length, 0);
    });
  });

  group('getAllActions', () {
    test('All Actions', () {
      final container = ProviderContainer(
        overrides: [],
      );
      var actions = container.read(getAllActionsProvider);
      expect(actions.length, 5);
    });
  });
}
