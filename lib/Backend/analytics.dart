import 'dart:io';

import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tail_app/Backend/dynamic_config.dart';
import 'package:tail_app/Backend/wear_bridge.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import 'logging_wrappers.dart';

bool _didInit = false;

// should only fire once per app launch
Future<void> launchAppAnalytics() async {
  if (_didInit) {
    return;
  }
  analyticsEvent(name: "Launch App", props: await _getLaunchProps());
  analyticsEvent(name: "Settings", props: await _getSettingsProps());
}

Future<void> _initAptBase() async {
  if (_didInit) {
    return;
  }
  await Aptabase.init("A-SH-1386827771", InitOptions(printDebugMessages: kDebugMode, host: "https://aptabase.codel1417.xyz"));
  _didInit = true;
}

Future<void> analyticsEvent({String name = "", Map<String, String> props = const {}}) async {
  // global config file check
  if (!(await getDynamicConfigInfo()).featureFlags.enableAnalytics) {
    return;
  }

// user config check
  if (!HiveProxy.getOrDefault(settings, allowAnalytics, defaultValue: allowAnalyticsDefault)) {
    return;
  }
  _initAptBase();
  Aptabase.instance.trackEvent(name, props);
}

Future<Map<String, String>> _getSettingsProps({Map<String, String> props = const {}}) async {
  props = Map.of(props);

  // Settings
  props['UwU Enabled'] = HiveProxy.getOrDefault(settings, uwuTextEnabled, defaultValue: uwuTextEnabledDefault).toString();
  props['Marketing Notifications Enabled'] = HiveProxy.getOrDefault(settings, marketingNotificationsEnabled, defaultValue: marketingNotificationsEnabledDefault).toString();
  props['Fake Gear Enabled'] = HiveProxy.getOrDefault(settings, showDemoGear, defaultValue: showDemoGearDefault).toString();
  props['Hide Tutorial Cards Enabled'] = HiveProxy.getOrDefault(settings, hideTutorialCards, defaultValue: hideTutorialCardsDefault).toString();
  props['Haptic Feedback Enabled'] = HiveProxy.getOrDefault(settings, haptics, defaultValue: hapticsDefault).toString();
  props['Kitsune Mode Enabled'] = HiveProxy.getOrDefault(settings, kitsuneModeToggle, defaultValue: kitsuneModeDefault).toString();
  props['Tail Blog Wifi Only Enabled'] = HiveProxy.getOrDefault(settings, tailBlogWifiOnly, defaultValue: tailBlogWifiOnlyDefault).toString();
  props['Larger Cards Enabled'] = HiveProxy.getOrDefault(settings, largerActionCardSize, defaultValue: largerActionCardSizeDefault).toString();
  props['Show Battery % Enabled'] = HiveProxy.getOrDefault(settings, showAccurateBattery, defaultValue: showAccurateBatteryDefault).toString();
  props['Keep Screen On Enabled'] = HiveProxy.getOrDefault(settings, keepAwake, defaultValue: keepAwakeDefault).toString();
  props['Selected Language'] = HiveProxy.getOrDefault(settings, selectedLocale, defaultValue: "Not Set").toString();
  props['Developer Mode'] = HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault).toString();
  props['Custom App Color'] = (HiveProxy.getOrDefault(settings, appColor, defaultValue: appColorDefault) != appColorDefault).toString();

  return props;
}

Future<Map<String, String>> _getLaunchProps({Map<String, String> props = const {}}) async {
  props = Map.of(props);
  //props['App Version'] = (await PackageInfo.fromPlatform()).version;
  //props['App Build'] = (await PackageInfo.fromPlatform()).buildNumber;
  props['Locale'] = Platform.localeName;
  props['Installer Store'] = (await PackageInfo.fromPlatform()).installerStore ?? "Unknown";

  try {
    props['Has Watch'] = (await isPaired()).toString();
  } catch (e) {
    props['Has Watch'] = false.toString();
  }

  if (Platform.isAndroid) {
    AndroidDeviceInfo androidDeviceInfo = await DeviceInfoPlugin().androidInfo;
    props['Device Brand'] = androidDeviceInfo.brand;
  } else if (Platform.isIOS) {
    IosDeviceInfo iosDeviceInfo = await DeviceInfoPlugin().iosInfo;
    props['Device Brand'] = "Apple";
  }
  return props;
}

Future<void> launchExternalUrl({required String url, required String analyticsLabel, bool addTrackingUtm = true}) async {
  analyticsEvent(name: "Launch External URL", props: {"type": analyticsLabel});
  await launchUrl(Uri.parse(url + (addTrackingUtm ? "/${getOutboundUtm()}" : "")));
}

String getOutboundUtm() {
  String utm = "?utm_medium=Tail_App";
  if (Platform.isAndroid) {
    utm = "$utm?utm_source=tailappandr";
  } else if (Platform.isIOS) {
    utm = "$utm?utm_source=tailappios";
  }
  return utm;
}
