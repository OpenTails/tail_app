import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:data_saver/data_saver.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:intl/intl.dart';
import 'package:logarte/logarte.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wordpress_client/wordpress_client.dart';

import '../Backend/logging_wrappers.dart';
import '../Backend/version.dart';
import '../constants.dart';
import '../l10n/app_localizations.dart';
import '../l10n/messages_all_locales.dart';

part 'utils.g.dart';

enum BluetoothPermissionStatus {
  granted,
  denied,
  unknown,
}

@riverpod
Future<BluetoothPermissionStatus> getBluetoothPermission(Ref ref) async {
  BluetoothPermissionStatus status = BluetoothPermissionStatus.unknown;
  if (kIsWeb) {
    return BluetoothPermissionStatus.granted;
  }
  if (Platform.isAndroid && (await DeviceInfoPlugin().androidInfo).version.sdkInt > 30) {
    PermissionStatus permissionStatusScan = await Permission.bluetoothScan.request();
    //logger.info("permissionStatusScan $permissionStatusScan");
    status = PermissionStatus.granted == permissionStatusScan ? BluetoothPermissionStatus.granted : BluetoothPermissionStatus.denied;

    PermissionStatus permissionStatusConnect = await Permission.bluetoothConnect.request();
    //logger.info("permissionStatusConnect $permissionStatusConnect");
    status = status == BluetoothPermissionStatus.granted && PermissionStatus.granted == permissionStatusConnect ? BluetoothPermissionStatus.granted : BluetoothPermissionStatus.denied;
  } else if (Platform.isAndroid) {
    PermissionStatus permissionStatusLocation = await Permission.location.request();
    //logger.info("permissionStatusLocation $permissionStatusLocation");
    status = PermissionStatus.granted == permissionStatusLocation ? BluetoothPermissionStatus.granted : BluetoothPermissionStatus.denied;

    PermissionStatus permissionStatusLocationInUse = await Permission.locationWhenInUse.request();
    //logger.info("permissionStatusLocationInUse $permissionStatusLocationInUse");
    status = status == BluetoothPermissionStatus.granted && PermissionStatus.granted == permissionStatusLocationInUse ? BluetoothPermissionStatus.granted : BluetoothPermissionStatus.denied;
  } else {
    PermissionStatus permissionStatusBluetooth = await Permission.bluetooth.request();
    //logger.info("permissionStatusBluetooth $permissionStatusBluetooth");
    status = PermissionStatus.granted == permissionStatusBluetooth ? BluetoothPermissionStatus.granted : BluetoothPermissionStatus.denied;
  }
  return status;
}

@Riverpod(keepAlive: true)
Future<String> initLocale(Ref ref) async {
  final String defaultLocale = kIsWeb ? "EN" : Platform.localeName; // Returns locale string in the form 'en_US'

  String locale = AppLocalizations.supportedLocales
          .where(
            (element) => element.toLanguageTag() == HiveProxy.getOrDefault(settings, selectedLocale, defaultValue: ""),
          )
          .map(
            (e) => e.toLanguageTag(),
          )
          .firstOrNull ??
      defaultLocale;

  await initializeMessages(locale);
  Intl.defaultLocale = locale;
  return locale;
}

final dioLogger = Logger('Dio');

Dio? _dio;
final cacheOptions = CacheOptions(
  // A default store is required for interceptor.
  store: HiveCacheStore(
    null,
    hiveBoxName: "dioCache",
  ),
  hitCacheOnErrorCodes: const [500],

  hitCacheOnNetworkFailure: true,
  maxStale: const Duration(days: 7),
);

Future<Dio> initDio({skipSentry = false}) async {
  if (_dio != null) {
    return _dio!;
  }
  final Dio dio = Dio()
/*     ..interceptors.add(
      LogInterceptor(
        requestBody: false,
        requestHeader: false,
        responseBody: false,
        responseHeader: false,
        request: true,
        logPrint: (o) => dioLogger.finer(o.toString()),
      ),
    ) */
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

  // Global options

  dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));
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
  Dio dio = await initDio();
  return WordpressClient.fromDioInstance(baseUrl: Uri.parse('https://thetailcompany.com/wp-json/wp/v2'), instance: dio);
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
  // Does not work with r/g/b double values
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

Future<bool> isLimitedDataEnvironment() async {
  final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult.contains(ConnectivityResult.none)) {
    return true;
  }
  final DataSaverMode mode = await DataSaver().checkMode();
  bool isMobile = connectivityResult.contains(ConnectivityResult.mobile);

  if (mode == DataSaverMode.enabled && isMobile) {
    return true;
  }

  if (HiveProxy.getOrDefault(settings, tailBlogWifiOnly, defaultValue: tailBlogWifiOnlyDefault) && isMobile) {
    return true;
  }
  return false;
}
