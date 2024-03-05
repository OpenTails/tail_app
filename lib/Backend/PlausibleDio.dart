import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:plausible_analytics/plausible_analytics.dart';

import '../main.dart';

class PlausibleDio extends Plausible {
  PlausibleDio(super.serverUrl, super.domain);

  //

  Dio dio = initDio();

  /// Post event to plausible
  @override
  Future<int> event({String name = "pageview", String referrer = "", String page = "", Map<String, String> props = const {}}) async {
    if (!enabled) {
      return 0;
    }

    // Post-edit parameters
    if (serverUrl.toString().endsWith('/')) {
      // Remove trailing slash '/'
      super.serverUrl = serverUrl.substring(0, serverUrl.length - 1);
    }
    page = "app://localhost/$page";
    referrer = "app://localhost/$referrer";

    // Http Post request see https://plausible.io/docs/events-api
    try {
      Object body = {
        "domain": domain,
        "name": name,
        "url": page,
        "referrer": referrer,
        "props": props,
      };
      await dio.post(Uri.parse('$serverUrl/api/event').toString(), data: json.encode(body), options: Options(contentType: 'application/json; charset=utf-8', headers: {'X-Forwarded-For': '127.0.0.1', 'User-Agent': userAgent}));
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    return 1;
  }
}
