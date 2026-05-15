import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/foreground_service_manager.dart';
import 'package:tail_app/Backend/triggers/stored_triggers.dart';
import 'package:tail_app/Backend/wakelock_manager.dart';

import 'Backend/app_badges.dart';
import 'Backend/app_shortcuts.dart';
import 'Backend/logging_wrappers.dart';
import 'Backend/utilities/hive.dart';
import 'Backend/utilities/locale.dart';
import 'Backend/utilities/sentry.dart';
import 'Backend/wear_bridge.dart';
import 'Frontend/Widgets/bt_app_state_controller.dart';
import 'Frontend/go_router_config.dart';
import 'Frontend/theme_helpers.dart';
import 'Frontend/translation_string_definitions.dart';
import 'constants.dart';
import 'l10n/app_localizations.dart';

final _logger = Logger('Main');

Future<void> main() async {
  configureLogging();
  _logger.info("Begin");
  initFlutter();
  await initHive();
  initWear();
  appShortcuts();
  await startSentryApp(TailApp());
}

void initFlutter() {
  WidgetsBinding widgetsBinding =
      SentryWidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(
    widgetsBinding: widgetsBinding,
  ); // keeps the splash screen visible
}

class TailApp extends StatelessWidget {
  TailApp({super.key}) {
    if (kDebugMode) {
      _logger.info('Debug Mode Enabled');
      HiveProxy.put(settings, showDebugging, true);
    }

    // Force start singletons
    KnownDevices.instance;
    TriggerList.instance;
    ForegroundServiceManager.instance;
    AppBadgeManager.instance;
    WakelockManager.instance;
  }

  @override
  Widget build(BuildContext context) {
    _logger.info('Starting app');
    launchAppAnalytics();
    setupSystemColor(context);

    if (kDebugMode) {
      _logger.info('Debug Mode Enabled');
      HiveProxy.put(settings, showDebugging, true);
    }
    Future(
      FlutterNativeSplash.remove,
    ); //remove the splash screen one frame later
    Color primaryAppColor = Color(
      HiveProxy.getOrDefault(settings, appColor, defaultValue: appColorDefault),
    );
    return WithForegroundTask(
      child: BtAppStateController(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            Hive.box(
              settings,
            ).listenable(keys: [appColor, uwuTextEnabled, selectedLocale]),
            UserLocale.instance,
          ]),
          builder: (BuildContext context, Widget? child) {
            rebuildAllChildren(context);
            return MaterialApp.router(
              title: title(),
              color: primaryAppColor,
              theme: buildTheme(Brightness.light, primaryAppColor),
              darkTheme: buildTheme(Brightness.dark, primaryAppColor),
              routerConfig: router,
              localizationsDelegates: [
                LocaleNamesLocalizationsDelegate(),
                ...AppLocalizations.localizationsDelegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              themeMode: ThemeMode.system,
              debugShowCheckedModeBanner: false,
            );
          },
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
