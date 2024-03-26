import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:feedback_sentry/feedback_sentry.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:plausible_analytics/plausible_analytics.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

import 'Backend/Definitions/Action/BaseAction.dart';
import 'Backend/PlausibleDio.dart';
import 'Backend/Sensors.dart';
import 'Backend/moveLists.dart';
import 'Frontend/GoRouterConfig.dart';
import 'Frontend/intnDefs.dart';
import 'constants.dart';

//late SharedPreferences prefs;

FutureOr<SentryEvent?> beforeSend(SentryEvent event, {Hint? hint}) async {
  bool reportingEnabled = SentryHive.box(settings).get("allowErrorReporting", defaultValue: true);
  if (reportingEnabled) {
    if (kDebugMode) {
      print('Before sending sentry event');
    }
    return event;
  } else {
    return null;
  }
}

const String serverUrl = "https://plausable.codel1417.xyz";
const String domain = "tail-app";

late final Plausible plausible;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Flogger.init(config: const FloggerConfig(showDebugLogs: true, printClassName: true, printMethodName: true, showDateTime: false));
  PlatformDispatcher.instance.onError = (error, stack) {
    Flogger.e(error.toString(), stackTrace: stack);
    return true;
  };

  if (kDebugMode) {
    Flogger.registerListener(
      (record) {
        LogConsole.add(OutputEvent(record.level, [record.printable()]), bufferSize: 10000);
        log(record.printable(), stackTrace: record.stackTrace);
      },
    );
  }

  //var localeLoaded = await initializeMessages('ace');
  //Intl.defaultLocale = 'ace';
  //Flogger.i("Loaded local: $localeLoaded");
  final Directory appDir = await getApplicationSupportDirectory();
  SentryHive
    ..init(appDir.path)
    ..registerAdapter(BaseStoredDeviceAdapter())
    ..registerAdapter(MoveListAdapter())
    ..registerAdapter(MoveAdapter())
    ..registerAdapter(BaseActionAdapter())
    ..registerAdapter(TriggerAdapter())
    ..registerAdapter(TriggerActionAdapter())
    ..registerAdapter(ActionCategoryAdapter())
    ..registerAdapter(DeviceTypeAdapter())
    ..registerAdapter(MoveTypeAdapter())
    ..registerAdapter(EasingTypeAdapter())
    ..registerAdapter(
      AutoActionCategoryAdapter(),
    );
  await SentryHive.openBox(settings);
  await SentryHive.openBox<Trigger>('triggers');
  await SentryHive.openBox<MoveList>('sequences');
  await SentryHive.openBox<BaseStoredDevice>('devices');
  initDio();
  FlutterAppBadger.removeBadge();
  await SentryFlutter.init(
    (options) async {
      options.dsn = 'https://284f1830184d74dbbbb48ad14b577ffc@sentry.codel1417.xyz/3';
      options.addIntegration(LoggingIntegration());
      options.attachScreenshot = true; //not supported on GlitchTip
      options.attachViewHierarchy = true; //not supported on GlitchTip
      options.tracesSampleRate = 1.0;
      //options.profilesSampleRate = 1.0;
      options.enableBreadcrumbTrackingForCurrentPlatform();
      options.attachThreads = true;
      options.anrEnabled = true;
      options.beforeSend = beforeSend;
    },
    // Init your App.
    appRunner: () => runApp(
      DefaultAssetBundle(
        bundle: SentryAssetBundle(),
        child: SentryUserInteractionWidget(
          child: SentryScreenshotWidget(
            child: ProviderScope(
              observers: [
                if (kDebugMode) ...[RiverpodProviderObserver()],
              ],
              child: TailApp(),
            ),
          ),
        ),
      ),
    ),
  );
}

Dio initDio() {
  final Dio dio = Dio();
  dio.httpClientAdapter = NativeAdapter();
  dio.interceptors.add(
    RetryInterceptor(
      dio: dio,
      logPrint: Flogger.d, // specify log function (optional)
      retries: 3, // retry count (optional)
      retryDelays: const [
        // set delays between retries (optional)
        Duration(seconds: 10), // wait 1 sec before first retry
        Duration(seconds: 30), // wait 2 sec before second retry
        Duration(seconds: 60), // wait 3 sec before third retry
      ],
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      PrettyDioLogger(
        requestBody: true,
        compact: true,
      ),
    );
  }

  /// This *must* be the last initialization step of the Dio setup, otherwise
  /// your configuration of Dio might overwrite the Sentry configuration.

  dio.addSentry(failedRequestStatusCodes: []);
  return dio;
}

class TailApp extends ConsumerWidget {
  TailApp({super.key}) {
    //Init Plausible
    // Platform messages may fail, so we use a try/catch PlatformException.
    plausible = PlausibleDio(serverUrl, domain);
    plausible.enabled = true;
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Flogger.i('Starting app');
    return BetterFeedback(
      themeMode: ThemeMode.system,
      darkTheme: FeedbackThemeData.dark(),
      child: ValueListenableBuilder(
        valueListenable: SentryHive.box(settings).listenable(keys: [appColor]),
        builder: (BuildContext context, value, Widget? child) {
          return MaterialApp.router(
            title: subTitle(),
            color: Color(SentryHive.box(settings).get(appColor, defaultValue: appColorDefault)),
            theme: BuildTheme(Brightness.light, Color(SentryHive.box(settings).get(appColor, defaultValue: appColorDefault))),
            darkTheme: BuildTheme(Brightness.dark, Color(SentryHive.box(settings).get(appColor, defaultValue: appColorDefault))),
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            themeMode: ThemeMode.system,
          );
        },
      ),
    );
  }
}

ThemeData BuildTheme(Brightness brightness, Color color) {
  if (brightness == Brightness.light) {
    return FlexThemeData.light(
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.light,
        seedColor: color,
        primary: color,
      ),
      // Use very subtly themed app bar elevation in light mode.
      appBarElevation: 0.5,
      useMaterial3: true,
      // We use the nicer Material-3 Typography in both M2 and M3 mode.
      typography: Typography.material2021(platform: defaultTargetPlatform),
    );
  } else {
    return FlexThemeData.dark(
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: color,
        primary: color,
      ),
      // Use a bit more themed elevated app bar in dark mode.
      appBarElevation: 2,
      useMaterial3: true,
      // We use the nicer Material-3 Typography in both M2 and M3 mode.
      typography: Typography.material2021(platform: defaultTargetPlatform),
    );
  }
}

class RiverpodProviderObserver extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    Flogger.d('Provider $provider was initialized with $value');
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    Flogger.d('Provider $provider was disposed');
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    Flogger.d('Provider $provider updated from $previousValue to $newValue');
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    Flogger.e('Provider $provider threw $error at $stackTrace', stackTrace: stackTrace);
  }
}
