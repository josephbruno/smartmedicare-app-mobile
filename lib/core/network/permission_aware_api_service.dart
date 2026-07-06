import 'package:dio/dio.dart';

import '../../data/models/user.dart';
import '../services/permission_service.dart';
import 'api_client.dart';
import 'api_exception.dart';

typedef PermissionsGetter = List<String> Function();

/// API service that enforces permissions at the API call level.
/// Wraps ApiClient to add permission checking before making requests.
class PermissionAwareApiService {
  final ApiClient _apiClient;
  final PermissionsGetter _getPermissions;
  final Function? _onPermissionDenied;

  PermissionAwareApiService({
    required ApiClient apiClient,
    required PermissionsGetter getPermissions,
    Function? onPermissionDenied,
  })  : _apiClient = apiClient,
        _getPermissions = getPermissions,
        _onPermissionDenied = onPermissionDenied;

  /// Get the underlying Dio client (use with caution).
  Dio get dio => _apiClient.dio;

  /// Make a GET request with permission check.
  Future<Response<T>> get<T>(
    String path, {
    required String permission,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    _checkPermission(permission);
    return _apiClient.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Make a POST request with permission check.
  Future<Response<T>> post<T>(
    String path, {
    required String permission,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    _checkPermission(permission);
    return _apiClient.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Make a PUT request with permission check.
  Future<Response<T>> put<T>(
    String path, {
    required String permission,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    _checkPermission(permission);
    return _apiClient.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Make a DELETE request with permission check.
  Future<Response<T>> delete<T>(
    String path, {
    required String permission,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    _checkPermission(permission);
    return _apiClient.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Check permission without making a request.
  /// Useful for UI decisions.
  bool canAccess(String permission) {
    final permissions = _getPermissions();
    return PermissionService.hasPermission(permissions, permission);
  }

  /// Check if user has ANY of the permissions.
  bool canAccessAny(List<String> permissions) {
    final userPermissions = _getPermissions();
    return PermissionService.hasAnyPermission(userPermissions, permissions);
  }

  /// Check if user has ALL of the permissions.
  bool canAccessAll(List<String> permissions) {
    final userPermissions = _getPermissions();
    return PermissionService.hasAllPermissions(userPermissions, permissions);
  }

  /// Make a request without permission check (use sparingly).
  Future<Response<T>> getUnchecked<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _apiClient.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Make a POST request without permission check (use sparingly).
  Future<Response<T>> postUnchecked<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _apiClient.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Internal: Check permission and throw if denied.
  void _checkPermission(String permission) {
    final permissions = _getPermissions();
    if (!PermissionService.hasPermission(permissions, permission)) {
      _onPermissionDenied?.call();
      throw ApiException(
        'You do not have permission: $permission',
        statusCode: 403,
      );
    }
  }
}

/// API endpoint permission mapping.
/// Define which endpoints require which permissions.
class ApiEndpointPermissions {
  // POS endpoints
  static const String posList = 'pos.manage';
  static const String posCreate = 'pos.manage';
  static const String posUpdate = 'pos.manage';
  static const String posDelete = 'pos.manage';

  // Billing endpoints
  static const String invoicesList = 'billing.view';
  static const String invoicesCreate = 'billing.create';
  static const String invoicesUpdate = 'billing.create';
  static const String invoicesDelete = 'billing.delete';

  // Inventory endpoints
  static const String inventoryList = 'inventory.manage';
  static const String inventoryCreate = 'inventory.manage';
  static const String inventoryUpdate = 'inventory.manage';
  static const String inventoryDelete = 'inventory.manage';

  // Product endpoints
  static const String productsList = 'products.manage';
  static const String productsCreate = 'products.manage';
  static const String productsUpdate = 'products.manage';
  static const String productsDelete = 'products.manage';

  // Purchase order endpoints
  static const String purchasesList = 'purchases.view';
  static const String purchasesCreate = 'purchases.manage';
  static const String purchasesUpdate = 'purchases.manage';
  static const String purchasesDelete = 'purchases.manage';

  // Customer endpoints
  static const String customersList = 'customers.view';
  static const String customersCreate = 'customers.manage';
  static const String customersUpdate = 'customers.manage';
  static const String customersDelete = 'customers.manage';

  // EMR endpoints
  static const String emrList = 'emr.manage';
  static const String emrCreate = 'emr.manage';
  static const String emrUpdate = 'emr.manage';
  static const String emrDelete = 'emr.manage';

  // Appointment endpoints
  static const String appointmentsList = 'appointments.view';
  static const String appointmentsCreate = 'appointments.manage';
  static const String appointmentsUpdate = 'appointments.manage';
  static const String appointmentsDelete = 'appointments.manage';

  // Expense endpoints
  static const String expensesList = 'expenses.view';
  static const String expensesCreate = 'expenses.manage';
  static const String expensesUpdate = 'expenses.manage';
  static const String expensesDelete = 'expenses.manage';

  // Report endpoints
  static const String reportsList = 'reports.view';
  static const String reportsExport = 'reports.export';

  // Settings endpoints
  static const String settingsView = 'settings.view';
  static const String settingsEdit = 'settings.edit';
}
