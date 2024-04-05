import 'package:flutter/material.dart';
import 'package:plausible_analytics/plausible_analytics.dart';

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
      plausible.event(page: route.settings.name.toString(), referrer: refferalName);
    }
  }
}
