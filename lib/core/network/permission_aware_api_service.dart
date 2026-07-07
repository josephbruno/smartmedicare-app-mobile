import 'package:dio/dio.dart';

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
  // Billing / POS
  static const String invoicesList = AppPermissions.invoicesView;
  static const String invoicesCreate = AppPermissions.invoicesCreate;
  static const String invoicesUpdate = AppPermissions.invoicesCreate;
  static const String invoicesCancel = AppPermissions.invoicesCancel;

  // Inventory
  static const String inventoryList = AppPermissions.inventoryView;
  static const String inventoryAdjust = AppPermissions.inventoryAdjust;
  static const String inventoryTransfer = AppPermissions.inventoryTransfer;

  // Products
  static const String productsList = AppPermissions.productsView;
  static const String productsCreate = AppPermissions.productsCreate;
  static const String productsUpdate = AppPermissions.productsEdit;
  static const String productsDelete = AppPermissions.productsDelete;

  // Purchases
  static const String purchasesList = AppPermissions.purchasesView;
  static const String purchasesCreate = AppPermissions.purchasesCreate;
  static const String purchasesUpdate = AppPermissions.purchasesEdit;
  static const String purchasesDelete = AppPermissions.purchasesDelete;

  // Customers
  static const String customersList = AppPermissions.customersView;
  static const String customersCreate = AppPermissions.customersCreate;
  static const String customersUpdate = AppPermissions.customersEdit;
  static const String customersDelete = AppPermissions.customersDelete;

  // EMR
  static const String emrVisitsList = AppPermissions.emrVisitsView;
  static const String emrVisitsCreate = AppPermissions.emrVisitsCreate;
  static const String emrVisitsUpdate = AppPermissions.emrVisitsEdit;

  // Appointments
  static const String appointmentsList = AppPermissions.patientAppointmentsView;
  static const String appointmentsCreate = AppPermissions.patientAppointmentsCreate;
  static const String appointmentsUpdate = AppPermissions.patientAppointmentsEdit;

  // Expenses
  static const String expensesList = AppPermissions.expensesView;
  static const String expensesCreate = AppPermissions.expensesCreate;
  static const String expensesUpdate = AppPermissions.expensesEdit;
  static const String expensesDelete = AppPermissions.expensesDelete;

  // Reports
  static const String reportsList = AppPermissions.reportsView;
  static const String reportsExport = AppPermissions.reportsExport;

  // Settings / admin
  static const String shopSettings = AppPermissions.shopManage;
  static const String usersList = AppPermissions.usersView;
  static const String usersCreate = AppPermissions.usersCreate;
  static const String usersUpdate = AppPermissions.usersEdit;
  static const String branchManage = AppPermissions.branchManage;
  static const String doctorsManage = AppPermissions.doctorsManage;
}
