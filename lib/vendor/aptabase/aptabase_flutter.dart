/// The Flutter SDK for Aptabase, a privacy-first and
/// simple analytics platform for apps.

import "dart:async";
import "dart:convert";
import "dart:developer" as developer;
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter/widgets.dart";
import "package:tail_app/Frontend/utils.dart";
import "package:tail_app/vendor/aptabase/random_string.dart";
import "package:tail_app/vendor/aptabase/storage_manager.dart";
import "package:tail_app/vendor/aptabase/storage_manager_hive.dart";
import "package:tail_app/vendor/aptabase/sys_info.dart";

import "init_options.dart";

enum _SendResult { disabled, success, discard, tryAgain }

/// Vendored as the main library is abandoned and I don't feel like
/// maintaining a fork
///
/// replaced SharedPreferences with Hive_CE and Universal_IO with DIO

/// Aptabase Client for Flutter
///
/// Initialize the client with `Aptabase.init(appKey)` and then
/// use `Aptabase.instance.trackEvent(eventName, props)` to record events.
class Aptabase {
  Aptabase._();

  static const _sdkVersion = "aptabase_flutter@0.4.1";
  static const _sessionTimeout = Duration(hours: 1);

  static const Map<String, String> _hosts = {
    "EU": "https://eu.aptabase.com",
    "US": "https://us.aptabase.com",
    "DEV": "http://localhost:3000",
    "SH": "",
  };

  static late final String _appKey;
  static late final InitOptions _initOptions;
  static late final Uri? _apiUrl;
  static var _sessionId = _newSessionId();
  static var _lastTouchTs = DateTime.now().toUtc();
  static Timer? _timer;
  static var _isTimerRunning = false;
  static late final StorageManager _storage;
  static AppLifecycleListener? _listener;

  static final instance = Aptabase._();

  /// Initializes the Aptabase SDK with the given appKey.
  static Future<void> init(
    String appKey, [
    InitOptions opts = const InitOptions(),
    StorageManager? storage,
  ]) async {
    final parts = appKey.split("-");
    assert(
      parts.length == 3,
      "The Aptabase App Key has the pattern A-REG-0000000000",
    );
    assert(
      _hosts.containsKey(parts[1]),
      "The region part must be one of: ${_hosts.keys.join(" ")}",
    );

    if (parts.length != 3 || _hosts[parts[1]] == null) {
      _logError(
        "The Aptabase App Key '$appKey' is invalid. "
        "Tracking will be disabled.",
      );

      return;
    }

    _appKey = appKey;
    _initOptions = opts;

    final region = parts[1];
    _apiUrl = _getApiUrl(region, opts);

    if (_apiUrl == null) return;

    _logDebug("API URL is defined: $_apiUrl");

    _storage = storage ?? StorageManagerHive();

    await _storage.init();
    _logDebug("Storage initialized");

    _listener = AppLifecycleListener(
      onInactive: () => _tick("lifecycle onInactive"),
      onResume: _startTimer,
    );

    await _tick("init");
    _startTimer();

    _logInfo("Aptabase initilized!");
  }

  static void _dispose() {
    _timer?.cancel();
    _timer = null;
    _isTimerRunning = false;

    _listener?.dispose();
    _listener = null;
  }

  static void _startTimer() {
    _timer ??= Timer.periodic(
      _initOptions.tickDuration,
      (_) async => _tick("timer"),
    );
  }

  static Future<void> _tick(String reason) async {
    _logDebug("Checking events ($reason)");

    if (_isTimerRunning) {
      _logDebug("Already running, avoid duplication");
      return;
    }

    try {
      _isTimerRunning = true;

      final items = await _storage.getItems(_initOptions.batchLength);

      if (items.isEmpty) return;

      final events = items.map((e) => e.value).toList();
      final result = await _send(events);

      switch (result) {
        case _SendResult.disabled:
          _dispose();

        case _SendResult.tryAgain:
          break;

        case _SendResult.success:
        case _SendResult.discard:
          await _storage.deleteEvents(items.map((e) => e.key).toSet());
      }
    } catch (e, s) {
      _logError("Error on send events: $e", e, s);
    } finally {
      _isTimerRunning = false;
    }
  }

