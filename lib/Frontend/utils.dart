import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:data_saver/data_saver.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:logarte/logarte.dart';
import 'package:logging/logging.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:universal_io/io.dart';
import 'package:wordpress_client/wordpress_client.dart' hide Theme;

import '../Backend/logging_wrappers.dart';
import '../constants.dart';

final dioLogger = Logger('Dio');

bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
Dio? _dio;
final cacheOptions = CacheOptions(
  // A default store is required for interceptor.
  store: HiveCacheStore(null, hiveBoxName: "dioCache"),
  hitCacheOnErrorCodes: const [500],

  hitCacheOnNetworkFailure: true,
  maxStale: const Duration(days: 7),
);

Future<Dio> initDio() async {
  if (_dio != null) {
    return _dio!;
  }

  final Dio dio = Dio()..interceptors.add(LogarteDioInterceptor(logarte));
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
  dio.addSentry();
  _dio = dio;
  return dio;
}

WordpressClient? _wordpressClient;

Future<WordpressClient> getWordpressClient() async {
  if (_wordpressClient != null) {
    return _wordpressClient!;
  }
  Dio dio = await initDio();
  return WordpressClient.fromDioInstance(
    baseUrl: Uri.parse('https://thetailcompany.com/wp-json/wp/v2'),
    instance: dio,
  );
}

Future<bool> isLimitedDataEnvironment() async {
  if (!isMobile) {
    return false;
  }
  final List<ConnectivityResult> connectivityResult = await (Connectivity()
      .checkConnectivity());
  if (connectivityResult.contains(ConnectivityResult.none)) {
    return true;
  }
  final DataSaverMode mode = await DataSaver().checkMode();
  bool isMobileData = connectivityResult.contains(ConnectivityResult.mobile);

  if (mode == DataSaverMode.enabled && isMobileData) {
    return true;
  }

  if (HiveProxy.getOrDefault(
        settings,
        tailBlogWifiOnly,
        defaultValue: tailBlogWifiOnlyDefault,
      ) &&
      isMobileData) {
    return true;
  }
  return false;
}
