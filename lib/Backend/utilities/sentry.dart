import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:universal_io/io.dart';

import '../../constants.dart';
import '../dynamic_config.dart';
import '../logging_wrappers.dart';

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

FutureOr<SentryEvent?> beforeSend(SentryEvent event, Hint hint) async {
  DynamicConfigInfo dynamicConfigInfo = await getDynamicConfigInfo();

  bool reportingEnabled =
      HiveProxy.getOrDefault(
        settings,
        allowErrorReporting,
        defaultValue: allowErrorReportingDefault,
      ) &&
      dynamicConfigInfo.featureFlags.enableErrorReporting;
  if (reportingEnabled) {
    if (kDebugMode) {
      print('Before sending sentry event');
    }
    return event;
  } else {
    return null;
  }
}

Logger _logger = Logger("Sentry");

Future<void> startSentryApp(Widget child) async {
  if (const String.fromEnvironment('SENTRY_DSN', defaultValue: "").isEmpty) {
    runApp(child);
  }
  _logger.fine("Init Sentry");
  String environment = await getSentryEnvironment();
  DynamicConfigInfo dynamicConfigInfo = await getDynamicConfigInfo();
  _logger.info("Detected Environment: $environment");

  await SentryFlutter.init(
    (options) async {
      options
        ..dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: "")
        ..addIntegration(LoggingIntegration())
        ..enableBreadcrumbTrackingForCurrentPlatform()
        ..debug = kDebugMode
        ..diagnosticLevel = SentryLevel.info
        ..environment = environment
        ..tracesSampleRate = kDebugMode
            ? 1
            : dynamicConfigInfo.sentryConfig.tracesSampleRate
        ..profilesSampleRate = kDebugMode
            ? 1
            : dynamicConfigInfo.sentryConfig.profilesSampleRate
        ..beforeSend = beforeSend
        ..reportPackages = false
        ..attachScreenshot = true
        ..privacy.maskAllImages = false
        ..privacy.maskAllText =
            false // app does not contain any PII
        ..screenshotQuality = SentryScreenshotQuality.low
        ..replay.sessionSampleRate =
            dynamicConfigInfo.sentryConfig.replaySessionSampleRate
        ..replay.onErrorSampleRate =
            dynamicConfigInfo.sentryConfig.replayOnErrorSampleRate;
    },
    // Init your App.
    // ignore: missing_provider_scope
    appRunner: () => runApp(SentryScreenshotWidget(child: child)),
  );
}
