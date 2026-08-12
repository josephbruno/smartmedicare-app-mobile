import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../session/auth_session.dart';
import '../services/permission_service.dart';
import '../update/windows_update_gate.dart';
import '../widgets/permission_guard.dart';
import '../app_config.dart';
import '../../features/auth/cashier_desktop_only_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/landing_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/pin_unlock_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/set_pin_screen.dart';
import '../../features/auth/subscription_expired_screen.dart';
import '../../features/auth/video_splash_screen.dart';
import '../../features/common/not_found_screen.dart';
import '../../features/customers/customer_detail_screen.dart';
import '../../features/customers/customer_form_screen.dart';
import '../../features/customers/customer_list_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/emr/appointment_form_screen.dart';
import '../../features/emr/deworming_management_screen.dart';
import '../../features/emr/documents_screen.dart';
import '../../features/emr/lab_reports_screen.dart';
import '../../features/emr/patient_appointment_list_screen.dart';
import '../../features/emr/patient_list_screen.dart';
import '../../features/emr/pet_timeline_screen.dart';
import '../../features/emr/pet_visit_summary_screen.dart';
import '../../features/emr/reminder_dashboard_screen.dart';
import '../../features/emr/surgery_management_screen.dart';
import '../../features/emr/visit_detail_screen.dart';
import '../../features/emr/visit_form_screen.dart';
import '../../features/emr/visit_list_screen.dart';
import '../../features/expenses/expenses_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/inventory/stock_ageing_screen.dart';
import '../../features/inventory/stock_alerts_screen.dart';
import '../../features/inventory/stock_transfer_detail_screen.dart';
import '../../features/inventory/stock_transfer_form_screen.dart';
import '../../features/inventory/stock_transfer_list_screen.dart';
import '../../features/invoices/invoice_detail_screen.dart';
import '../../features/invoices/invoice_list_screen.dart';
import '../../features/pos/pos_screen.dart';
import '../../features/products/product_form_screen.dart';
import '../../features/products/product_list_screen.dart';
import '../../features/invoices/sale_return_form_screen.dart';
import '../../features/purchases/purchase_detail_screen.dart';
import '../../features/purchases/purchase_form_screen.dart';
import '../../features/purchases/purchase_list_screen.dart';
import '../../features/purchases/purchase_return_detail_screen.dart';
import '../../features/purchases/purchase_return_form_screen.dart';
import '../../features/purchases/purchase_return_list_screen.dart';
import '../../features/purchases/supplier_list_screen.dart';
import '../../features/reports/gst_report_screen.dart';
import '../../features/reports/day_close_report_screen.dart';
import '../../features/reports/payment_report_screen.dart';
import '../../features/reports/sales_report_screen.dart';
import '../../features/reports/stock_transfer_report_screen.dart';
import '../../features/reports/visit_report_screen.dart';
import '../../features/settings/account_security_screen.dart';
import '../../features/settings/branches_screen.dart';
import '../../features/settings/catalog_master_data_screen.dart';
import '../../features/settings/doctors_screen.dart';
import '../../features/settings/emr_master_data_screen.dart';
import '../../features/settings/pet_species_breed_master_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/usb_printer_settings_screen.dart';
import '../../features/settings/users_screen.dart';
import '../../features/shell/app_shell.dart';

