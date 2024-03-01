import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:feedback_sentry/feedback_sentry.dart';
import 'package:fk_user_agent/fk_user_agent.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:plausible_analytics/plausible_analytics.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

import 'Backend/Bluetooth/BluetoothManager.dart';
import 'Backend/Definitions/Action/BaseAction.dart';
import 'Backend/Sensors.dart';
import 'Backend/moveLists.dart';
import 'Frontend/GoRouterConfig.dart';
import 'Frontend/intnDefs.dart';

//late SharedPreferences prefs;

FutureOr<SentryEvent?> beforeSend(SentryEvent event, {Hint? hint}) async {
  bool reportingEnabled = SentryHive.box('settings').get("allowErrorReporting", defaultValue: true);
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

final Plausible plausible = Plausible(serverUrl, domain);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FkUserAgent.init();
  // Platform messages may fail, so we use a try/catch PlatformException.
  try {
    String platformVersion = FkUserAgent.userAgent!;
    plausible.userAgent = platformVersion;
  } on PlatformException {}
  plausible.enabled = true;
  Flogger.init(config: const FloggerConfig(showDebugLogs: true, printClassName: true, printMethodName: true, showDateTime: false));
  PlatformDispatcher.instance.onError = (error, stack) {
    Flogger.e(error.toString(), stackTrace: stack);
    return true;
  };
  Flogger.registerListener(
    (record) {
      LogConsole.add(OutputEvent(record.level, [record.printable()]), bufferSize: 100000);
      if (kDebugMode) {
        log(record.printable(), stackTrace: record.stackTrace);
      }
    },
  );
  //var localeLoaded = await initializeMessages('ace');
  //Intl.defaultLocale = 'ace';
  //Flogger.i("Loaded local: $localeLoaded");
  final appDir = await getApplicationSupportDirectory();
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
    ..registerAdapter(SpeedAdapter())
    ..registerAdapter(MoveTypeAdapter())
    ..registerAdapter(EasingTypeAdapter())
    ..registerAdapter(
      AutoActionCategoryAdapter(),
    );
  await SentryHive.openBox('settings');
  await SentryHive.openBox<Trigger>('triggers');
  await SentryHive.openBox<MoveList>('sequences');
  await SentryHive.openBox<BaseStoredDevice>('devices');
  initDio();
  await SentryFlutter.init(
    (options) async {
      options.dsn = 'https://284f1830184d74dbbbb48ad14b577ffc@sentry.codel1417.xyz/3';
      options.addIntegration(LoggingIntegration());
      options.attachScreenshot = true; //not supported on GlitchTip
      options.attachViewHierarchy = true; //not supported on GlitchTip
      options.tracesSampleRate = 1.0;
      options.profilesSampleRate = 1.0;
      options.attachThreads = true;
      options.enableUserInteractionTracing = true;
      options.reportSilentFlutterErrors = true;
      options.enableAutoNativeBreadcrumbs = true;
      options.enableAutoPerformanceTracing = true;
      options.enableAppHangTracking = true;
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
                RiverpodProviderObserver(),
              ],
              child: const _EagerInitialization(
                child: TailApp(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Dio initDio() {
  final dio = Dio();

  /// This *must* be the last initialization step of the Dio setup, otherwise
  /// your configuration of Dio might overwrite the Sentry configuration.
  dio.addSentry();
  return dio;
}

class TailApp extends ConsumerWidget {
  const TailApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Flogger.i('Starting app');
    return BetterFeedback(
      themeMode: ThemeMode.system,
      darkTheme: FeedbackThemeData.dark(),
      child: ValueListenableBuilder(
        valueListenable: SentryHive.box('settings').listenable(keys: ["appColor"]),
        builder: (BuildContext context, value, Widget? child) {
          return MaterialApp.router(
            title: subTitle(),
            color: Color(SentryHive.box('settings').get('appColor', defaultValue: Colors.orange.value)),
            theme: BuildTheme(Brightness.light, Color(SentryHive.box('settings').get('appColor', defaultValue: Colors.orange.value))),
            darkTheme: BuildTheme(Brightness.dark, Color(SentryHive.box('settings').get('appColor', defaultValue: Colors.orange.value))),
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              //GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'), // English
              Locale('ace'), // UwU
            ],
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
      fontFamily: GoogleFonts.notoSans().fontFamily,
      // We use the nicer Material-3 Typography in both M2 and M3 mode.
      typography: Typography.material2021(platform: defaultTargetPlatform),
    );
  } else {
    return FlexThemeData.dark(
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: Color(
          SentryHive.box('settings').get('appColor', defaultValue: Colors.orange.value),
        ),
        primary: Color(
          SentryHive.box('settings').get('appColor', defaultValue: Colors.orange.value),
        ),
      ),
      // Use a bit more themed elevated app bar in dark mode.
      appBarElevation: 2,
      useMaterial3: true,
      fontFamily: GoogleFonts.notoSans().fontFamily,
      // We use the nicer Material-3 Typography in both M2 and M3 mode.
      typography: Typography.material2021(platform: defaultTargetPlatform),
    );
  }
}

class _EagerInitialization extends ConsumerWidget {
  const _EagerInitialization({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize providers by watching them.
    // By using "watch", the provider will stay alive and not be disposed.
    ref.watch(reactiveBLEProvider);
    ref.watch(knownDevicesProvider);
    ref.watch(btConnectStateHandlerProvider);
    ref.watch(triggerListProvider);
    ref.watch(moveListsProvider);
    return child;
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
