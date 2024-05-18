import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:http/http.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tail_app/Frontend/utils.dart';
import 'package:wordpress_client/wordpress_client.dart';

/// Sentry only uses the [send] method of Client
class SentryDioClient implements Client {
  @override
  void close() {
    // TODO: implement close
  }

  @override
  Future<Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<Response> get(Uri url, {Map<String, String>? headers}) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future<Response> head(Uri url, {Map<String, String>? headers}) {
    // TODO: implement head
    throw UnimplementedError();
  }

  @override
  Future<Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    // TODO: implement patch
    throw UnimplementedError();
  }

  @override
  Future<Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    // TODO: implement post
    throw UnimplementedError();
  }

  @override
  Future<Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    // TODO: implement put
    throw UnimplementedError();
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) {
    // TODO: implement read
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) {
    // TODO: implement readBytes
    throw UnimplementedError();
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    // TODO: implement send
    return initDio(skipSentry: true) // avoid loop by not attaching sentry to sentry events;
        .requestUri(request.url,
            data: (request as StreamedRequest).sink,
            options: dio.Options(
              method: request.method,
              headers: request.headers,
            ))
        .then(
      (value) {
        return StreamedResponse(Stream.value(value.data), value.statusCode!, headers: value.headers.getHeaderMap());
      },
    );
  }
}

class CustomSentryPlatformChecker extends PlatformChecker {
  @override
  bool get hasNativeIntegration {
    return false;
  }
}
