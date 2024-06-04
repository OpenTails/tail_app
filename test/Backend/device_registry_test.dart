import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' as flTest;
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/LoggingWrappers.dart';
import 'package:test/test.dart';

import '../testing_utils/gear_utils.dart';
import '../testing_utils/hive_utils.dart';

void main() {
  setUpAll(() async {
    flTest.TestWidgetsFlutterBinding.ensureInitialized();
    await setupHive();
  });
  tearDownAll(() async {
    await deleteHive();
  });
  test('Test storing gear to ref', () async {
    final container = ProviderContainer(
      overrides: [],
    );
    expect(container.read(knownDevicesProvider).length, 0);
    expect(HiveProxy.getAll<BaseStoredDevice>('devices').length, 0);
    BaseStatefulDevice baseStatefulDevice = await createAndStoreGear('MiTail', container);
    expect(baseStatefulDevice.baseDeviceDefinition.btName, 'MiTail');
    expect(container.read(knownDevicesProvider).length, 1);
    expect(container.read(knownDevicesProvider).values.first, baseStatefulDevice);
    expect(HiveProxy.getAll<BaseStoredDevice>('devices').length, 1);
    expect(HiveProxy.getAll<BaseStoredDevice>('devices').first, baseStatefulDevice.baseStoredDevice);
  });
}
