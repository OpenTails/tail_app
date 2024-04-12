import 'package:cross_platform/cross_platform.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_dio/sentry_dio.dart';

Future<bool> getBluetoothPermission() async {
  bool granted = false;
  if (Platform.isAndroid && (await DeviceInfoPlugin().androidInfo).version.sdkInt > 30) {
    granted = PermissionStatus.granted == await Permission.bluetoothScan.request();
    granted = granted && PermissionStatus.granted == await Permission.bluetoothConnect.request();
  } else {
    granted = PermissionStatus.granted == await Permission.location.request();
    granted = granted && PermissionStatus.granted == await Permission.locationWhenInUse.request();
    granted = granted && PermissionStatus.granted == await Permission.bluetooth.request();
  }
  return granted;
}

Dio initDio() {
  final Dio dio = Dio();

  /// This *must* be the last initialization step of the Dio setup, otherwise
  /// your configuration of Dio might overwrite the Sentry configuration.
  dio.httpClientAdapter = NativeAdapter();
  dio.addSentry(failedRequestStatusCodes: []);
  return dio;
}
