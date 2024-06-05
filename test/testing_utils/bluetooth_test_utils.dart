import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_utils.dart';

// Annotation which generates the cat.mocks.dart library and the MockCat class.
@GenerateNiceMocks([MockSpec<FlutterBluePlusMockable>(), MockSpec<BluetoothEvents>()])
import 'bluetooth_test_utils.mocks.dart';

void setupBTMock(String btName, String btMac) {
  flutterBluePlus = MockFlutterBluePlusMockable();

  when(flutterBluePlus.isSupported).thenAnswer((_) async => true);
  when(flutterBluePlus.adapterState).thenAnswer((_) => Stream.fromIterable([BluetoothAdapterState.on]));
  when(flutterBluePlus.isScanning).thenAnswer((_) => Stream.fromIterable([false]));
  when(flutterBluePlus.isScanningNow).thenAnswer((_) => true);
  when(flutterBluePlus.isSupported).thenAnswer((_) async => true);
  when(flutterBluePlus.isSupported).thenAnswer((_) async => true);
  when(flutterBluePlus.connectedDevices).thenAnswer((_) => [BluetoothDevice(remoteId: DeviceIdentifier(btMac))]);
  when(flutterBluePlus.scanResults).thenAnswer((_) =>
      Stream.value([ScanResult(rssi: 50, advertisementData: AdvertisementData(advName: btName, txPowerLevel: null, appearance: null, connectable: true, manufacturerData: {}, serviceData: {}, serviceUuids: []), device: BluetoothDevice(remoteId: DeviceIdentifier(btMac)), timeStamp: DateTime.now())]));
  when(flutterBluePlus.onScanResults).thenAnswer((_) =>
      Stream.value([ScanResult(rssi: 50, advertisementData: AdvertisementData(advName: btName, txPowerLevel: null, appearance: null, connectable: true, manufacturerData: {}, serviceData: {}, serviceUuids: []), device: BluetoothDevice(remoteId: DeviceIdentifier(btMac)), timeStamp: DateTime.now())]));
  when(flutterBluePlus.setLogLevel(LogLevel.warning, color: true)).thenReturn(Future(() {}));

  BluetoothEvents bluetoothEvents = MockBluetoothEvents();
  when(flutterBluePlus.events).thenAnswer((_) => bluetoothEvents);
  when(bluetoothEvents.onMtuChanged).thenAnswer((_) => Stream.fromIterable([OnMtuChangedEvent(BmMtuChangedResponse(mtu: 50, success: true, remoteId: DeviceIdentifier(btMac)))]));
  when(bluetoothEvents.onReadRssi).thenAnswer((_) => Stream.fromIterable([OnReadRssiEvent(BmReadRssiResult(rssi: 50, success: true, remoteId: DeviceIdentifier(btMac), errorCode: 0, errorString: ''))]));
  when(bluetoothEvents.onServicesReset).thenAnswer((_) => Stream.fromIterable([OnServicesResetEvent(BmBluetoothDevice(remoteId: DeviceIdentifier(btMac), platformName: btName))]));
  when(bluetoothEvents.onDiscoveredServices).thenAnswer((_) => Stream.fromIterable([OnDiscoveredServicesEvent(BmDiscoverServicesResult(remoteId: DeviceIdentifier(btMac), services: [], success: true, errorCode: 0, errorString: ''))]));
  when(bluetoothEvents.onConnectionStateChanged).thenAnswer((_) => Stream.fromIterable([OnConnectionStateChangedEvent(BmConnectionStateResponse(remoteId: DeviceIdentifier(btMac), connectionState: BmConnectionStateEnum.connected, disconnectReasonCode: null, disconnectReasonString: null))]));
}
