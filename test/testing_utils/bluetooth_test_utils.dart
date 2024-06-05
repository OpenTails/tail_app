import 'package:mockito/annotations.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_utils.dart';

// Annotation which generates the cat.mocks.dart library and the MockCat class.
@GenerateNiceMocks([MockSpec<FlutterBluePlusMockable>()])
import 'bluetooth_test_utils.mocks.dart';

void setupBTMock() {
  flutterBluePlus = MockFlutterBluePlusMockable();
}
