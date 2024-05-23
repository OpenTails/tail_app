import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:feedback_sentry/feedback_sentry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:logging/logging.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:plausible_analytics/plausible_analytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/action_registry.dart';
import 'package:tail_app/Backend/appShortcuts.dart';
import 'package:tail_app/Frontend/Widgets/bt_app_state_controller.dart';

import 'Backend/Definitions/Action/base_action.dart';
import 'Backend/background_update.dart';
import 'Backend/move_lists.dart';
import 'Backend/notifications.dart';
import 'Backend/plausible_dio.dart';
import 'Backend/sensors.dart';
import 'Frontend/go_router_config.dart';
import 'Frontend/intn_defs.dart';
import 'constants.dart';

//late SharedPreferences prefs;

FutureOr<SentryEvent?> beforeSend(SentryEvent event, Hint hint) async {
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

const String serverUrl = "https://plausible.codel1417.xyz";
const String domain = "tail-app";

late final Plausible plausible;
final mainLogger = Logger('Main');

Future<void> main() async {
  Logger.root.level = Level.ALL;
  mainLogger.info("Begin");
  initFlogger();
  initFlutter();
  initNotifications();
  initBackgroundTasks();
  //var localeLoaded = await initializeMessages('ace');
  //Intl.defaultLocale = 'ace';
  //Flogger.i("Loaded local: $localeLoaded");
  mainLogger.fine("Init Hive");
  await initHive();
  //initDio();
  mainLogger.fine("Init Sentry");
  await SentryFlutter.init(
    (options) async {
      options.dsn = 'https://a2d00e5fef5103984087f0ee8c39b3b0@sentry.codel1417.xyz/2';
      options.addIntegration(LoggingIntegration());
      options.attachScreenshot = true; //not supported on GlitchTip
      options.tracesSampleRate = 0.5;
      //options.profilesSampleRate = 1.0;
      options.enableBreadcrumbTrackingForCurrentPlatform();
      options.attachThreads = true;
      options.anrEnabled = true;
      options.beforeSend = beforeSend;
      options.enableMetrics = true;
      options.diagnosticLevel = SentryLevel.debug;
      //options.platformChecker = CustomSentryPlatformChecker();
      //options.httpClient = SentryDioClient(); // This doesn't do much :/. Sentry flutter uses native to send data
    },
    // Init your App.
    // ignore: missing_provider_scope
    appRunner: () => runApp(
      DefaultAssetBundle(
        bundle: SentryAssetBundle(),
        child: SentryScreenshotWidget(
          child: TailApp(),
        ),
      ),
    ),
  );
}

void initFlogger() {
  Flogger.init(config: const FloggerConfig(showDebugLogs: true, printClassName: true, printMethodName: true, showDateTime: false));
  Flogger.registerListener(
    (record) {
      LogConsole.add(OutputEvent(record.level, [record.printable()]), bufferSize: 1000);
      //log(record.printable(), stackTrace: record.stackTrace);
    },
  );
}

void initFlutter() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  widgetsBinding.addObserver(WidgetBindingLogger());
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding); // keeps the splash screen visible
}

class WidgetBindingLogger extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    mainLogger.info("didChangeAppLifecycleState: $state");
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    mainLogger.info("didRequestAppExit");
    return super.didRequestAppExit();
  }
}

Future<void> initHive() async {
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
    )
    ..registerAdapter(FavoriteActionAdapter());
  await SentryHive.openBox(settings); // Do not set type here
  await SentryHive.openBox<Trigger>(triggerBox);
  await SentryHive.openBox<FavoriteAction>(favoriteActionsBox);
  await SentryHive.openBox<MoveList>('sequences');
  await SentryHive.openBox<BaseStoredDevice>('devices');
  await SentryHive.openBox('notificationsStuff');
}

class TailApp extends StatefulWidget {
  TailApp({super.key}) {
    //Init Plausible
    // Platform messages may fail, so we use a try/catch PlatformException.
    plausible = PlausibleDio(serverUrl, domain);
    plausible.enabled = true;
    mainLogger.info('Starting app');
    if (kDebugMode) {
      mainLogger.info('Debug Mode Enabled');
      SentryHive.box(settings).put(showDebugging, true);
      SentryHive.box(settings).put(allowAnalytics, false);
      SentryHive.box(settings).put(allowErrorReporting, false);
    }
  }

  @override
  State<TailApp> createState() => _TailAppState();
}

class _TailAppState extends State<TailApp> {
  @override
  void initState() {
    // Only after at least the action method is set, the notification events are delivered
    AwesomeNotifications().setListeners(
        onActionReceivedMethod: NotificationController.onActionReceivedMethod,
        onNotificationCreatedMethod: NotificationController.onNotificationCreatedMethod,
        onNotificationDisplayedMethod: NotificationController.onNotificationDisplayedMethod,
        onDismissActionReceivedMethod: NotificationController.onDismissActionReceivedMethod);

    super.initState();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      observers: [
        RiverpodProviderObserver(),
      ],
      child: _EagerInitialization(
        child: BtAppStateController(
            child: BetterFeedback(
          themeMode: ThemeMode.system,
          darkTheme: FeedbackThemeData.dark(),
          child: ValueListenableBuilder(
            valueListenable: SentryHive.box(settings).listenable(keys: [appColor]),
            builder: (BuildContext context, value, Widget? child) {
              Future(() => FlutterNativeSplash.remove()); //remove the splash screen one frame later
              return MaterialApp.router(
                title: title(),
                color: Color(SentryHive.box(settings).get(appColor, defaultValue: appColorDefault)),
                theme: buildTheme(Brightness.light, Color(SentryHive.box(settings).get(appColor, defaultValue: appColorDefault))),
                darkTheme: buildTheme(Brightness.dark, Color(SentryHive.box(settings).get(appColor, defaultValue: appColorDefault))),
                routerConfig: router,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                themeMode: ThemeMode.system,
                debugShowCheckedModeBanner: false,
              );
            },
          ),
        )),
      ),
    );
  }
}

ThemeData buildTheme(Brightness brightness, Color color) {
  if (brightness == Brightness.light) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.light,
        seedColor: color,
        primary: color,
      ),
      appBarTheme: const AppBarTheme(elevation: 2),
      // We use the nicer Material-3 Typography in both M2 and M3 mode.
      typography: Typography.material2021(platform: defaultTargetPlatform),
    );
  } else {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: color,
        primary: color,
      ),
      appBarTheme: const AppBarTheme(elevation: 2),
      // We use the nicer Material-3 Typography in both M2 and M3 mode.
      typography: Typography.material2021(platform: defaultTargetPlatform),
    );
  }
}

class RiverpodProviderObserver extends ProviderObserver {
  final Logger riverpodLogger = Logger('Riverpod');

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    riverpodLogger.info('Provider $provider was initialized with $value');
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    riverpodLogger.info('Provider $provider was disposed');
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    riverpodLogger.info('Provider $provider updated from $previousValue to $newValue');
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    riverpodLogger.warning('Provider $provider threw $error at $stackTrace', error, stackTrace);
  }
}

class _EagerInitialization extends ConsumerWidget {
  const _EagerInitialization({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize providers by watching them.
    // By using "watch", the provider will stay alive and not be disposed.
    //ref.watch(knownDevicesProvider);
    //ref.watch(triggerListProvider);
    //ref.watch(moveListsProvider);
    //ref.watch(favoriteActionsProvider);
    ref.watch(appShortcutsProvider);
    return child;
  }
}
