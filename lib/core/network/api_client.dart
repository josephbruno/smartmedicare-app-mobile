import 'package:dio/dio.dart';

import '../app_config.dart';
import 'api_exception.dart';
import 'api_logging_interceptor.dart';
import 'network_resilience.dart';

typedef TokenGetter = String? Function();
typedef BranchIdGetter = int? Function();
typedef SuperAdminGetter = bool Function();
typedef VoidCallback = void Function();

/// Called for 403 PLAN_UPGRADE_REQUIRED / 422 PLAN_LIMIT_REACHED with the API's message.
typedef PlanErrorCallback = void Function(String code, String message);

/// Called with the X-Plan-Version response header (changes on upgrade / CMS module edits).
typedef PlanVersionCallback = void Function(String version);

/// HTTP client aligned with [frontend/src/api/client.ts].
class ApiClient {
  ApiClient({
    required TokenGetter getToken,
    required BranchIdGetter getBranchId,
    required SuperAdminGetter isSuperAdmin,
    required VoidCallback onUnauthorized,
    required VoidCallback onSubscriptionExpired,
    PlanErrorCallback? onPlanError,
    PlanVersionCallback? onPlanVersion,
    String? baseUrl,
  })  : _onPlanError = onPlanError,
        _onPlanVersion = onPlanVersion,
        _getToken = getToken,
        _getBranchId = getBranchId,
        _isSuperAdmin = isSuperAdmin,
        _onUnauthorized = onUnauthorized,
        _onSubscriptionExpired = onSubscriptionExpired,
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    configureDioNetworking(dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final branchId = _getBranchId();
          final skipBranch = _isSuperAdmin() &&
              options.path.contains('/reports/');
          if (branchId != null && !skipBranch) {
            options.headers['X-Branch-Id'] = branchId.toString();
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          final version = response.headers.value('x-plan-version');
          if (version != null && version.isNotEmpty) _onPlanVersion?.call(version);
          return handler.next(response);
        },
        onError: (e, handler) {
          final status = e.response?.statusCode;
          if (status == 401) {
            _onUnauthorized();
          } else if (status == 402) {
            _onSubscriptionExpired();
          } else if (status == 403 || status == 422) {
            final data = e.response?.data;
            if (data is Map) {
              final code = data['code']?.toString();
              if (code == 'PLAN_UPGRADE_REQUIRED' || code == 'PLAN_LIMIT_REACHED') {
                _onPlanError?.call(code!, data['message']?.toString() ?? 'Not included in your current plan.');
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
    dio.interceptors.add(ApiLoggingInterceptor());
  }

  final Dio dio;
  final TokenGetter _getToken;
  final BranchIdGetter _getBranchId;
  final SuperAdminGetter _isSuperAdmin;
  final VoidCallback _onUnauthorized;
  final VoidCallback _onSubscriptionExpired;
  final PlanErrorCallback? _onPlanError;
  final PlanVersionCallback? _onPlanVersion;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      dio.put<T>(path, data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options);

  static Never throwFromDio(DioException e) {
    final data = e.response?.data;
    final status = e.response?.statusCode;
    String msg = humanizeNetworkError(e);
    Map<String, List<String>>? errors;
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      if (m['message'] is String) msg = m['message'] as String;
      if (m['errors'] is Map) {
        errors = {};
        (m['errors'] as Map).forEach((k, v) {
          if (v is List) {
            errors![k.toString()] = v.map((e) => e.toString()).toList();
          }
        });
      }
    } else if (_looksLikeHtml(data) || status == 403) {
      final html = data is String ? data.toLowerCase() : '';
      if (html.contains('lsrecap') || html.contains('bot verification')) {
        msg = 'The host blocked this request as a bot. Please try again in a minute.';
      } else if (status == 403 || html.contains('access to this resource')) {
        msg = 'The host firewall blocked this request. Try again in a few minutes.';
      } else {
        msg = 'The server returned an unexpected response. Please try again.';
      }
    }

    // Prefer the first field error over a generic validation message.
    if (errors != null && errors.isNotEmpty) {
      for (final list in errors.values) {
        if (list.isNotEmpty) {
          final first = list.first.trim();
          if (first.isNotEmpty) {
            msg = first;
            break;
          }
        }
      }
    }

    // Rate limited (login / PIN brute-force protection).
    if (status == 429) {
      final retry = int.tryParse(e.response?.headers.value('retry-after') ?? '') ?? 60;
      final wait = retry >= 60
          ? '${(retry / 60).ceil()} minute${retry >= 120 ? 's' : ''}'
          : '$retry seconds';
      msg = 'Too many attempts. Please wait $wait and try again.';
    }

    throw ApiException(
      msg,
      code: data is Map ? data['code']?.toString() : null,
      statusCode: e.response?.statusCode,
      errors: errors,
    );
  }

  static bool _looksLikeHtml(dynamic data) {
    if (data is! String) return false;
    final s = data.trimLeft().toLowerCase();
    return s.startsWith('<!doctype') || s.startsWith('<html');
  }
}