  /// Returns the session id for the current session.
  /// If the session is too old, a new session id is generated.
  String _evalSessionId() {
    final now = DateTime.now().toUtc();
    final elapsed = now.difference(_lastTouchTs);
    if (elapsed > _sessionTimeout) {
      _sessionId = _newSessionId();
      _logDebug("New session ID was generated: $_sessionId");
    }

    _lastTouchTs = now;
    return _sessionId;
  }

  Future<Map<String, dynamic>> _systemProps() async {
    final sysInfo = await SystemInfo.get();

    return {
      "isDebug": kDebugMode,
      "osName": sysInfo.osName,
      "osVersion": sysInfo.osVersion,
      "locale": sysInfo.locale,
      "appVersion": sysInfo.appVersion,
      "appBuildNumber": sysInfo.buildNumber,
      "sdkVersion": _sdkVersion,
    };
  }

  /// Records an event with the given name and optional properties.
  Future<void> trackEvent(
    String eventName, [
    Map<String, dynamic>? props,
  ]) async {
    if (_appKey.isEmpty || _apiUrl == null) {
      _logInfo("Tracking is disabled!");

      return;
    }

    final time = DateTime.now().toUtc();

    final body = json.encode({
      "timestamp": time.toIso8601String(),
      "sessionId": _evalSessionId(),
      "eventName": eventName,
      "systemProps": await _systemProps(),
      "props": props,
    });

    final key = "aptabase_${time.millisecondsSinceEpoch}_$eventName";

    await _storage.addEvent(key, body);
  }

  static Future<_SendResult> _send(List<String> events) async {
    try {
      final apiUrl = _apiUrl;
      if (apiUrl == null) {
        _logInfo("Tracking is disabled!");

        return _SendResult.disabled;
      }
      Dio dio = await initDio();

      Map<String, String> headers = {};
      headers["App-Key"] = _appKey;
      headers[HttpHeaders.contentTypeHeader] =
          "application/json; "
          "charset=UTF-8";
      if (!kIsWeb) {
        headers["User-Agent"] = _sdkVersion;
      }
      _logDebug("Sending ${events.length} events");
      Response response = await dio.post(
        apiUrl.toString(),
        data: events.toString(),
        options: Options(headers: headers, followRedirects: true),
      );

      if (kDebugMode && response.statusCode! >= 300) {
        final body = await response.data.transform(utf8.decoder).join();

        _logError(
          "TrackEvent failed with status code "
          "${response.statusCode}. Response: $body",
        );

        return response.statusCode! >= 500
            ? _SendResult.tryAgain
            : _SendResult.discard;
      }

      _logDebug("Sent successfully");

      return _SendResult.success;
    } on DioException catch (e, s) {
      _logError("TrackEvent Exception: $e", e, s);

      return _SendResult.tryAgain;
    }
  }

  /// Returns the API URL for the given region.
  static Uri? _getApiUrl(String region, InitOptions opts) {
    var baseUrl = _hosts[region];

    if (region == "SH") {
      if (opts.host != null) {
        baseUrl = opts.host;
      } else {
        _logError(
          "Host parameter must be defined when using Self-Hosted App Key. "
          "Tracking will be disabled.",
        );
        return null;
      }
    }

    return Uri.parse("$baseUrl/api/v0/events");
  }

  /// Returns a new session id.
  static String _newSessionId() => RandomString.randomize();

  static void _logError(String msg, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      msg,
      name: "Aptabase",
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _logInfo(String msg) {
    developer.log(msg, name: "Aptabase", level: 800);
  }

  static void _logDebug(String msg) {
    if (!_initOptions.printDebugMessages) return;

    developer.log(msg, name: "Aptabase", level: 500);
  }
}
