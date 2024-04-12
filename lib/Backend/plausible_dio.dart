import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:install_referrer/install_referrer.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plausible_analytics/plausible_analytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/move_lists.dart';

import '../Frontend/utils.dart';
import '../constants.dart';
import '../main.dart';
import 'Definitions/Device/device_definition.dart';
import 'sensors.dart';

class PlausibleDio extends Plausible {
  PlausibleDio(super.serverUrl, super.domain);

  Dio dio = initDio();

  /// Post event to plausible
  @override
  Future<int> event({String name = "pageview", String referrer = "", String page = "", Map<String, String> props = const {}}) async {
    if (!enabled && SentryHive.box(settings).get(allowAnalytics, defaultValue: allowAnalyticsDefault)) {
      return 0;
    }
    final transaction = Sentry.startTransaction('Plausible Event', 'http');
    // Post-edit parameters
    if (serverUrl.toString().endsWith('/')) {
      // Remove trailing slash '/'
      super.serverUrl = serverUrl.substring(0, serverUrl.length - 1);
    }
    page = "app://localhost/$page?utm_source=${(await InstallReferrer.referrer).name}";
    referrer = "app://localhost/$referrer";
    props = Map.of(props);
    props['Number Of Devices'] = SentryHive.box<BaseStoredDevice>('devices').length.toString();
    props['Number Of Sequences'] = SentryHive.box<MoveList>('sequences').length.toString();
    props['Number Of Triggers'] = SentryHive.box<Trigger>(triggerBox).length.toString();
    props['App Version'] = (await PackageInfo.fromPlatform()).version;
    props['App Build'] = (await PackageInfo.fromPlatform()).buildNumber;

    // Http Post request see https://plausible.io/docs/events-api
    try {
      Object body = {
        "domain": domain,
        "name": name,
        "url": page,
        "referrer": referrer,
        "props": props,
      };
      await dio.post(
        Uri.parse('$serverUrl/api/event').toString(),
        data: json.encode(body),
        options: Options(
          contentType: 'application/json; charset=utf-8',
        ),
      );
    } catch (e) {
      transaction.throwable = e;
      transaction.status = const SpanStatus.internalError();
      if (kDebugMode) {
        print(e);
      }
    }
    transaction.finish();
    return 1;
  }
}
