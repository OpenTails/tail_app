import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:feedback_sentry/feedback_sentry.dart';
import 'package:firebase_testlab_detector/firebase_testlab_detector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:install_referrer/install_referrer.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:sentry_logging/sentry_logging.dart';

import 'Backend/Definitions/Action/base_action.dart';
import 'Backend/Definitions/Device/device_definition.dart';
import 'Backend/app_shortcuts.dart';
import 'Backend/dynamic_config.dart';
import 'Backend/favorite_actions.dart';
import 'Backend/logging_wrappers.dart';
import 'Backend/move_lists.dart';
import 'Backend/sensors.dart';
import 'Frontend/Widgets/bt_app_state_controller.dart';
import 'Frontend/go_router_config.dart';
import 'Frontend/translation_string_definitions.dart';
import 'Frontend/utils.dart';
import 'constants.dart';
import 'l10n/messages_all_locales.dart';

//late SharedPreferences prefs;

FutureOr<SentryEvent?> beforeSend(SentryEvent event, Hint hint) async {
  bool reportingEnabled = HiveProxy.getOrDefault(settings, "allowErrorReporting", defaultValue: true);
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
  if (Platform.isIOS) {
    var installationAppReferrer = await InstallReferrer.referrer;
    if (installationAppReferrer == InstallationAppReferrer.iosTestFlight) {
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
    final bool isRunningInTestlab = await FirebaseTestlabDetector.isAppRunningInTestlab() ?? false;
    if (isRunningInTestlab) {
      return 'staging';
    }
  }
  return 'production';
}

Future<void> main() async {
  Logger.root.level = Level.ALL;
  mainLogger.info("Begin");
  Logger.root.onRecord.listen((event) {
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

  initLocale();
  await initHive();
  mainLogger.fine("Init Sentry");
  String environment = await getSentryEnvironment();
  DynamicConfigInfo dynamicConfigInfo = await getDynamicConfigInfo();
  mainLogger.info("Detected Environment: $environment");

  //initialize the foreground service library
  if (Platform.isAndroid) {
    FlutterForegroundTask.initCommunicationPort();
  }
  await SentryFlutter.init(
    (options) async {
      options
        ..dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: "")
        ..addIntegration(LoggingIntegration())
        ..enableBreadcrumbTrackingForCurrentPlatform()
        ..debug = kDebugMode
        ..diagnosticLevel = SentryLevel.info
        ..environment = environment
        ..tracesSampleRate = dynamicConfigInfo.sentryTraces
        ..profilesSampleRate = dynamicConfigInfo.sentryProfiles
        ..beforeSend = beforeSend
        ..reportPackages = false
        ..attachScreenshot = true
        ..screenshotQuality = SentryScreenshotQuality.low
        ..experimental.replay.sessionSampleRate = dynamicConfigInfo.sentryReplay;
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

void initFlutter() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized()..addObserver(WidgetBindingLogger());
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

  @override
  Future<void> didChangeLocales(List<Locale>? locales) async {
    await initLocale();
  }
}

Future<void> initHive() async {
  mainLogger.fine("Init Hive");
  final Directory appDir = await getApplicationSupportDirectory();
  SentryHive.init(appDir.path);
  if (!SentryHive.isAdapterRegistered(BaseStoredDeviceAdapter().typeId)) {
    SentryHive.registerAdapter(BaseStoredDeviceAdapter());
  }
  if (!SentryHive.isAdapterRegistered(MoveListAdapter().typeId)) {
    SentryHive.registerAdapter(MoveListAdapter());
  }
  if (!SentryHive.isAdapterRegistered(MoveAdapter().typeId)) {
    SentryHive.registerAdapter(MoveAdapter());
  }
  if (!SentryHive.isAdapterRegistered(TriggerActionAdapter().typeId)) {
    SentryHive.registerAdapter(TriggerActionAdapter());
  }
  if (!SentryHive.isAdapterRegistered(TriggerAdapter().typeId)) {
    SentryHive.registerAdapter(TriggerAdapter());
  }
  if (!SentryHive.isAdapterRegistered(ActionCategoryAdapter().typeId)) {
    SentryHive.registerAdapter(ActionCategoryAdapter());
  }
  if (!SentryHive.isAdapterRegistered(DeviceTypeAdapter().typeId)) {
    SentryHive.registerAdapter(DeviceTypeAdapter());
  }
  if (!SentryHive.isAdapterRegistered(MoveTypeAdapter().typeId)) {
    SentryHive.registerAdapter(MoveTypeAdapter());
  }
  if (!SentryHive.isAdapterRegistered(EasingTypeAdapter().typeId)) {
    SentryHive.registerAdapter(EasingTypeAdapter());
  }
  if (!SentryHive.isAdapterRegistered(AudioActionAdapter().typeId)) {
    SentryHive.registerAdapter(AudioActionAdapter());
  }
  if (!SentryHive.isAdapterRegistered(FavoriteActionAdapter().typeId)) {
    SentryHive.registerAdapter(FavoriteActionAdapter());
  }
  if (!SentryHive.isAdapterRegistered(BaseActionAdapter().typeId)) {
    SentryHive.registerAdapter(BaseActionAdapter());
  }
  if (!SentryHive.isAdapterRegistered(EarSpeedAdapter().typeId)) {
    SentryHive.registerAdapter(EarSpeedAdapter());
  }
  await SentryHive.openBox(settings); // Do not set type here
  await SentryHive.openBox<Trigger>(triggerBox);
  await SentryHive.openBox<FavoriteAction>(favoriteActionsBox);
  await SentryHive.openBox<AudioAction>(audioActionsBox);
  await SentryHive.openBox<MoveList>(sequencesBox);
  await SentryHive.openBox<BaseStoredDevice>(devicesBox);
}

Future<void> initLocale() async {
  final String defaultLocale = Platform.localeName; // Returns locale string in the form 'en_US'
  mainLogger.info("Locale: $defaultLocale");

  bool localeLoaded = await initializeMessages(defaultLocale);
  Intl.defaultLocale = defaultLocale;
  mainLogger.info("Loaded locale: $defaultLocale $localeLoaded");
}

class TailApp extends ConsumerWidget {
  TailApp({super.key}) {
    // Platform messages may fail, so we use a try/catch PlatformException.
    mainLogger.info('Starting app');
    if (kDebugMode) {
      mainLogger.info('Debug Mode Enabled');
      HiveProxy
        ..put(settings, showDebugging, true)
        ..put(settings, allowAnalytics, false)
        ..put(settings, allowErrorReporting, false)
        ..put(settings, hasCompletedOnboarding, hasCompletedOnboardingVersionToAgree)
        ..put(settings, showDemoGear, true);
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WithForegroundTask(
      key: GlobalKey(debugLabel: "foregroundTask"),
      child: ProviderScope(
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
                  unawaited(setupSystemColor(context));
                  Future(FlutterNativeSplash.remove); //remove the splash screen one frame later
                  Color color = Color(HiveProxy.getOrDefault(settings, appColor, defaultValue: appColorDefault));
                  return MaterialApp.router(
                    title: title(),
                    color: color,
                    theme: buildTheme(Brightness.light, color),
                    darkTheme: buildTheme(Brightness.dark, color),
                    routerConfig: router,
                    localizationsDelegates: AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    themeMode: ThemeMode.system,
                    debugShowCheckedModeBanner: false,
                  );
                },
              ),
            ),
          ),
        ),
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
      typography: Typography.material2021(),
      filledButtonTheme: FilledButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: getTextColor(color),
        ),
      ),
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
      typography: Typography.material2021(),
      filledButtonTheme: FilledButtonThemeData(
        style: ElevatedButton.styleFrom(foregroundColor: getTextColor(color), elevation: 1),
      ),
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
    if (kDebugMode) {
      //ref.watch(initWearProvider);
    }
    return child;
  }
}
