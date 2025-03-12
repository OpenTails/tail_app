import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logarte/logarte.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:platform/platform.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wordpress_client/wordpress_client.dart';

import '../Backend/logging_wrappers.dart';
import '../Backend/version.dart';

LocalPlatform platform = const LocalPlatform();

Future<bool> getBluetoothPermission(Logger logger) async {
  bool granted = false;
  if (platform.isAndroid && (await DeviceInfoPlugin().androidInfo).version.sdkInt > 30) {
    PermissionStatus permissionStatusScan = await Permission.bluetoothScan.request();
    logger.info("permissionStatusScan $permissionStatusScan");
    granted = PermissionStatus.granted == permissionStatusScan;
    PermissionStatus permissionStatusConnect = await Permission.bluetoothConnect.request();
    logger.info("permissionStatusConnect $permissionStatusConnect");
    granted = granted && PermissionStatus.granted == permissionStatusConnect;
  } else if (platform.isAndroid) {
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

Dio? _dio;

Future<Dio> initDio({skipSentry = false}) async {
  if (_dio != null) {
    return _dio!;
  }
  final Dio dio = Dio()
    ..interceptors.add(
      LogInterceptor(
        requestBody: false,
        requestHeader: false,
        responseBody: false,
        responseHeader: false,
        request: true,
        logPrint: (o) => dioLogger.finer(o.toString()),
      ),
    )
    ..interceptors.add(LogarteDioInterceptor(logarte));
  dio.interceptors.add(
    RetryInterceptor(
      dio: dio,
      logPrint: dioLogger.info, // specify log function (optional)
      retries: 15, // retry count (optional)
      retryDelays: const [
        // set delays between retries (optional)
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 3),
        Duration(seconds: 4),
        Duration(seconds: 5),
        Duration(seconds: 10),
        Duration(seconds: 20),
        Duration(seconds: 40),
        Duration(seconds: 80),
        Duration(seconds: 160),
        Duration(seconds: 320),
      ],
    ),
  );
  if (!skipSentry) {
    /// This *must* be the last initialization step of the Dio setup, otherwise
    /// your configuration of Dio might overwrite the Sentry configuration.
    dio.addSentry(failedRequestStatusCodes: [SentryStatusCode.range(400, 500)]);
  }
  _dio = dio;
  return dio;
}

WordpressClient? _wordpressClient;

Future<WordpressClient> getWordpressClient() async {
  if (_wordpressClient != null) {
    return _wordpressClient!;
  }
  return WordpressClient.fromDioInstance(baseUrl: Uri.parse('https://thetailcompany.com/wp-json/wp/v2'), instance: await initDio());
}

Version getVersionSemVer(String input) {
  String major = "0";
  String minor = "0";
  String patch = "0";
  List<String> split = input.split(" ").last.split(".");
  if (split.isNotEmpty && int.tryParse(split[0]) != null) {
    major = split[0];
  }
  if (split.length > 1 && int.tryParse(split[1]) != null) {
    minor = split[1];
  }
  if (split.length > 2 && int.tryParse(split[2].replaceAll(RegExp('[^0-9]'), '')) != null) {
    patch = split[2].replaceAll(RegExp('[^0-9]'), '');
  }
  return Version(major: int.parse(major), minor: int.parse(minor), patch: int.parse(patch));
}

Color getTextColor(Color color) {
  // Counting the perceptive luminance - human eye favors green color...
  double luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;

  if (luminance > 0.7) {
    return Typography.material2021().black.labelLarge!.color!;
  } else {
    return Typography.material2021().white.labelLarge!.color!;
  }
}

Future<void> setupSystemColor(BuildContext context) async {
  final SystemUiOverlayStyle dark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent /*Android=23*/,
    statusBarBrightness: Brightness.light /*iOS*/,
    statusBarIconBrightness: Brightness.dark /*Android=23*/,
    systemStatusBarContrastEnforced: false /*Android=29*/,
    systemNavigationBarColor: Colors.transparent /*Android=27*/,
    systemNavigationBarDividerColor: Colors.transparent.withAlpha(1) /*Android=28,不能用全透明 */,
    systemNavigationBarIconBrightness: Brightness.dark /*Android=27*/,
    systemNavigationBarContrastEnforced: false /*Android=29*/,
  );
  final SystemUiOverlayStyle light = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    // 23
    statusBarIconBrightness: Brightness.dark,
    // 23
    systemNavigationBarColor: Colors.transparent,
    // 27
    systemStatusBarContrastEnforced: false /*Android=29*/,
    systemNavigationBarDividerColor: Colors.transparent.withAlpha(1) /* 不能用全透明 */,
    // 28
    systemNavigationBarIconBrightness: Brightness.dark,
    // 27
    systemNavigationBarContrastEnforced: false, // 29
  );
  if (Theme.of(context).colorScheme.brightness == Brightness.light) {
    SystemChrome.setSystemUIOverlayStyle(light);
  } else {
    SystemChrome.setSystemUIOverlayStyle(dark);
  }
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

String getOutboundUtm() {
  String utm = "?utm_medium=Tail_App";
  if (platform.isAndroid) {
    utm = "$utm?utm_source=tailappandr";
  } else if (platform.isIOS) {
    utm = "$utm?utm_source=tailappios";
  }
  return utm;
}
