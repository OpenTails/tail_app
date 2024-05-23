import 'package:cross_platform/cross_platform.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:wordpress_client/wordpress_client.dart';

Future<bool> getBluetoothPermission() async {
  bool granted = false;
  if (Platform.isAndroid && (await DeviceInfoPlugin().androidInfo).version.sdkInt > 30) {
    granted = PermissionStatus.granted == await Permission.bluetoothScan.request();
    granted = granted && PermissionStatus.granted == await Permission.bluetoothConnect.request();
  } else if (Platform.isAndroid) {
    granted = PermissionStatus.granted == await Permission.location.request();
    granted = granted && PermissionStatus.granted == await Permission.locationWhenInUse.request();
    granted = granted && PermissionStatus.granted == await Permission.bluetooth.request();
  } else {
    granted = PermissionStatus.granted == await Permission.bluetooth.request();
  }
  return granted;
}

final dioLogger = Logger('Dio');

Dio initDio({skipSentry = false}) {
  final Dio dio = Dio();

  /// This *must* be the last initialization step of the Dio setup, otherwise
  /// your configuration of Dio might overwrite the Sentry configuration.
  dio.httpClientAdapter = NativeAdapter();
  dio.interceptors.add(
    LogInterceptor(
      requestBody: false,
      requestHeader: false,
      responseBody: false,
      responseHeader: false,
      request: false,
      logPrint: (o) => dioLogger.finer(o.toString()),
    ),
  );
  if (!skipSentry) {
    dio.addSentry(failedRequestStatusCodes: []);
  }
  return dio;
}

WordpressClient getWordpressClient() {
  return WordpressClient.fromDioInstance(baseUrl: Uri.parse('https://thetailcompany.com/wp-json/wp/v2'), instance: initDio());
}

Version getVersionSemVer(String input) {
  String major = "0";
  String minor = "0";
  String patch = "0";
  List<String> split = input.split(".");
  if (split.isNotEmpty && int.tryParse(split[0]) != null) {
    major = split[0];
  }
  if (split.length > 1 && int.tryParse(split[1]) != null) {
    minor = split[1];
  }
  if (split.length > 2 && int.tryParse(split[2]) != null) {
    patch = split[2].replaceAll(RegExp(r"\D"), "");
  }
  return Version(int.parse(major), int.parse(minor), int.parse(patch));
}
