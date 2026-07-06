import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../session/auth_session.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/landing_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/pin_unlock_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/set_pin_screen.dart';
import '../../features/auth/subscription_expired_screen.dart';
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
import '../../features/emr/reminder_dashboard_screen.dart';
import '../../features/emr/surgery_management_screen.dart';
import '../../features/emr/visit_detail_screen.dart';
import '../../features/emr/visit_form_screen.dart';
import '../../features/emr/visit_list_screen.dart';
import '../../features/expenses/expenses_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/inventory/stock_ageing_screen.dart';
import '../../features/inventory/stock_transfer_detail_screen.dart';
import '../../features/inventory/stock_transfer_form_screen.dart';
import '../../features/inventory/stock_transfer_list_screen.dart';
import '../../features/invoices/invoice_detail_screen.dart';
import '../../features/invoices/invoice_list_screen.dart';
import '../../features/pos/pos_screen.dart';
import '../../features/products/product_form_screen.dart';
import '../../features/products/product_list_screen.dart';
import '../../features/purchases/purchase_detail_screen.dart';
import '../../features/purchases/purchase_form_screen.dart';
import '../../features/purchases/purchase_list_screen.dart';
import '../../features/purchases/supplier_list_screen.dart';
import '../../features/reports/gst_report_screen.dart';
import '../../features/reports/sales_report_screen.dart';
import '../../features/settings/branches_screen.dart';
import '../../features/settings/doctors_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/users_screen.dart';
import '../../features/shell/app_shell.dart';

GoRouter createAppRouter({
  required AuthSession auth,
  required GlobalKey<NavigatorState> rootNavigatorKey,
}) {
  String? permissionRedirect(String path) {
    bool need(String perm) => !auth.hasPermission(perm);

    if (path.startsWith('/pos')) {
      if (need('invoices.create')) return '/dashboard';
    }
    if (path.startsWith('/invoices')) {
      if (need('invoices.view')) return '/dashboard';
    }
    if (path.startsWith('/products')) {
      if (need('products.view')) return '/dashboard';
    }
    if (path.startsWith('/stock-transfers')) {
      if (need('inventory.transfer')) return '/dashboard';
    }
    if (path.startsWith('/inventory') || path.startsWith('/stock-ageing')) {
      if (need('inventory.view')) return '/dashboard';
    }
    if (path.startsWith('/purchases')) {
      if (need('purchases.view')) return '/dashboard';
    }
    if (path.startsWith('/suppliers')) {
      if (need('suppliers.view')) return '/dashboard';
    }
    if (path.startsWith('/customers')) {
      if (need('customers.view')) return '/dashboard';
    }
    if (path.startsWith('/patients')) {
      if (need('customers.view')) return '/dashboard';
    }
    if (path.startsWith('/emr/appointments')) {
      if (path.endsWith('/new')) {
        if (need('patient_appointments.create')) return '/dashboard';
      } else if (path.contains('/edit')) {
        if (need('patient_appointments.edit')) return '/dashboard';
      } else if (need('patient_appointments.view')) {
        return '/dashboard';
      }
    }
    if (path.startsWith('/emr/pets/')) {
      if (path.contains('/deworming') && need('emr.deworming.view')) {
        return '/dashboard';
      }
      if (path.contains('/surgeries') && need('emr.surgeries.view')) {
        return '/dashboard';
      }
      if (path.contains('/lab-reports') && need('emr.lab_reports.view')) {
        return '/dashboard';
      }
      if (path.contains('/documents') && need('emr.documents.view')) {
        return '/dashboard';
      }
      if (path.contains('/timeline') && need('emr.visits.view')) {
        return '/dashboard';
      }
    }
    if (path.startsWith('/emr/visits')) {
      if (path.endsWith('/new')) {
        if (need('emr.visits.create')) return '/dashboard';
      } else if (path.contains('/edit')) {
        if (need('emr.visits.edit')) return '/dashboard';
      } else if (need('emr.visits.view')) {
        return '/dashboard';
      }
    }
    if (path.startsWith('/emr/reminders')) {
      if (need('emr.reminders.view')) return '/dashboard';
    }
    if (path.startsWith('/expenses')) {
      if (need('expenses.view')) return '/dashboard';
    }
    if (path.startsWith('/reports')) {
      if (need('reports.view')) return '/dashboard';
    }
    if (path.startsWith('/settings/doctors')) {
      if (need('doctors.manage')) return '/dashboard';
    }
    if (path == '/settings' || path.startsWith('/settings/')) {
      if (path == '/settings' && need('shop.manage')) return '/dashboard';
      if (path.startsWith('/settings/users') && need('users.view')) {
        return '/dashboard';
      }
      if (path.startsWith('/settings/branches') && need('branch.manage')) {
        return '/dashboard';
      }
    }
    return null;
  }

  const publicAuthRoutes = {
    '/',
    '/login',
    '/register',
    '/forgot-password',
    '/pin',
    '/set-pin',
  };

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: auth,
    initialLocation: '/',
    errorBuilder: (context, state) => const NotFoundScreen(),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final session = auth.hasStoredSession;
      final unlocked = auth.isUnlocked;

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
        return '/dashboard';
      }

      if (session && unlocked) {
        final denied = permissionRedirect(loc);
        if (denied != null) return denied;
      }
      return null;
    },
    routes: [
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
            builder: (c, s) => const InvoiceListScreen(),
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
            builder: (c, s) => const SalesReportScreen(),
          ),
          GoRoute(
            path: '/reports/gst',
            name: 'GSTReport',
            builder: (c, s) => const GstReportScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'Settings',
            builder: (c, s) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/users',
            name: 'Users',
            builder: (c, s) => const UsersScreen(),
          ),
          GoRoute(
            path: '/settings/doctors',
            name: 'Doctors',
            builder: (c, s) => const DoctorsScreen(),
          ),
          GoRoute(
            path: '/settings/branches',
            name: 'Branches',
            builder: (c, s) => const BranchesScreen(),
          ),
        ],
      ),
    ],
  );
}
