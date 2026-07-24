/// Permission constants for the entire app.
/// These match the backend Spatie permission names exactly.
abstract class AppPermissions {
  // Products & catalog
  static const String productsView = 'products.view';
  static const String productsCreate = 'products.create';
  static const String productsEdit = 'products.edit';
  static const String productsDelete = 'products.delete';

  // Inventory
  static const String inventoryView = 'inventory.view';
  static const String inventoryAdjust = 'inventory.adjust';
  static const String inventoryTransfer = 'inventory.transfer';

  // Purchases & suppliers
  static const String purchasesView = 'purchases.view';
  static const String purchasesCreate = 'purchases.create';
  static const String purchasesEdit = 'purchases.edit';
  static const String purchasesDelete = 'purchases.delete';
  static const String suppliersView = 'suppliers.view';
  static const String suppliersCreate = 'suppliers.create';
  static const String suppliersEdit = 'suppliers.edit';
  static const String suppliersDelete = 'suppliers.delete';

  // Billing
  static const String invoicesView = 'invoices.view';
  static const String invoicesCreate = 'invoices.create';
  static const String invoicesCancel = 'invoices.cancel';
  static const String paymentsView = 'payments.view';
  static const String paymentsCreate = 'payments.create';
  static const String discountsApply = 'discounts.apply';

  // Customers & pets
  static const String customersView = 'customers.view';
  static const String customersCreate = 'customers.create';
  static const String customersEdit = 'customers.edit';
  static const String customersDelete = 'customers.delete';
  static const String petsView = 'pets.view';
  static const String petsCreate = 'pets.create';
  static const String petsEdit = 'pets.edit';

  // Expenses & reports
  static const String expensesView = 'expenses.view';
  static const String expensesCreate = 'expenses.create';
  static const String expensesEdit = 'expenses.edit';
  static const String expensesDelete = 'expenses.delete';
  static const String reportsView = 'reports.view';
  static const String reportsExport = 'reports.export';
  static const String analyticsView = 'analytics.view';

  // Users, roles & shop
  static const String usersView = 'users.view';
  static const String usersCreate = 'users.create';
  static const String usersEdit = 'users.edit';
  static const String usersDelete = 'users.delete';
  static const String rolesManage = 'roles.manage';
  static const String shopManage = 'shop.manage';
  static const String branchManage = 'branch.manage';
  static const String doctorsManage = 'doctors.manage';

  // EMR
  static const String emrVisitsView = 'emr.visits.view';
  static const String emrMasterDataManage = 'emr.master_data.manage';
  static const String emrVisitsCreate = 'emr.visits.create';
  static const String emrVisitsEdit = 'emr.visits.edit';
  static const String emrVisitsBill = 'emr.visits.bill';
  static const String emrDewormingView = 'emr.deworming.view';
  static const String emrDewormingCreate = 'emr.deworming.create';
  static const String emrSurgeriesView = 'emr.surgeries.view';
  static const String emrSurgeriesCreate = 'emr.surgeries.create';
  static const String emrLabReportsView = 'emr.lab_reports.view';
  static const String emrLabReportsUpload = 'emr.lab_reports.upload';
  static const String emrDocumentsView = 'emr.documents.view';
  static const String emrDocumentsUpload = 'emr.documents.upload';
  static const String emrRemindersView = 'emr.reminders.view';
  static const String emrRemindersManage = 'emr.reminders.manage';

  // Appointments
  static const String patientAppointmentsView = 'patient_appointments.view';
  static const String patientAppointmentsCreate = 'patient_appointments.create';
  static const String patientAppointmentsEdit = 'patient_appointments.edit';
  static const String patientAppointmentsCancel = 'patient_appointments.cancel';
}

/// Role constants that match backend roles (single-clinic model).
abstract class AppRoles {
  static const String superAdmin = 'super_admin';
  static const String branchManager = 'branch_manager';
  static const String doctor = 'doctor';
  static const String cashier = 'cashier';

  static const List<String> allRoles = [
    superAdmin,
    branchManager,
    doctor,
    cashier,
  ];

