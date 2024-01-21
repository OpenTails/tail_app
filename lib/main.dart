import 'dart:async';
import 'dart:developer';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock/wakelock.dart';

import 'Backend/Bluetooth/BluetoothManager.dart';
import 'Frontend/GoRouterConfig.dart';

late SharedPreferences prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Flogger.init(config: const FloggerConfig(showDebugLogs: true, printClassName: true, printMethodName: true, showDateTime: false));
  PlatformDispatcher.instance.onError = (error, stack) {
    Flogger.e(error.toString(), stackTrace: stack);
    return true;
  };
  Flogger.registerListener(
    (record) {
      LogConsole.add(OutputEvent(record.level, [record.printable()]), bufferSize: 100000);
      log(record.printable(), stackTrace: record.stackTrace);
    },
  );
  prefs = await SharedPreferences.getInstance();
  await SentryFlutter.init((options) {
    options.dsn = 'https://2558d1aca0730fe5a59b946cd62154a6@o1187002.ingest.sentry.io/4506525602742272';
    options.addIntegration(LoggingIntegration());
    options.attachScreenshot = true;
    options.attachViewHierarchy = true;
    options.tracesSampleRate = 1.0;
    options.profilesSampleRate = 1.0;
    options.attachThreads = true;
    options.enableUserInteractionTracing = true;
    options.reportSilentFlutterErrors = true;
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
          ));
}

class TailApp extends ConsumerWidget {
  const TailApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Flogger.i('Starting app');
    setupAsyncPermissions();
    return AdaptiveTheme(
        light: ThemeData.light(useMaterial3: true),
        dark: ThemeData.dark(useMaterial3: true),
        initial: AdaptiveThemeMode.system,
        builder: (theme, darkTheme) {
          return MaterialApp.router(
            title: 'All of the Tails',
            theme: theme,
            darkTheme: darkTheme,
            routerConfig: router,
          );
        });
  }

  //Todo: make a screen to display required permissions
  Future<void> setupAsyncPermissions() async {
    Wakelock.enable();
    Flogger.i("Permission BluetoothScan: ${await Permission.bluetoothScan.request()}");
    Flogger.i("Permission BluetoothConnect: ${await Permission.bluetoothConnect.request()}");

    //Flogger.i("Permission Location: ${await Permission.locationWhenInUse.request()}");
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
