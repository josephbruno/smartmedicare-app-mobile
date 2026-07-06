import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Logs every API request and response to the console in debug builds.
class ApiLoggingInterceptor extends Interceptor {
  static const _tag = '[API]';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_enabled) return handler.next(options);

    final buffer = StringBuffer()
      ..writeln('→ ${options.method} ${options.uri}')
      ..writeln('Headers: ${_redactHeaders(options.headers)}');

    if (options.queryParameters.isNotEmpty) {
      buffer.writeln('Query: ${options.queryParameters}');
    }
    if (options.data != null) {
      buffer.writeln('Request body:\n${_format(options.data)}');
    }

    debugPrint('$_tag\n$buffer');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_enabled) return handler.next(response);

    final buffer = StringBuffer()
      ..writeln('← ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}')
      ..writeln('Response body:\n${_format(response.data)}');

    debugPrint('$_tag\n$buffer');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_enabled) return handler.next(err);

    final buffer = StringBuffer()
      ..writeln('✕ ${err.requestOptions.method} ${err.requestOptions.uri}')
      ..writeln('Status: ${err.response?.statusCode ?? '—'}')
      ..writeln('Message: ${err.message}');

    if (err.response?.data != null) {
      buffer.writeln('Error body:\n${_format(err.response!.data)}');
    }

    debugPrint('$_tag\n$buffer');
    handler.next(err);
  }

  bool get _enabled => kDebugMode;

  Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    final copy = Map<String, dynamic>.from(headers);
    for (final key in copy.keys.toList()) {
      if (key.toLowerCase() == 'authorization') {
        copy[key] = 'Bearer ***';
      }
    }
    return copy;
  }

  String _format(dynamic data) {
    if (data == null) return 'null';
    if (data is FormData) {
      return 'FormData(fields: ${data.fields}, files: ${data.files.length})';
    }
    if (data is String) return data;
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}
