import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../app_config.dart';

/// Retries transient DNS / connection failures a few times.
class ConnectionRetryInterceptor extends Interceptor {
  ConnectionRetryInterceptor(
    this._dio, {
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 700),
  });

  final Dio _dio;
  final int maxRetries;
  final Duration retryDelay;

  static const _attemptKey = 'maran_retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    final attempt = err.requestOptions.extra[_attemptKey] as int? ?? 0;
    if (attempt >= maxRetries) {
      return handler.next(err);
    }

    err.requestOptions.extra[_attemptKey] = attempt + 1;
    await Future<void>.delayed(retryDelay * (attempt + 1));

    try {
      final response = await _dio.fetch<dynamic>(err.requestOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    } catch (_) {
      return handler.next(err);
    }
  }

  static bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout) return true;
    if (err.type != DioExceptionType.connectionError &&
        err.type != DioExceptionType.unknown) {
      return false;
    }
    final msg = '${err.message} ${err.error}'.toLowerCase();
    return msg.contains('failed host lookup') ||
        msg.contains('socketexception') ||
        msg.contains('connection errored') ||
        msg.contains('network is unreachable') ||
        msg.contains('timed out');
  }
}

/// Configures [Dio] for more reliable Windows DNS / TLS behavior.
void configureDioNetworking(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      client.idleTimeout = const Duration(seconds: 15);
      return client;
    },
  );
  dio.interceptors.insert(0, ConnectionRetryInterceptor(dio));
}

/// Warm DNS for the API host so the first login is less likely to fail.
Future<void> warmApiDns(String baseUrl) async {
  try {
    final host = Uri.tryParse(baseUrl)?.host;
    if (host == null || host.isEmpty) return;
    await InternetAddress.lookup(host).timeout(const Duration(seconds: 5));
  } catch (_) {
    // Best-effort only.
  }
}

/// Maps low-level Dio/network failures to a user-facing message.
String humanizeNetworkError(DioException e) {
  final raw = '${e.message ?? ''} ${e.error ?? ''}'.toLowerCase();
  if (raw.contains('failed host lookup') ||
      raw.contains('name not resolved') ||
      raw.contains('no address associated')) {
    final hostHint = _apiHostHint();
    if (Platform.isWindows) {
      return 'Cannot reach the Maran server (DNS lookup failed for '
          '$hostHint).\n\n'
          'Check your internet connection, then allow Maran Billing through '
          'antivirus/firewall (Total Security, Windows Defender). '
          'Try again in a few seconds.';
    }
    return 'Cannot reach the Maran server (DNS lookup failed for '
        '$hostHint).\n\n'
        'Check Wi‑Fi/mobile data, then try again. If this keeps happening, '
        'reinstall the latest app build.';
  }
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      raw.contains('timed out')) {
    return 'Connection timed out while reaching the Maran server. '
        'Check your internet connection and try again.';
  }
  if (e.type == DioExceptionType.connectionError ||
      raw.contains('connection errored') ||
      raw.contains('network is unreachable') ||
      raw.contains('socketexception')) {
    if (Platform.isWindows) {
      return 'No network connection to the Maran server. '
          'Check Wi‑Fi/Ethernet and antivirus network protection, then retry.';
    }
    return 'No network connection to the Maran server. '
        'Check Wi‑Fi/mobile data, then retry.';
  }
  return e.message ?? 'Network error';
}

String _apiHostHint() {
  final host = Uri.tryParse(AppConfig.apiBaseUrl)?.host;
  if (host == null || host.isEmpty) return 'the API host';
  return host;
}
