import 'package:cross_platform/cross_platform.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logarte/logarte.dart';
import 'package:logging/logging.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:wordpress_client/wordpress_client.dart';

import '../Backend/LoggingWrappers.dart';

Future<bool> getBluetoothPermission(Logger logger) async {
  bool granted = false;
  if (Platform.isAndroid && (await DeviceInfoPlugin().androidInfo).version.sdkInt > 30) {
    PermissionStatus permissionStatusScan = await Permission.bluetoothScan.request();
    logger.info("permissionStatusScan $permissionStatusScan");
    granted = PermissionStatus.granted == permissionStatusScan;
    PermissionStatus permissionStatusConnect = await Permission.bluetoothConnect.request();
    logger.info("permissionStatusConnect $permissionStatusConnect");
    granted = granted && PermissionStatus.granted == permissionStatusConnect;
  } else if (Platform.isAndroid) {
    PermissionStatus permissionStatusLocation = await Permission.location.request();
    logger.info("permissionStatusLocation $permissionStatusLocation");
    granted = PermissionStatus.granted == permissionStatusLocation;
    PermissionStatus permissionStatusLocationInUse = await Permission.locationWhenInUse.request();
    logger.info("permissionStatusLocationInUse $permissionStatusLocationInUse");
    granted = granted && PermissionStatus.granted == permissionStatusLocationInUse;
  } else {
    PermissionStatus permissionStatusBluetooth = await Permission.bluetooth.request();
    logger.info("permissionStatusBluetooth $permissionStatusBluetooth");
    granted = PermissionStatus.granted == permissionStatusBluetooth;
  }
  return granted;
}

final dioLogger = Logger('Dio');

Dio initDio({skipSentry = false}) {
  final Dio dio = Dio();

  /// This *must* be the last initialization step of the Dio setup, otherwise
  /// your configuration of Dio might overwrite the Sentry configuration.
  dio.httpClientAdapter = NativeAdapter();
  /*dio.interceptors.add(
    LogInterceptor(
      requestBody: false,
      requestHeader: false,
      responseBody: false,
      responseHeader: false,
      request: false,
      logPrint: (o) => dioLogger.finer(o.toString()),
    ),
  );*/
  dio.interceptors.add(LogarteDioInterceptor(logarte));
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

Color getTextColor(Color color) {
  int d = 0;

  // Counting the perceptive luminance - human eye favors green color...
  double luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;

  if (luminance > 0.5) {
    return Typography.material2021().black.labelLarge!.color!;
  } else {
    return Typography.material2021().white.labelLarge!.color!;
  }
}
