import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_utils.dart';

// Annotation which generates the cat.mocks.dart library and the MockCat class.
@GenerateNiceMocks([MockSpec<FlutterBluePlusMockable>(), MockSpec<BluetoothEvents>()])
import 'bluetooth_test_utils.mocks.dart';

void setupBTMock(String btName, String btMac) {
  MockFlutterBluePlusMockable flutterBluePlusMock = MockFlutterBluePlusMockable();
  flutterBluePlus = flutterBluePlusMock;
  when(flutterBluePlusMock.isSupported).thenAnswer((_) async => true);
  when(flutterBluePlusMock.adapterState).thenAnswer((_) => Stream.fromIterable([BluetoothAdapterState.on]));
  when(flutterBluePlusMock.isScanning).thenAnswer((_) => Stream.fromIterable([false]));
  when(flutterBluePlusMock.isScanningNow).thenAnswer((_) => true);
  when(flutterBluePlusMock.isSupported).thenAnswer((_) async => true);
  when(flutterBluePlusMock.isSupported).thenAnswer((_) async => true);
  when(flutterBluePlusMock.connectedDevices).thenAnswer((_) => [BluetoothDevice(remoteId: DeviceIdentifier(btMac))]);
  when(flutterBluePlusMock.scanResults).thenAnswer((_) =>
      Stream.value([ScanResult(rssi: 50, advertisementData: AdvertisementData(advName: btName, txPowerLevel: null, appearance: null, connectable: true, manufacturerData: {}, serviceData: {}, serviceUuids: []), device: BluetoothDevice(remoteId: DeviceIdentifier(btMac)), timeStamp: DateTime.now())]));
  when(flutterBluePlusMock.onScanResults).thenAnswer((_) =>
      Stream.value([ScanResult(rssi: 50, advertisementData: AdvertisementData(advName: btName, txPowerLevel: null, appearance: null, connectable: true, manufacturerData: {}, serviceData: {}, serviceUuids: []), device: BluetoothDevice(remoteId: DeviceIdentifier(btMac)), timeStamp: DateTime.now())]));
  when(flutterBluePlusMock.setLogLevel(any, color: any)).thenReturn(Future(() {}));

  BluetoothEvents bluetoothEvents = MockBluetoothEvents();
  when(flutterBluePlusMock.events).thenAnswer((_) => bluetoothEvents);
  when(bluetoothEvents.onMtuChanged).thenAnswer((_) => Stream.fromIterable([OnMtuChangedEvent(BmMtuChangedResponse(mtu: 50, success: true, remoteId: DeviceIdentifier(btMac)))]));
  when(bluetoothEvents.onReadRssi).thenAnswer((_) => Stream.fromIterable([OnReadRssiEvent(BmReadRssiResult(rssi: 50, success: true, remoteId: DeviceIdentifier(btMac), errorCode: 0, errorString: ''))]));
  when(bluetoothEvents.onServicesReset).thenAnswer((_) => Stream.fromIterable([OnServicesResetEvent(BmBluetoothDevice(remoteId: DeviceIdentifier(btMac), platformName: btName))]));
  when(bluetoothEvents.onDiscoveredServices).thenAnswer((_) => Stream.fromIterable([OnDiscoveredServicesEvent(BmDiscoverServicesResult(remoteId: DeviceIdentifier(btMac), services: [], success: true, errorCode: 0, errorString: ''))]));
  when(bluetoothEvents.onConnectionStateChanged).thenAnswer((_) => Stream.fromIterable([OnConnectionStateChangedEvent(BmConnectionStateResponse(remoteId: DeviceIdentifier(btMac), connectionState: BmConnectionStateEnum.connected, disconnectReasonCode: null, disconnectReasonString: null))]));
}
