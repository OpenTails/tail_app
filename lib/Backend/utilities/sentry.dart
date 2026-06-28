import 'dart:async';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:tail_app/Backend/utilities/hive.dart';
import 'package:universal_io/io.dart';

import '../../constants.dart';
import '../dynamic_config.dart';
import '../logging_wrappers.dart';

Random _random = Random();

Future<String> getSentryEnvironment() async {
  if (!kReleaseMode) {
    return 'debug';
  }
  try {
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
  } catch (e, s) {
    _logger.severe("Failed to determine environment for sentry", e, s);
  }
  return 'production';
}

FutureOr<SentryEvent?> beforeSend(SentryEvent event, Hint hint) async {
  bool reportingEnabled = true;
  if (isHiveReady) {
    DynamicConfigInfo dynamicConfigInfo = await getDynamicConfigInfo();
    reportingEnabled =
        HiveProxy.getOrDefault(
          settings,
          allowErrorReporting,
          defaultValue: allowErrorReportingDefault,
        ) &&
        dynamicConfigInfo.featureFlags.enableErrorReporting &&
        _random.nextDouble() <= dynamicConfigInfo.sentryConfig.sampleRate;
  }
  if (reportingEnabled) {
    return event;
  } else {
    return null;
  }
}

FutureOr<SentryTransaction?> beforeSendTransaction(
  SentryTransaction transaction,
  Hint hint,
) async {
  if (isHiveReady) {
    DynamicConfigInfo dynamicConfigInfo = await getDynamicConfigInfo();
    if (_random.nextDouble() <=
        dynamicConfigInfo.sentryConfig.tracesSampleRate) {
      return transaction;
    } else {
      return null;
    }
  }
  return transaction;
}

/// Filter out bluetooth device Ids so errors don't duplicate
/// TODO: More filtering for events
Breadcrumb? beforeBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  breadcrumb?.message = breadcrumb.message?.replaceAllMapped(
    RegExp(r'\^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})', caseSensitive: false),
    (match) => "[filtered mac address]",
  );
  //TODO: Verify other UUIDs are not caught in the crossfire
  breadcrumb?.message = breadcrumb.message?.replaceAllMapped(
    RegExp(
      r'\^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
      caseSensitive: false,
    ),
    (match) => "[filtered UUID]",
  );
  return breadcrumb;
}

Logger _logger = Logger("Sentry");

Future<void> startSentryApp(Widget child) async {
  _logger.fine("Init Sentry");
  String dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: "");
  _logger.info("Sentry DSN: $dsn");
  if (dsn.isEmpty) {
    _logger.severe("Sentry DSN is empty, Launching without sentry");
    runApp(child);
  }
  //String environment = await getSentryEnvironment();
  //_logger.info("Detected Environment: $environment");
  await SentryFlutter.init(
    (options) async {
      options
        ..dsn = dsn
        ..addIntegration(LoggingIntegration())
        ..enableBreadcrumbTrackingForCurrentPlatform()
        ..diagnosticLevel = SentryLevel.info
        //..environment = environment
        ..sampleRate = 1
        ..tracesSampleRate = 1
        // ..profilesSampleRate = kDebugMode
        //     ? 1
        //     : dynamicConfigInfo.sentryConfig.profilesSampleRate
        ..beforeSend = beforeSend
        ..beforeBreadcrumb = beforeBreadcrumb
        ..beforeSendTransaction = beforeSendTransaction
        ..addEventProcessor(EventSampleRateFilter())
        ..reportSilentFlutterErrors =
            true //TODO: configure dynamically after sentry inits
        ..attachScreenshot = true
        ..attachViewHierarchy = true
        ..enableTombstone = true
        ..enableFramesTracking
        ..privacy.maskAllImages = false
        ..privacy.maskAllText =
            false // app does not contain any PII
        ..screenshotQuality = SentryScreenshotQuality.low
        ..includeModuleInStackTrace = true;
      // ..replay.sessionSampleRate =
      //     dynamicConfigInfo.sentryConfig.replaySessionSampleRate
      // ..replay.onErrorSampleRate =
      //     dynamicConfigInfo.sentryConfig.replayOnErrorSampleRate;
    },
    // Init your App.
    // ignore: missing_provider_scope
    appRunner: () => runApp(
      SentryWidget(
        child: DefaultAssetBundle(bundle: SentryAssetBundle(), child: child),
      ),
    ),
  );
}

class EventSampleRateFilter implements EventProcessor {
  String environment = kReleaseMode ? "production" : "debug";

  EventSampleRateFilter() {
    Future(getSentryEnvironment).then((value) => environment = value);
  }

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, Hint hint) {
    event.environment = environment;
    return event;
  }
}
