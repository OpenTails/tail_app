import 'package:flutter/material.dart';
import 'package:plausible_analytics/plausible_analytics.dart';
import 'package:sentry_hive/sentry_hive.dart';

import '../Definitions/Device/BaseDeviceDefinition.dart';

class CustomNavObserver extends NavigatorObserver {
  /// The [Plausible] instance to report page views to.
  final Plausible plausible;

  CustomNavObserver(this.plausible);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    String? name = route.settings.name;
    String refferalName = previousRoute?.settings.name ?? "";
    if (name != null) {
      plausible.screenWidth = MediaQuery.of(route.navigator!.context).size.width.toString();
      plausible.event(page: route.settings.name.toString(), props: {"Number Of Devices": SentryHive.box<BaseStoredDevice>('devices').length.toString()}, referrer: refferalName);
    }
  }
}
