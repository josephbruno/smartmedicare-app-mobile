import 'core/network/api_client.dart';
import 'data/services/device_token_service.dart';
import 'data/services/auth_service.dart';
import 'data/services/billing_service.dart';
import 'data/services/cashier_cash_session_service.dart';
import 'data/services/customer_service.dart';
import 'data/services/doctor_service.dart';
import 'data/services/emr_service.dart';
import 'data/services/expense_service.dart';
import 'data/services/inventory_service.dart';
import 'data/services/product_service.dart';
import 'data/services/purchase_service.dart';
import 'data/services/reports_service.dart';
import 'data/services/emr_master_data_service.dart';
import 'data/services/settings_service.dart';

/// Centralized API services (constructed once per app).
class AppServices {
  AppServices(this.api)
      : auth = AuthService(api),
        billing = BillingService(api),
        cashierCash = CashierCashSessionService(api),
        products = ProductService(api),
        customers = CustomerService(api),
        inventory = InventoryService(api),
        purchases = PurchaseService(api),
        purchaseReturns = PurchaseReturnService(api),
        suppliers = SupplierService(api),
        expenses = ExpenseService(api),
        emr = EmrService(api),
        emrMasterData = EmrMasterDataService(api),
        doctors = DoctorService(api),
        reports = ReportsService(api),
        shop = ShopService(api),
        branches = BranchService(api),
        users = UsersService(api),
        deviceTokens = DeviceTokenService(api);

  final ApiClient api;
  final AuthService auth;
  final BillingService billing;
  final CashierCashSessionService cashierCash;
  final ProductService products;
  final CustomerService customers;
  final InventoryService inventory;
  final PurchaseService purchases;
  final PurchaseReturnService purchaseReturns;
  final SupplierService suppliers;
  final ExpenseService expenses;
  final EmrService emr;
  final EmrMasterDataService emrMasterData;
  final DoctorService doctors;
  final ReportsService reports;
  final ShopService shop;
  final BranchService branches;
  final UsersService users;
  final DeviceTokenService deviceTokens;
}
