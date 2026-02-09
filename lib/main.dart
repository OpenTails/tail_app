import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/version.dart';

import 'Backend/Definitions/Action/base_action.dart';
import 'Backend/Definitions/Device/device_definition.dart';
import 'Backend/app_shortcuts.dart';
import 'Backend/dynamic_config.dart';
import 'Backend/favorite_actions.dart';
import 'Backend/logging_wrappers.dart';
import 'Backend/move_lists.dart';
import 'Backend/sensors.dart';
import 'Backend/wear_bridge.dart';
import 'Frontend/Widgets/bt_app_state_controller.dart';
import 'Frontend/go_router_config.dart';
import 'Frontend/translation_string_definitions.dart';
import 'Frontend/utils.dart';
import 'constants.dart';
import 'l10n/app_localizations.dart';

FutureOr<SentryEvent?> beforeSend(SentryEvent event, Hint hint) async {
  DynamicConfigInfo dynamicConfigInfo = await getDynamicConfigInfo();

  bool reportingEnabled = HiveProxy.getOrDefault(settings, "allowErrorReporting", defaultValue: true) && dynamicConfigInfo.featureFlags.enableErrorReporting;
  if (reportingEnabled) {
    if (kDebugMode) {
      print('Before sending sentry event');
    }
    return event;
  } else {
    return null;
  }
}

final mainLogger = Logger('Main');

Future<String> getSentryEnvironment() async {
  if (!kReleaseMode) {
    return 'debug';
  }
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  String referral = packageInfo.installerStore ?? "";
  if (Platform.isIOS) {
    if (referral == "com.apple.testflight") {
      return 'staging';
    }
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    if (!iosInfo.isPhysicalDevice) {
      return 'debug';
    }
  }

  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    if (!androidInfo.isPhysicalDevice) {
      return 'debug';
    }
    //final bool isRunningInTestlab = await FirebaseTestlabDetector.isAppRunningInTestlab() ?? false;
    //if (isRunningInTestlab) {
    //  return 'staging';
    //}
  }
  return 'production';
}

Future<void> initMainApp() async {
  //initialize the foreground service library
  if (Platform.isAndroid) {
    FlutterForegroundTask.initCommunicationPort();
  }
  await startSentryApp(TailApp());
}

Future<void> startSentryApp(Widget child) async {
  if (const String.fromEnvironment('SENTRY_DSN', defaultValue: "").isEmpty) {
    runApp(child);
  }
  mainLogger.fine("Init Sentry");
  String environment = await getSentryEnvironment();
  DynamicConfigInfo dynamicConfigInfo = await getDynamicConfigInfo();
  mainLogger.info("Detected Environment: $environment");

  await SentryFlutter.init(
    (options) async {
      options
        ..dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: "")
        ..addIntegration(LoggingIntegration())
        ..enableBreadcrumbTrackingForCurrentPlatform()
        ..debug = kDebugMode
        ..diagnosticLevel = SentryLevel.info
        ..environment = environment
        ..tracesSampleRate = kDebugMode ? 1 : dynamicConfigInfo.sentryConfig.tracesSampleRate
        ..profilesSampleRate = kDebugMode ? 1 : dynamicConfigInfo.sentryConfig.profilesSampleRate
        ..beforeSend = beforeSend
        ..reportPackages = false
        ..attachScreenshot = true
        ..privacy.maskAllImages = false
        ..privacy.maskAllText =
            false // app does not contain any PII
        ..screenshotQuality = SentryScreenshotQuality.low
        ..replay.sessionSampleRate = dynamicConfigInfo.sentryConfig.replaySessionSampleRate
        ..replay.onErrorSampleRate = dynamicConfigInfo.sentryConfig.replayOnErrorSampleRate;
    },
    // Init your App.
    // ignore: missing_provider_scope
    appRunner: () => runApp(SentryScreenshotWidget(child: TailApp())),
  );
}