  /// Roles assignable by clinic owner when creating staff.
  static const List<String> staffRoles = [
    branchManager,
    doctor,
    cashier,
  ];

  /// Default cashier permissions (mirrors RolePermissionSeeder).
  static const List<String> cashierPermissions = [
    AppPermissions.productsView,
    AppPermissions.inventoryView,
    AppPermissions.invoicesView,
    AppPermissions.invoicesCreate,
    AppPermissions.paymentsCreate,
    AppPermissions.customersView,
    AppPermissions.customersCreate,
    AppPermissions.customersEdit,
    AppPermissions.petsView,
    AppPermissions.petsCreate,
    AppPermissions.emrVisitsView,
    AppPermissions.emrVisitsBill,
    AppPermissions.emrRemindersView,
    AppPermissions.patientAppointmentsView,
    AppPermissions.patientAppointmentsCreate,
    AppPermissions.discountsApply,
  ];

  /// Default doctor permissions (mirrors RolePermissionSeeder).
  static const List<String> doctorPermissions = [
    AppPermissions.customersView,
    AppPermissions.customersCreate,
    AppPermissions.customersEdit,
    AppPermissions.petsView,
    AppPermissions.petsCreate,
    AppPermissions.petsEdit,
    AppPermissions.invoicesView,
    AppPermissions.invoicesCreate,
    AppPermissions.paymentsView,
    AppPermissions.productsView,
    AppPermissions.inventoryView,
    AppPermissions.emrVisitsView,
    AppPermissions.emrVisitsCreate,
    AppPermissions.emrVisitsEdit,
    AppPermissions.emrDewormingView,
    AppPermissions.emrDewormingCreate,
    AppPermissions.emrSurgeriesView,
    AppPermissions.emrSurgeriesCreate,
    AppPermissions.emrLabReportsView,
    AppPermissions.emrLabReportsUpload,
    AppPermissions.emrDocumentsView,
    AppPermissions.emrDocumentsUpload,
    AppPermissions.emrRemindersView,
    AppPermissions.emrRemindersManage,
    AppPermissions.patientAppointmentsView,
    AppPermissions.patientAppointmentsCreate,
    AppPermissions.patientAppointmentsEdit,
    AppPermissions.patientAppointmentsCancel,
  ];
}

/// Permission service for checking user permissions and roles.
class PermissionService {
  static bool hasPermission(
    List<String> userPermissions,
    String permission, {
    List<String> userRoles = const [],
  }) {
    if (isSuperAdmin(userRoles)) return true;
    if (userPermissions.contains('*')) return true;
    return userPermissions.contains(permission);
  }

  static bool hasAnyPermission(
    List<String> userPermissions,
    List<String> permissions, {
    List<String> userRoles = const [],
  }) {
    if (isSuperAdmin(userRoles)) return true;
    if (userPermissions.contains('*')) return true;
    return permissions.any((p) => userPermissions.contains(p));
  }

  static bool hasAllPermissions(
    List<String> userPermissions,
    List<String> permissions, {
    List<String> userRoles = const [],
  }) {
    if (isSuperAdmin(userRoles)) return true;
    if (userPermissions.contains('*')) return true;
    return permissions.every((p) => userPermissions.contains(p));
  }

  static bool hasRole(List<String> userRoles, String role) {
    return userRoles.contains(role);
  }

  static bool hasAnyRole(List<String> userRoles, List<String> roles) {
    return roles.any((r) => userRoles.contains(r));
  }

  static bool isSuperAdmin(List<String> userRoles) {
    return userRoles.contains(AppRoles.superAdmin);
  }

  static String getRoleDisplayName(String role) {
    const roleNames = {
      AppRoles.superAdmin: 'Clinic Owner',
      AppRoles.branchManager: 'Branch Manager',
      AppRoles.doctor: 'Doctor',
      AppRoles.cashier: 'Cashier',
    };
    return roleNames[role] ?? role;
  }

  static String getPermissionDisplayName(String permission) {
    return permission.replaceAll('.', ' ').replaceAll('_', ' ');
  }
}