GoRouter createAppRouter({
  required AuthSession auth,
  required GlobalKey<NavigatorState> rootNavigatorKey,
}) {
  String? permissionRedirect(String path) {
    final denied = auth.homeRoute;
    bool need(String perm) => !auth.hasPermission(perm);

    if (path.startsWith('/pos')) {
      if (need(AppPermissions.invoicesCreate)) return denied;
    }
    if (path.startsWith('/invoices')) {
      if (path.endsWith('/return')) {
        if (need(AppPermissions.invoicesCreate)) return denied;
      } else if (need(AppPermissions.invoicesView)) {
        return denied;
      }
    }
    if (path.startsWith('/products')) {
      if (path.endsWith('/new')) {
        if (need(AppPermissions.productsCreate)) return denied;
      } else if (path.contains('/edit')) {
        if (need(AppPermissions.productsEdit)) return denied;
      } else if (need(AppPermissions.productsView)) {
        return denied;
      }
    }
    if (path.startsWith('/stock-transfers')) {
      if (path.endsWith('/new')) {
        if (need(AppPermissions.inventoryTransfer)) return denied;
      } else if (need(AppPermissions.inventoryTransfer)) {
        return denied;
      }
    }
    if (path.startsWith('/inventory') ||
        path.startsWith('/stock-ageing') ||
        path.startsWith('/stock-alerts')) {
      if (need(AppPermissions.inventoryView)) return denied;
    }
    if (path.startsWith('/purchases') || path.startsWith('/purchase-returns')) {
      if (path.endsWith('/new')) {
        if (need(AppPermissions.purchasesCreate)) return denied;
      } else if (need(AppPermissions.purchasesView)) {
        return denied;
      }
    }
    if (path.startsWith('/suppliers')) {
      if (need(AppPermissions.suppliersView)) return denied;
    }
    if (path.startsWith('/customers')) {
      if (path.endsWith('/new')) {
        if (need(AppPermissions.customersCreate)) return denied;
      } else if (need(AppPermissions.customersView)) {
        return denied;
      }
    }
    if (path.startsWith('/patients')) {
      if (need(AppPermissions.customersView)) return denied;
    }
    if (path.startsWith('/emr/appointments')) {
      if (path.endsWith('/new')) {
        if (need(AppPermissions.patientAppointmentsCreate)) return denied;
      } else if (path.contains('/edit')) {
        if (need(AppPermissions.patientAppointmentsEdit)) return denied;
      } else if (need(AppPermissions.patientAppointmentsView)) {
        return denied;
      }
    }
    if (path.startsWith('/emr/pets/')) {
      if (path.contains('/deworming') && need(AppPermissions.emrDewormingView)) {
        return denied;
      }
      if (path.contains('/surgeries') && need(AppPermissions.emrSurgeriesView)) {
        return denied;
      }
      if (path.contains('/lab-reports') && need(AppPermissions.emrLabReportsView)) {
        return denied;
      }
      if (path.contains('/documents') && need(AppPermissions.emrDocumentsView)) {
        return denied;
      }
      if (path.contains('/timeline') && need(AppPermissions.emrVisitsView)) {
        return denied;
      }
      if (path.contains('/visit-summary') && need(AppPermissions.emrVisitsView)) {
        return denied;
      }
    }
    if (path.startsWith('/emr/visits')) {
      if (path.endsWith('/new')) {
        if (need(AppPermissions.emrVisitsCreate)) return denied;
      } else if (path.contains('/edit')) {
        if (need(AppPermissions.emrVisitsEdit)) return denied;
      } else if (need(AppPermissions.emrVisitsView)) {
        return denied;
      }
    }
    if (path.startsWith('/emr/reminders')) {
      if (need(AppPermissions.emrRemindersView)) return denied;
    }
    if (path.startsWith('/expenses')) {
      if (need(AppPermissions.expensesView)) return denied;
    }
    if (path.startsWith('/reports/day-close')) {
      if (need(AppPermissions.cashierDayClose)) return denied;
    } else if (path.startsWith('/reports/payments') || path.startsWith('/reports/sales')) {
      if (need(AppPermissions.reportsView)) return denied;
    } else if (path.startsWith('/reports')) {
      if (need(AppPermissions.reportsView) || !auth.isSuperAdmin) return denied;
    }
    if (path.startsWith('/settings/doctors')) {
      if (need(AppPermissions.doctorsManage)) return denied;
    }
    if (path.startsWith('/settings/emr-master-data')) {
      if (need(AppPermissions.emrMasterDataManage)) return denied;
    }
    if (path.startsWith('/settings/species-breeds')) {
      if (need(AppPermissions.petsMasterDataManage)) return denied;
    }
    if (path.startsWith('/settings/catalog')) {
      if (need(AppPermissions.productsEdit)) return denied;
    }
    if (path.startsWith('/settings/printer')) {
      // Local USB TSPL config — cashiers on desktop, or anyone who can manage shop.
      final canPrinter = auth.hasPermission(AppPermissions.shopManage) ||
          (auth.hasRole(AppRoles.cashier) &&
              AppConfig.isCashierPlatform &&
              auth.hasPermission(AppPermissions.invoicesCreate));
      if (!canPrinter) return denied;
    } else if (path == '/settings' || path.startsWith('/settings/')) {
      if (path == '/settings' && need(AppPermissions.shopManage)) return denied;
      if (path.startsWith('/settings/users') && need(AppPermissions.usersView)) {
        return denied;
      }
      if (path.startsWith('/settings/branches') && need(AppPermissions.branchManage)) {
        return denied;
      }
    }
    return null;
  }

  const publicAuthRoutes = {
    '/',
    '/splash',
    '/login',
    '/register',
    '/forgot-password',
    '/pin',
    '/set-pin',
    '/cashier-desktop-only',
  };

  final updateGate = WindowsUpdateGate.instance;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: Listenable.merge([auth, updateGate]),
    initialLocation: '/splash',
    errorBuilder: (context, state) => const NotFoundScreen(),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final session = auth.hasStoredSession;
      final unlocked = auth.isUnlocked;

      // Hold on splash while update prompt/download is active.
      if (updateGate.holdsSplash && loc != '/splash') {
        return '/splash';
      }

      // Keep the branded splash visible for its full duration.
      if (loc == '/splash') return null;

      if (session && !unlocked) {
        if (loc == '/set-pin') return null;
        if (!auth.hasPinSet) {
          if (loc != '/set-pin') return '/set-pin';
        } else if (loc != '/pin') {
          return '/pin';
        }
      }

      if (!session) {
        if (!publicAuthRoutes.contains(loc) && loc != '/subscription-expired') {
          return '/';
        }
        if (loc == '/pin' || loc == '/set-pin') return '/';
      }

      if (session && unlocked && publicAuthRoutes.contains(loc)) {
        if (!auth.cashierPlatformAllowed && loc != '/cashier-desktop-only') {
          return '/cashier-desktop-only';
        }
        return auth.homeRoute;
      }

      if (session && unlocked && !auth.cashierPlatformAllowed) {
        if (loc != '/cashier-desktop-only') return '/cashier-desktop-only';
        return null;
      }

      if (session && unlocked) {
        final denied = permissionRedirect(loc);
        if (denied != null) return denied;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'Splash',
        builder: (c, s) => const VideoSplashScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'Landing',
        builder: (c, s) => const LandingScreen(),
      ),
      GoRoute(
        path: '/pin',
        name: 'PinUnlock',
        builder: (c, s) => const PinUnlockScreen(),
      ),
      GoRoute(
        path: '/set-pin',
        name: 'SetPin',
        builder: (c, s) => const SetPinScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'Login',
        builder: (c, s) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'Register',
        builder: (c, s) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'ForgotPassword',
        builder: (c, s) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/cashier-desktop-only',
        name: 'CashierDesktopOnly',
        builder: (c, s) => const CashierDesktopOnlyScreen(),
      ),
      GoRoute(
        path: '/subscription-expired',
        name: 'SubscriptionExpired',
        builder: (c, s) => const SubscriptionExpiredScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'Dashboard',
            builder: (c, s) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/pos',
            name: 'POS',
            builder: (c, s) => const PosScreen(),
          ),
          GoRoute(
            path: '/invoices',
            name: 'Invoices',
            builder: (c, s) {
              final q = s.uri.queryParameters;
              return InvoiceListScreen(
                initialDateFrom: q['date_from'],
                initialDateTo: q['date_to'],
              );
            },
          ),
          GoRoute(
            path: '/invoices/:id/return',
            name: 'InvoiceSaleReturn',
            builder: (c, s) {
              final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
              return SaleReturnFormScreen(invoiceId: id);
            },
          ),
          GoRoute(
            path: '/invoices/:id',
            name: 'InvoiceDetail',
            builder: (c, s) {
              final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
              return InvoiceDetailScreen(id: id);
            },
          ),
          GoRoute(
            path: '/products',
            name: 'Products',
            builder: (c, s) => const ProductListScreen(),
          ),
          GoRoute(
            path: '/products/new',
            name: 'ProductNew',
            builder: (c, s) => const ProductFormScreen(),
          ),
          GoRoute(
            path: '/products/:id/edit',
            name: 'ProductEdit',
            builder: (c, s) {
              final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
              return ProductFormScreen(productId: id);
            },
          ),
          GoRoute(
            path: '/inventory',
            name: 'Inventory',
            builder: (c, s) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/stock-alerts',
            name: 'StockAlerts',
            builder: (c, s) {
              final tab = s.uri.queryParameters['tab'];
              final initialTab = tab == 'expiry' ? 1 : 0;
              return StockAlertsScreen(
                key: ValueKey('stock-alerts-$initialTab'),
                initialTab: initialTab,
              );
            },
          ),
          GoRoute(
            path: '/stock-ageing',
            name: 'StockAgeing',
            builder: (c, s) => const StockAgeingScreen(),
          ),
          GoRoute(
            path: '/stock-transfers',
            name: 'StockTransfers',
            builder: (c, s) => const StockTransferListScreen(),
          ),
          GoRoute(
            path: '/stock-transfers/new',
            name: 'StockTransferNew',
            builder: (c, s) => const StockTransferFormScreen(),
          ),
          GoRoute(
            path: '/stock-transfers/:id',
            name: 'StockTransferDetail',
            builder: (c, s) {
              final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
              return StockTransferDetailScreen(id: id);
            },
          ),
          GoRoute(
            path: '/purchases',
            name: 'Purchases',
            builder: (c, s) => const PurchaseListScreen(),
          ),
          GoRoute(
            path: '/purchases/new',
            name: 'PurchaseNew',
            builder: (c, s) => const PurchaseFormScreen(),
          ),
          GoRoute(
            path: '/purchases/:id',
            name: 'PurchaseDetail',
            builder: (c, s) {
              final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
              return PurchaseDetailScreen(id: id);
            },
          ),
          GoRoute(
            path: '/purchase-returns',
            name: 'PurchaseReturns',
            builder: (c, s) => const PurchaseReturnListScreen(),
          ),
          GoRoute(
            path: '/purchase-returns/new',
            name: 'PurchaseReturnNew',
            builder: (c, s) => const PurchaseReturnFormScreen(),
          ),
          GoRoute(
            path: '/purchase-returns/:id',
            name: 'PurchaseReturnDetail',
            builder: (c, s) {
              final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
              return PurchaseReturnDetailScreen(id: id);
            },
          ),
          GoRoute(
            path: '/suppliers',
            name: 'Suppliers',
            builder: (c, s) => const SupplierListScreen(),
          ),
          GoRoute(
            path: '/customers',
            name: 'Customers',
            builder: (c, s) => const CustomerListScreen(),
          ),
          GoRoute(
            path: '/customers/new',
            name: 'CustomerNew',
            builder: (c, s) => const CustomerFormScreen(),
          ),
          GoRoute(
            path: '/customers/:id',
            name: 'CustomerDetail',
            builder: (c, s) {
              final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
              return CustomerDetailScreen(id: id);
            },
          ),
          GoRoute(
            path: '/patients',
            name: 'Patients',
            builder: (c, s) => const PatientListScreen(),
          ),
          GoRoute(
            path: '/emr/appointments',
            name: 'PatientAppointments',
            builder: (c, s) => const PatientAppointmentListScreen(),
          ),
          GoRoute(
            path: '/emr/appointments/new',
            name: 'AppointmentNew',
            builder: (c, s) => const AppointmentFormScreen(),
          ),
          GoRoute(
            path: '/emr/appointments/:id/edit',
            name: 'AppointmentEdit',
            builder: (c, s) {
              final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
              return AppointmentFormScreen(appointmentId: id);
            },
          ),
          GoRoute(
            path: '/emr/pets/:petId/timeline',
            name: 'PetTimeline',
            builder: (c, s) {
              final petId = int.tryParse(s.pathParameters['petId'] ?? '') ?? 0;
              return PetTimelineScreen(petId: petId);
            },
          ),
          GoRoute(
            path: '/emr/pets/:petId/visit-summary',
            name: 'PetVisitSummary',
            builder: (c, s) {
              final petId = int.tryParse(s.pathParameters['petId'] ?? '') ?? 0;
              return PetVisitSummaryScreen(petId: petId);
            },
          ),
          GoRoute(
            path: '/emr/pets/:petId/deworming',
            name: 'DewormingManagement',
            builder: (c, s) {
              final petId = int.tryParse(s.pathParameters['petId'] ?? '') ?? 0;
              return DewormingManagementScreen(petId: petId);
            },
          ),
          GoRoute(
            path: '/emr/pets/:petId/surgeries',
            name: 'SurgeryManagement',
            builder: (c, s) {
              final petId = int.tryParse(s.pathParameters['petId'] ?? '') ?? 0;
              return SurgeryManagementScreen(petId: petId);
            },
          ),
          GoRoute(
            path: '/emr/pets/:petId/lab-reports',
            name: 'LabReports',
            builder: (c, s) {
              final petId = int.tryParse(s.pathParameters['petId'] ?? '') ?? 0;
              return LabReportsScreen(petId: petId);
            },
          ),
          GoRoute(
            path: '/emr/pets/:petId/documents',
            name: 'PetDocuments',
            builder: (c, s) {
              final petId = int.tryParse(s.pathParameters['petId'] ?? '') ?? 0;
              return DocumentsScreen(petId: petId);
            },
          ),
          GoRoute(
            path: '/emr/visits',
            name: 'VisitList',
            builder: (c, s) => const VisitListScreen(),
          ),
          GoRoute(
            path: '/emr/visits/new',
            name: 'VisitNew',
            builder: (c, s) => VisitFormScreen(
              appointmentId: int.tryParse(
                s.uri.queryParameters['appointment_id'] ?? '',
              ),
              petId: int.tryParse(s.uri.queryParameters['pet_id'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/emr/visits/:id/edit',
            name: 'VisitEdit',
            builder: (c, s) {
              final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
              return VisitFormScreen(visitId: id);
            },
          ),
          GoRoute(
            path: '/emr/visits/:id',
            name: 'VisitDetail',
            builder: (c, s) {
              final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
              return VisitDetailScreen(visitId: id);
            },
          ),
          GoRoute(
            path: '/emr/reminders',
            name: 'Reminders',
            builder: (c, s) => const ReminderDashboardScreen(),
          ),
          GoRoute(
            path: '/expenses',
            name: 'Expenses',
            builder: (c, s) => const ExpensesScreen(),
          ),
          GoRoute(
            path: '/reports/sales',
            name: 'SalesReport',
            builder: (c, s) => const PermissionGuard(
              permission: AppPermissions.reportsView,
              child: SalesReportScreen(),
            ),
          ),
          GoRoute(
            path: '/reports/gst',
            name: 'GSTReport',
            builder: (c, s) => PermissionGuard(
              permission: AppPermissions.reportsView,
              additionalCheck: () => c.read<AuthSession>().isSuperAdmin,
              child: const GstReportScreen(),
            ),
          ),
          GoRoute(
            path: '/reports/stock-transfers',
            name: 'StockTransferReport',
            builder: (c, s) => PermissionGuard(
              permission: AppPermissions.reportsView,
              additionalCheck: () => c.read<AuthSession>().isSuperAdmin,
              child: const StockTransferReportScreen(),
            ),
          ),
          GoRoute(
            path: '/reports/visits',
            name: 'VisitReport',
            builder: (c, s) => PermissionGuard(
              permission: AppPermissions.reportsView,
              additionalCheck: () => c.read<AuthSession>().isSuperAdmin,
              child: const VisitReportScreen(),
            ),
          ),
          GoRoute(
            path: '/reports/payments',
            name: 'PaymentReport',
            builder: (c, s) => const PermissionGuard(
              permission: AppPermissions.reportsView,
              child: PaymentReportScreen(),
            ),
          ),
          GoRoute(
            path: '/reports/day-close',
            name: 'DayCloseReport',
            builder: (c, s) => const PermissionGuard(
              permission: AppPermissions.cashierDayClose,
              child: DayCloseReportScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'Settings',
            builder: (c, s) => const PermissionGuard(
              permission: AppPermissions.shopManage,
              child: SettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/security',
            name: 'AccountSecurity',
            // Every signed-in user may change their own password/PIN,
            // regardless of role or shop-management permissions.
            builder: (c, s) => const AccountSecurityScreen(),
          ),
          GoRoute(
            path: '/settings/printer',
            name: 'UsbPrinterSettings',
            builder: (c, s) => AccessGuard(
              allow: (session) =>
                  session.hasPermission(AppPermissions.shopManage) ||
                  (session.hasRole(AppRoles.cashier) &&
                      AppConfig.isCashierPlatform &&
                      session.hasPermission(AppPermissions.invoicesCreate)),
              child: const UsbPrinterSettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/users',
            name: 'Users',
            builder: (c, s) => const PermissionGuard(
              permission: AppPermissions.usersView,
              child: UsersScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/doctors',
            name: 'Doctors',
            builder: (c, s) => const PermissionGuard(
              permission: AppPermissions.doctorsManage,
              child: DoctorsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/emr-master-data',
            name: 'EmrMasterData',
            builder: (c, s) => const PermissionGuard(
              permission: AppPermissions.emrMasterDataManage,
              child: EmrMasterDataScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/species-breeds',
            name: 'PetSpeciesBreeds',
            builder: (c, s) => const PermissionGuard(
              permission: AppPermissions.petsMasterDataManage,
              child: PetSpeciesBreedMasterScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/catalog',
            name: 'Catalog',
            builder: (c, s) => const PermissionGuard(
              permission: AppPermissions.productsEdit,
              child: CatalogMasterDataScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/branches',
            name: 'Branches',
            builder: (c, s) => PermissionGuard(
              permission: AppPermissions.branchManage,
              child: BranchesScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}