Future<void> main() async {
  Logger.root.level = Level.ALL;
  mainLogger.info("Begin");
  Logger.root.onRecord.listen((event) {
    try {
      // Hive may not be ready yet. just log in that case
      if (!HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) {
        return;
      }
      // ignore: empty_catches
    } catch (ignored) {}
    if (["GoRouter", "Dio"].contains(event.loggerName)) {
      return;
    }
    if (event.level.value < 1000 && event.stackTrace == null) {
      logarte.info(event.message, source: event.loggerName);
    } else {
      logarte.error(event.message, stackTrace: event.stackTrace);
    }
  });

  initFlutter();
  await initHive();
  initMainApp();
}

void initFlutter() {
  WidgetsBinding widgetsBinding = SentryWidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding); // keeps the splash screen visible
}

Future<void> initHive() async {
  mainLogger.fine("Init Hive");

  final Directory appDir = await getApplicationSupportDirectory();
  Hive.init(appDir.path);

  //Hive Type ID 1
  if (!Hive.isAdapterRegistered(BaseStoredDeviceAdapter().typeId)) {
    Hive.registerAdapter(BaseStoredDeviceAdapter());
  }
  //Hive Type ID 2
  if (!Hive.isAdapterRegistered(TriggerAdapter().typeId)) {
    Hive.registerAdapter(TriggerAdapter());
  }
  //Hive Type ID 3
  if (!Hive.isAdapterRegistered(MoveListAdapter().typeId)) {
    Hive.registerAdapter(MoveListAdapter());
  }
  //Hive Type ID 5
  if (!Hive.isAdapterRegistered(MoveAdapter().typeId)) {
    Hive.registerAdapter(MoveAdapter());
  }
  //Hive Type ID 6
  if (!Hive.isAdapterRegistered(DeviceTypeAdapter().typeId)) {
    Hive.registerAdapter(DeviceTypeAdapter());
  }
  //Hive Type ID 7
  if (!Hive.isAdapterRegistered(ActionCategoryAdapter().typeId)) {
    Hive.registerAdapter(ActionCategoryAdapter());
  }
  //Hive Type ID 8
  if (!Hive.isAdapterRegistered(TriggerActionAdapter().typeId)) {
    Hive.registerAdapter(TriggerActionAdapter());
  }
  //Hive Type ID 10
  if (!Hive.isAdapterRegistered(EasingTypeAdapter().typeId)) {
    Hive.registerAdapter(EasingTypeAdapter());
  }
  //Hive Type ID 11
  if (!Hive.isAdapterRegistered(MoveTypeAdapter().typeId)) {
    Hive.registerAdapter(MoveTypeAdapter());
  }
  //Hive Type ID 12
  if (!Hive.isAdapterRegistered(AudioActionAdapter().typeId)) {
    Hive.registerAdapter(AudioActionAdapter());
  }
  //Hive Type ID 13
  if (!Hive.isAdapterRegistered(FavoriteActionAdapter().typeId)) {
    Hive.registerAdapter(FavoriteActionAdapter());
  }
  //Hive Type ID 14
  if (!Hive.isAdapterRegistered(EarSpeedAdapter().typeId)) {
    Hive.registerAdapter(EarSpeedAdapter());
  }
  //Hive Type ID 15
  if (!Hive.isAdapterRegistered(GlowtipStatusAdapter().typeId)) {
    Hive.registerAdapter(GlowtipStatusAdapter());
  }
  //Hive Type ID 16
  if (!Hive.isAdapterRegistered(RGBStatusAdapter().typeId)) {
    Hive.registerAdapter(RGBStatusAdapter());
  }
  //Hive Type ID 17
  if (!Hive.isAdapterRegistered(VersionAdapter().typeId)) {
    Hive.registerAdapter(VersionAdapter());
  }
  await Hive.openBox(settings); // Do not set type here
  await Hive.openBox<Trigger>(triggerBox);
  await Hive.openBox<FavoriteAction>(favoriteActionsBox);
  await Hive.openBox<AudioAction>(audioActionsBox);
  await Hive.openBox<MoveList>(sequencesBox);
  await Hive.openBox<BaseStoredDevice>(devicesBox);
}

