/// Permission constants for the entire app.
/// These match the backend Spatie Permissions.
abstract class AppPermissions {
  // Auth & Shop
  static const String shopManage = 'shop.manage';
  static const String usersManage = 'users.manage';
  static const String rolesManage = 'roles.manage';

  // POS & Billing
  static const String posManage = 'pos.manage';
  static const String billingCreate = 'billing.create';
  static const String billingView = 'billing.view';
  static const String billingDelete = 'billing.delete';

  // Inventory
  static const String inventoryManage = 'inventory.manage';
  static const String productsManage = 'products.manage';
  static const String purchasesManage = 'purchases.manage';
  static const String purchasesView = 'purchases.view';

  // Customers
  static const String customersManage = 'customers.manage';
  static const String customersView = 'customers.view';

  // EMR & Appointments
  static const String emrManage = 'emr.manage';
  static const String appointmentsManage = 'appointments.manage';
  static const String appointmentsView = 'appointments.view';

  // Expenses
  static const String expensesManage = 'expenses.manage';
  static const String expensesView = 'expenses.view';

  // Reports
  static const String reportsView = 'reports.view';
  static const String reportsExport = 'reports.export';

  // Settings
  static const String settingsView = 'settings.view';
  static const String settingsEdit = 'settings.edit';

  // All permission keys for reference
  static const List<String> allPermissions = [
    shopManage,
    usersManage,
    rolesManage,
    posManage,
    billingCreate,
    billingView,
    billingDelete,
    inventoryManage,
    productsManage,
    purchasesManage,
    purchasesView,
    customersManage,
    customersView,
    emrManage,
    appointmentsManage,
    appointmentsView,
    expensesManage,
    expensesView,
    reportsView,
    reportsExport,
    settingsView,
    settingsEdit,
  ];
}

/// Role constants that match backend roles.
abstract class AppRoles {
  static const String superAdmin = 'super_admin';
  static const String shopOwner = 'shop_owner';
  static const String branchManager = 'branch_manager';
  static const String cashier = 'cashier';
  static const String inventoryStaff = 'inventory_staff';
  static const String accountant = 'accountant';

  static const List<String> allRoles = [
    superAdmin,
    shopOwner,
    branchManager,
    cashier,
    inventoryStaff,
    accountant,
  ];
}

/// Permission service for checking user permissions and roles.
/// This should be used wherever permission checks are needed.
class PermissionService {
  /// Map of role to default permissions.
  /// These are baseline permissions; backend may return more.
  static const Map<String, List<String>> rolePermissionMap = {
    AppRoles.superAdmin: ['*'], // All permissions
    AppRoles.shopOwner: [
      AppPermissions.shopManage,
      AppPermissions.usersManage,
      AppPermissions.rolesManage,
      AppPermissions.posManage,
      AppPermissions.billingView,
      AppPermissions.billingCreate,
      AppPermissions.inventoryManage,
      AppPermissions.customersManage,
      AppPermissions.emrManage,
      AppPermissions.appointmentsManage,
      AppPermissions.expensesView,
      AppPermissions.reportsView,
      AppPermissions.settingsView,
      AppPermissions.settingsEdit,
    ],
    AppRoles.branchManager: [
      AppPermissions.posManage,
      AppPermissions.billingCreate,
      AppPermissions.billingView,
      AppPermissions.inventoryManage,
      AppPermissions.customersManage,
      AppPermissions.customersView,
      AppPermissions.emrManage,
      AppPermissions.appointmentsManage,
      AppPermissions.reportsView,
      AppPermissions.expensesManage,
    ],
    AppRoles.cashier: [
      AppPermissions.posManage,
      AppPermissions.billingCreate,
      AppPermissions.customersView,
    ],
    AppRoles.inventoryStaff: [
      AppPermissions.inventoryManage,
      AppPermissions.productsManage,
      AppPermissions.purchasesManage,
      AppPermissions.customersView,
    ],
    AppRoles.accountant: [
      AppPermissions.billingView,
      AppPermissions.expensesManage,
      AppPermissions.expensesView,
      AppPermissions.reportsView,
      AppPermissions.reportsExport,
      AppPermissions.settingsView,
    ],
  };

