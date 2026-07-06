# Permission System Implementation Guide

This document explains how to use the new permission system in the mobile app.

## Overview

The permission system provides three layers of enforcement:

1. **Service Layer** (`PermissionService`) - Core permission checking logic
2. **UI Layer** (Guards & Extensions) - Control what users can see
3. **API Layer** (`PermissionAwareApiService`) - Control what users can do

## Quick Start

### 1. Check Permissions in Widgets

```dart
import 'core/extensions/permission_extensions.dart';
import 'core/services/permission_service.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Quick permission check
    if (!context.hasPermission(AppPermissions.posManage)) {
      return const Center(
        child: Text('You do not have access to POS'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('POS')),
      body: Column(
        children: [
          // Show button only if user has permission
          if (context.hasPermission(AppPermissions.posCreate))
            ElevatedButton(
              onPressed: () => _createOrder(),
              child: const Text('New Order'),
            ),
          
          // Show delete button only for admins
          if (context.isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteOrder(),
            ),
        ],
      ),
    );
  }
}
```

### 2. Guard Entire Screens

```dart
// Show screen only if user has permission
class POSScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: AppPermissions.posManage,
      fallback: Center(
        child: Text('POS access denied'),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Point of Sale')),
        body: _buildPOS(),
      ),
    );
  }
}
```

### 3. API-Level Permission Enforcement

```dart
class OrderService {
  final PermissionAwareApiService _api;

  OrderService(this._api);

  Future<List<Order>> getOrders() async {
    // This will throw if user doesn't have permission
    final response = await _api.get(
      '/pos/orders',
      permission: AppPermissions.posManage,
    );
    // ...
  }

  Future<Order> createOrder(OrderInput input) async {
    // API-level permission check
    final response = await _api.post(
      '/pos/orders',
      permission: AppPermissions.posCreate,
      data: input,
    );
    // ...
  }
}
```

## Permission Constants

All permissions are defined in `AppPermissions`:

```dart
// Auth & Shop
AppPermissions.shopManage
AppPermissions.usersManage
AppPermissions.rolesManage

// POS & Billing
AppPermissions.posManage
AppPermissions.billingCreate
AppPermissions.billingView
AppPermissions.billingDelete

// Inventory
AppPermissions.inventoryManage
AppPermissions.productsManage
AppPermissions.purchasesManage
AppPermissions.purchasesView

// Customers
AppPermissions.customersManage
AppPermissions.customersView

// EMR & Appointments
AppPermissions.emrManage
AppPermissions.appointmentsManage
AppPermissions.appointmentsView

// Expenses
AppPermissions.expensesManage
AppPermissions.expensesView

// Reports
AppPermissions.reportsView
AppPermissions.reportsExport

// Settings
AppPermissions.settingsView
AppPermissions.settingsEdit
```

## Role Constants

All roles are defined in `AppRoles`:

```dart
AppRoles.superAdmin        // Full access
AppRoles.shopOwner         // Shop management
AppRoles.branchManager     // Branch operations
AppRoles.cashier           // POS only
AppRoles.inventoryStaff    // Inventory management
AppRoles.accountant        // Reports & expenses
```

## Checking Permissions

### Method 1: Using Context Extension (Recommended)

```dart
// Single permission
if (context.hasPermission(AppPermissions.posManage)) {
  // show button
}

// Multiple permissions (ANY)
if (context.hasAnyPermission([
  AppPermissions.posManage,
  AppPermissions.billingCreate,
])) {
  // user has at least one
}

// Multiple permissions (ALL)
if (context.hasAllPermissions([
  AppPermissions.billingCreate,
  AppPermissions.customersManage,
])) {
  // user has all
}

// Check role
if (context.hasRole(AppRoles.branchManager)) {
  // show branch-specific features
}

// Check if super admin
if (context.isSuperAdmin) {
  // show admin panel
}
```

### Method 2: Direct Service Usage

```dart
final auth = context.authSession;

PermissionService.hasPermission(
  auth.user?.permissions ?? [],
  AppPermissions.posManage,
);

PermissionService.hasRole(
  auth.user?.roles ?? [],
  AppRoles.cashier,
);

PermissionService.isSuperAdmin(
  auth.user?.roles ?? [],
);
```

## UI Guards

### PermissionGuard - Single Permission

```dart
PermissionGuard(
  permission: AppPermissions.posManage,
  fallback: Center(child: Text('Access Denied')),
  child: POSWidget(),
)
```

### MultiPermissionGuard - Multiple Permissions

```dart
// Show if user has ANY of these permissions
MultiPermissionGuard(
  permissions: [
    AppPermissions.posManage,
    AppPermissions.billingCreate,
  ],
  requireAll: false, // default
  child: AdvancedPOSWidget(),
)

// Show if user has ALL of these permissions
MultiPermissionGuard(
  permissions: [
    AppPermissions.posManage,
    AppPermissions.inventoryManage,
  ],
  requireAll: true,
  child: AdvancedFeatureWidget(),
)
```

### RoleGuard - Single Role

```dart
RoleGuard(
  role: AppRoles.branchManager,
  child: BranchManagementScreen(),
)
```

### MultiRoleGuard - Multiple Roles

```dart
MultiRoleGuard(
  roles: [AppRoles.shopOwner, AppRoles.superAdmin],
  requireAll: false,
  child: AdminPanel(),
)
```