class TailApp extends ConsumerWidget {
  const TailApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Platform messages may fail, so we use a try/catch PlatformException.
    mainLogger.info('Starting app');
    launchAppAnalytics();

    if (kDebugMode) {
      mainLogger.info('Debug Mode Enabled');
      HiveProxy
        ..put(settings, showDebugging, true)
        //..put(settings, allowAnalytics, false)
        ..put(settings, showDemoGear, true);
    }

    return WithForegroundTask(
      child: ProviderScope(
        retry: (retryCount, error) => null, // disables retry on riverpod
        observers: [RiverpodProviderObserver()],
        child: _EagerInitialization(
          child: BtAppStateController(
            child: ValueListenableBuilder(
              valueListenable: Hive.box(settings).listenable(keys: [appColor, uwuTextEnabled, selectedLocale]),
              builder: (BuildContext context, value, Widget? child) {
                rebuildAllChildren(context);
                return TailAppMainWidget();
              },
            ),
          ),
        ),
      ),
    );
  }

  //https://stackoverflow.com/questions/43778488/how-to-force-flutter-to-rebuild-redraw-all-widgets
  void rebuildAllChildren(BuildContext context) {
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }
}

class TailAppMainWidget extends ConsumerWidget {
  const TailAppMainWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    setupSystemColor(context);
    ref.watch(initLocaleProvider);
    Future(FlutterNativeSplash.remove); //remove the splash screen one frame later
    Color color = Color(HiveProxy.getOrDefault(settings, appColor, defaultValue: appColorDefault));
    return MaterialApp.router(
      title: title(),
      color: color,
      theme: buildTheme(Brightness.light, color),
      darkTheme: buildTheme(Brightness.dark, color),
      routerConfig: router,
      localizationsDelegates: [LocaleNamesLocalizationsDelegate(), ...AppLocalizations.localizationsDelegates],
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}

ThemeData buildTheme(Brightness brightness, Color color) {
  if (brightness == Brightness.light) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(brightness: Brightness.light, seedColor: color, primary: color),
      appBarTheme: const AppBarTheme(elevation: 2),
      // We use the nicer Material-3 Typography in both M2 and M3 mode.
      typography: Typography.material2021(),
      filledButtonTheme: FilledButtonThemeData(style: ElevatedButton.styleFrom(foregroundColor: getTextColor(color))),
    );
  } else {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(brightness: Brightness.dark, seedColor: color, primary: color),
      appBarTheme: const AppBarTheme(elevation: 2),
      // We use the nicer Material-3 Typography in both M2 and M3 mode.
      typography: Typography.material2021(),
      filledButtonTheme: FilledButtonThemeData(style: ElevatedButton.styleFrom(foregroundColor: getTextColor(color), elevation: 1)),
    );
  }
}

final class RiverpodProviderObserver extends ProviderObserver {
  final Logger riverpodLogger = Logger('Riverpod');

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    riverpodLogger.info('Provider ${context.provider} was initialized with $value');
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    riverpodLogger.info('Provider ${context.provider} was disposed');
  }

  @override
  void didUpdateProvider(ProviderObserverContext context, Object? previousValue, Object? newValue) {
    riverpodLogger.info('Provider ${context.provider} updated from $previousValue to $newValue');
  }

  @override
  void providerDidFail(ProviderObserverContext context, Object error, StackTrace stackTrace) {
    if (error is ProviderException) {
      // The provider didn't fail directly, but instead depends on a failed provider.
      // The error was therefore already logged.
      return;
    }
    riverpodLogger.warning('Provider ${context.provider} threw $error at $stackTrace', error, stackTrace);
  }
}

class _EagerInitialization extends ConsumerWidget {
  const _EagerInitialization({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize providers by watching them.
    // By using "watch", the provider will stay alive and not be disposed.
    ref.watch(moveListsProvider);
    ref.watch(appShortcutsProvider);
    initWear();
    return child;
  }
}
