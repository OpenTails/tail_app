import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' as flTest;
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
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
  group('Stateful Device event listeners', () {
    test('Battery Levels', () async {
      setupBTMock('MiTail', 'TestMiTail');
      ProviderContainer container = await testGearAdd('MiTail', gearMacPrefix: 'Test');
      BaseStatefulDevice baseStatefulDevice = container.read(knownDevicesProvider).values.first;
      expect(baseStatefulDevice.batteryLevel.value, -1);
      expect(baseStatefulDevice.batlevels.isEmpty, true);
      baseStatefulDevice.batteryLevel.value = 100;
      expect(baseStatefulDevice.batteryLevel.value, 100);
      expect(baseStatefulDevice.batlevels.length, 1);
      expect(baseStatefulDevice.batlevels.first.y, 100);
      baseStatefulDevice.reset();
      expect(baseStatefulDevice.batteryLevel.value, -1);
      expect(baseStatefulDevice.batlevels.isEmpty, true);
    });
  });
}