## Conditional Rendering

### Show/Hide Based on Permission

```dart
if (context.hasPermission(AppPermissions.posDelete)) {
  IconButton(
    icon: const Icon(Icons.delete),
    onPressed: () => _deleteItem(),
  )
}
```

### Enable/Disable Based on Permission

```dart
ElevatedButton(
  onPressed: context.hasPermission(AppPermissions.posCreate)
      ? () => _createItem()
      : null,
  child: const Text('Create Item'),
)
```

### Theme Based on Permission

```dart
TextButton(
  onPressed: () => _deleteItem(),
  style: TextButton.styleFrom(
    foregroundColor: context.hasPermission(AppPermissions.posDelete)
        ? Colors.red
        : Colors.grey,
  ),
  child: const Text('Delete'),
)
```

## Error Handling

### Show Permission Denied Snackbar

```dart
if (!context.hasPermission(AppPermissions.posCreate)) {
  context.showPermissionDenied(
    message: 'You need permission to create orders',
  );
  return;
}
```

### Show Permission Denied Dialog

```dart
if (!context.hasPermission(AppPermissions.invoicesDelete)) {
  await context.showPermissionDeniedDialog(
    title: 'Cannot Delete',
    message: 'You do not have permission to delete invoices',
  );
  return;
}
```

## API-Level Enforcement

### Using PermissionAwareApiService

First, initialize the service:

```dart
// In your app's service setup
final permissionAwareApi = PermissionAwareApiService(
  apiClient: apiClient,
  getPermissions: () => authSession.user?.permissions ?? [],
  onPermissionDenied: () {
    // Handle permission denial
    print('Permission denied');
  },
);
```

Then use it in your repository/service:

```dart
class OrderRepository {
  final PermissionAwareApiService api;

  Future<List<Order>> getOrders() async {
    final response = await api.get(
      '/pos/orders',
      permission: ApiEndpointPermissions.posList,
    );
    return parseOrders(response.data);
  }

  Future<Order> createOrder(OrderInput input) async {
    final response = await api.post(
      '/pos/orders',
      permission: ApiEndpointPermissions.posCreate,
      data: input.toMap(),
    );
    return Order.fromJson(response.data);
  }

  Future<void> deleteOrder(int id) async {
    await api.delete(
      '/pos/orders/$id',
      permission: ApiEndpointPermissions.posDelete,
    );
  }
}
```

### Check Without Making Request

```dart
// Check if we can make a request before showing UI
if (api.canAccess(ApiEndpointPermissions.posCreate)) {
  // Show create button
}

// Check if we have ANY permission
if (api.canAccessAny([
  ApiEndpointPermissions.posCreate,
  ApiEndpointPermissions.posUpdate,
])) {
  // Show edit button
}

// Check if we have ALL permissions
if (api.canAccessAll([
  ApiEndpointPermissions.posCreate,
  ApiEndpointPermissions.customersManage,
])) {
  // Show advanced feature
}
```

## Integration Checklist

- [ ] Add PermissionService to all screens that show/hide features
- [ ] Wrap sensitive screens with PermissionGuard
- [ ] Add permission checks before delete operations
- [ ] Add permission checks before create/update operations
- [ ] Use context.showPermissionDenied for error handling
- [ ] Update all API services to use PermissionAwareApiService
- [ ] Test each role (super_admin, shop_owner, branch_manager, cashier, inventory_staff, accountant)
- [ ] Verify permission denied flows
- [ ] Update error logs to include permission failures

## Testing Permissions

### Test All Roles

1. Login as Super Admin - should see all features
2. Login as Shop Owner - should see shop management features
3. Login as Branch Manager - should see branch operations
4. Login as Cashier - should only see POS
5. Login as Inventory Staff - should only see inventory
6. Login as Accountant - should only see reports/expenses

### Test Permission Enforcement

1. Try to access restricted feature
2. Should see permission denied message
3. API calls should fail with 403
4. Restricted buttons should be disabled/hidden

## Best Practices

1. **Always check permissions before showing UI** - Use guards and conditions
2. **Enforce at API level** - Use PermissionAwareApiService
3. **Show clear error messages** - Help users understand why they can't do something
4. **Log permission failures** - For debugging and security monitoring
5. **Cache permissions locally** - Permissions come from backend auth response
6. **Test all roles** - Make sure each role works correctly
7. **Document custom permissions** - If adding new ones
8. **Use AppPermissions constants** - Don't hardcode permission strings

## Migration Guide

To add permissions to existing screens:

1. Find all places that show/hide UI based on user role
2. Replace with `context.hasPermission(AppPermissions.xxx)`
3. Replace any hardcoded role checks with `context.hasRole(AppRoles.xxx)`
4. Add PermissionGuard to protected screens
5. Update API calls to use PermissionAwareApiService
6. Test with all roles

Example:

```dart
// Before
if (user?.role == 'branch_manager') {
  // show feature
}

// After
if (context.hasRole(AppRoles.branchManager)) {
  // show feature
}

// Even better - use specific permission
if (context.hasPermission(AppPermissions.inventoryManage)) {
  // show feature
}
```

---

**Status**: Ready for integration  
**Files Created**: 4  
**Lines of Code**: 600+