  /// Check if a user has a specific permission.
  /// Super admins always return true.
  static bool hasPermission(List<String> userPermissions, String permission) {
    if (userPermissions.contains('*')) return true;
    return userPermissions.contains(permission);
  }

  /// Check if a user has ANY of the provided permissions.
  static bool hasAnyPermission(
    List<String> userPermissions,
    List<String> permissions,
  ) {
    if (userPermissions.contains('*')) return true;
    return permissions.any((p) => userPermissions.contains(p));
  }

  /// Check if a user has ALL of the provided permissions.
  static bool hasAllPermissions(
    List<String> userPermissions,
    List<String> permissions,
  ) {
    if (userPermissions.contains('*')) return true;
    return permissions.every((p) => userPermissions.contains(p));
  }

  /// Check if a user has a specific role.
  static bool hasRole(List<String> userRoles, String role) {
    return userRoles.contains(role);
  }

  /// Check if a user has ANY of the provided roles.
  static bool hasAnyRole(List<String> userRoles, List<String> roles) {
    return roles.any((r) => userRoles.contains(r));
  }

  /// Check if a user is a super admin.
  static bool isSuperAdmin(List<String> userRoles) {
    return userRoles.contains(AppRoles.superAdmin);
  }

  /// Get all permissions for a role (from the map, not backend).
  static List<String> getDefaultPermissionsForRole(String role) {
    return rolePermissionMap[role] ?? [];
  }

  /// Get all roles that have a specific permission.
  static List<String> getRolesWithPermission(String permission) {
    final roles = <String>[];
    rolePermissionMap.forEach((role, permissions) {
      if (permissions.contains('*') || permissions.contains(permission)) {
        roles.add(role);
      }
    });
    return roles;
  }

  /// Get a human-readable role name.
  static String getRoleDisplayName(String role) {
    const roleNames = {
      AppRoles.superAdmin: 'Super Admin',
      AppRoles.shopOwner: 'Shop Owner',
      AppRoles.branchManager: 'Branch Manager',
      AppRoles.cashier: 'Cashier',
      AppRoles.inventoryStaff: 'Inventory Staff',
      AppRoles.accountant: 'Accountant',
    };
    return roleNames[role] ?? role;
  }

  /// Get a human-readable permission name.
  static String getPermissionDisplayName(String permission) {
    const permissionNames = {
      AppPermissions.shopManage: 'Manage Shop Settings',
      AppPermissions.usersManage: 'Manage Users',
      AppPermissions.rolesManage: 'Manage Roles',
      AppPermissions.posManage: 'Manage POS',
      AppPermissions.billingCreate: 'Create Invoices',
      AppPermissions.billingView: 'View Invoices',
      AppPermissions.billingDelete: 'Delete Invoices',
      AppPermissions.inventoryManage: 'Manage Inventory',
      AppPermissions.productsManage: 'Manage Products',
      AppPermissions.purchasesManage: 'Manage Purchases',
      AppPermissions.purchasesView: 'View Purchases',
      AppPermissions.customersManage: 'Manage Customers',
      AppPermissions.customersView: 'View Customers',
      AppPermissions.emrManage: 'Manage Medical Records',
      AppPermissions.appointmentsManage: 'Manage Appointments',
      AppPermissions.appointmentsView: 'View Appointments',
      AppPermissions.expensesManage: 'Manage Expenses',
      AppPermissions.expensesView: 'View Expenses',
      AppPermissions.reportsView: 'View Reports',
      AppPermissions.reportsExport: 'Export Reports',
      AppPermissions.settingsView: 'View Settings',
      AppPermissions.settingsEdit: 'Edit Settings',
    };
    return permissionNames[permission] ?? permission;
  }
}
