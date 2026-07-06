# Integration Guide - Wiring Services into Existing Screens

This guide shows how to integrate all the new services into your existing Flutter screens.

---

## 🚀 Quick Start

### 1. Update main.dart

Replace your current main.dart with integration patterns from `main_integrated.dart`:

```dart
import 'core/di/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authSession = AuthSession();
  await authSession.restore();

  // Initialize all services
  await ServiceLocator.init(authSession);

  runApp(MyApp(authSession: authSession));
}
```

### 2. Access Services Anywhere

```dart
// In any widget or service
final customerService = ServiceLocator.customerService;
final invoiceService = ServiceLocator.invoiceService;
final cacheService = ServiceLocator.cacheService;
```

---

## 📋 Screen Integration Examples

### Example 1: Update Customer List Screen

**Before** (without new services):
```dart
class CustomerListScreen extends StatefulWidget {
  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<Customer> customers = [];
  
  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    // Manual API call
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: ListView.builder(
        itemCount: customers.length,
        itemBuilder: (context, index) {
          return ListTile(title: Text(customers[index].name));
        },
      ),
    );
  }
}
```

**After** (with new services):
```dart
class CustomerListScreen extends StatefulWidget {
  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<Customer> customers = [];
  String searchQuery = '';
  late final CustomerService _customerService;
  
  @override
  void initState() {
    super.initState();
    _customerService = ServiceLocator.customerService;
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      // Check permission first
      if (!context.hasPermission(AppPermissions.customersView)) {
        context.showPermissionDenied();
        return;
      }

      // Use cache for performance
      final customers = await ServiceLocator.cacheService.getOrLoad(
        key: 'customers:search:$searchQuery',
        loader: () => _customerService.searchCustomers(query: searchQuery),
        ttl: Duration(minutes: 5),
      );

      setState(() {
        this.customers = customers;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _addCustomer() async {
    // Check permission
    if (!context.hasPermission(AppPermissions.customersManage)) {
      await context.showPermissionDeniedDialog();
      return;
    }

    final newCustomer = await _customerService.createCustomer(
      name: 'John Doe',
      phone: '+91 98765 43210',
      email: 'john@example.com',
    );

    // Invalidate cache
    ServiceLocator.cacheService.invalidatePattern('customers:*');

    _loadCustomers();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: AppPermissions.customersView,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customers'),
          actions: [
            if (context.hasPermission(AppPermissions.customersManage))
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addCustomer,
              ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                  _loadCustomers();
                },
                decoration: InputDecoration(
                  hintText: 'Search customers...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            // Customer list
            Expanded(
              child: customers.isEmpty
                  ? const Center(child: Text('No customers found'))
                  : ListView.builder(
                      itemCount: customers.length,
                      itemBuilder: (context, index) {
                        final customer = customers[index];
                        return ListTile(
                          title: Text(customer.name),
                          subtitle: Text(customer.phone),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                child: const Text('Edit'),
                                onTap: () => _editCustomer(customer),
                              ),
                              PopupMenuItem(
                                child: const Text('Delete'),
                                enabled: context.hasPermission(
                                  AppPermissions.customersManage,
                                ),
                                onTap: () => _deleteCustomer(customer.id),
                              ),
                            ],
                          ),
                          onTap: () => _viewCustomerDetail(customer),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCustomer(Customer customer) async {
    // Navigate to edit screen
  }

  Future<void> _deleteCustomer(int id) async {
    if (!context.hasPermission(AppPermissions.customersManage)) {
      context.showPermissionDenied();
      return;
    }

    try {
      await _customerService.deleteCustomer(id);
      ServiceLocator.cacheService.invalidatePattern('customers:*');
      _loadCustomers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _viewCustomerDetail(Customer customer) async {
    // Navigate to detail screen
  }
}
```

---

### Example 2: Update POS Screen

**Integrate Advanced POS**:
```dart
class POSScreen extends StatefulWidget {
  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  late final AdvancedPosService _posService;
  late final InvoiceService _invoiceService;
  
  @override
  void initState() {
    super.initState();
    _posService = ServiceLocator.advancedPosService;
    _invoiceService = ServiceLocator.invoiceService;
  }

  Future<void> _checkout() async {
    if (!context.hasPermission(AppPermissions.posManage)) {
      context.showPermissionDenied();
      return;
    }

    try {
      // Create invoice from cart
      final invoice = await _invoiceService.createInvoice(
        customerId: null,
        invoiceDate: DateTime.now().toIso8601String(),
        items: _posService.cart.cast<InvoiceItem>(),
        totalAmount: _posService.getCartTotal(),
        subtotal: _posService.getCartSubtotal(),
        discountAmount: _posService.getCartDiscount(),
        cgstAmount: 0,
        sgstAmount: 0,
        igstAmount: 0,
        totalGst: 0,
        paidAmount: _posService.getCartTotal(),
        dueAmount: 0,
      );

      // Print receipt
      await ThermalPrinterService.printReceipt(
        invoice: invoice,
        items: _posService.cart.cast<InvoiceItem>(),
        shopName: 'My Pet Shop',
      );

      // Clear cart
      _posService.clearCart();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice created successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: AppPermissions.posManage,
      child: Scaffold(
        appBar: AppBar(title: const Text('Point of Sale')),
        body: Column(
          children: [
            // Cart items
            Expanded(
              child: ListView.builder(
                itemCount: _posService.cart.length,
                itemBuilder: (context, index) {
                  final item = _posService.cart[index];
                  return ListTile(
                    title: Text(item.productName),
                    subtitle: Text('Qty: ${item.quantity}'),
                    trailing: Text('₹${item.totalAmount}'),
                  );
                },
              ),
            ),
            // Totals and checkout
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Subtotal: ₹${_posService.getCartSubtotal()}'),
                  Text('Discount: ₹${_posService.getCartDiscount()}'),
                  Text('Total: ₹${_posService.getCartTotal()}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: _checkout,
                    child: const Text('Checkout'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Example 3: Update Settings Screen

**Integrate Settings Management**:
```dart
class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsService _settingsService;
  late final BackupRestoreService _backupService;
  late ShopSettings _shopSettings;
  late AppPreferences _preferences;

  @override
  void initState() {
    super.initState();
    _settingsService = ServiceLocator.settingsService;
    _backupService = ServiceLocator.backupRestoreService;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      _shopSettings = await _settingsService.getShopSettings();
      _preferences = _settingsService.getAppPreferences();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _createBackup() async {
    try {
      final backup = await _backupService.createBackup(
        description: 'Manual backup - ${DateTime.now()}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup created: ${backup.fileName}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: AppPermissions.settingsView,
      child: ResponsiveBuilder(
        mobileBuilder: (_) => _buildMobileSettings(),
        desktopBuilder: (_) => _buildDesktopSettings(),
      ),
    );
  }

  Widget _buildMobileSettings() {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Shop Name'),
            subtitle: Text(_shopSettings.name),
          ),
          ListTile(
            title: const Text('Theme'),
            trailing: DropdownButton<String>(
              value: _preferences.theme,
              items: const [
                DropdownMenuItem(value: 'light', child: Text('Light')),
                DropdownMenuItem(value: 'dark', child: Text('Dark')),
                DropdownMenuItem(value: 'system', child: Text('System')),
              ],
              onChanged: (value) async {
                if (value != null) {
                  await _settingsService.updateAppPreferences(theme: value);
                  _loadSettings();
                }
              },
            ),
          ),
          if (context.hasPermission(AppPermissions.settingsEdit))
            ListTile(
              title: const Text('Create Backup'),
              onTap: _createBackup,
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopSettings() {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Row(
        children: [
          // Left sidebar navigation
          SizedBox(
            width: 250,
            child: ListView(
              children: [
                ListTile(
                  title: const Text('Shop Settings'),
                  onTap: () {},
                ),
                ListTile(
                  title: const Text('Notifications'),
                  onTap: () {},
                ),
                ListTile(
                  title: const Text('Backup & Restore'),
                  onTap: () {},
                ),
              ],
            ),
          ),
          // Right content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shop Settings',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    decoration: InputDecoration(
                      label: const Text('Shop Name'),
                      initialValue: _shopSettings.name,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### Example 4: Add Responsive Layout to Dashboard

**Update Dashboard Screen**:
```dart
class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobileBuilder: (_) => _buildMobileDashboard(),
      tabletBuilder: (_) => _build TabletDashboard(),
      desktopBuilder: (_) => _buildDesktopDashboard(),
    );
  }

  Widget _buildMobileDashboard() {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildKPICard('Total Revenue', '₹50,000'),
            _buildKPICard('Total Orders', '125'),
            _buildKPICard('Pending Invoices', '12'),
            _buildKPICard('Low Stock Items', '5'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletDashboard() {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
          ),
          children: [
            _buildKPICard('Total Revenue', '₹50,000'),
            _buildKPICard('Total Orders', '125'),
            _buildKPICard('Pending Invoices', '12'),
            _buildKPICard('Low Stock Items', '5'),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopDashboard() {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          children: [
            _buildKPICard('Total Revenue', '₹50,000'),
            _buildKPICard('Total Orders', '125'),
            _buildKPICard('Pending Invoices', '12'),
            _buildKPICard('Low Stock Items', '5'),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(title, style: const TextStyle(fontSize: 14)),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🔌 Integration Checklist

### Permissions
- [ ] Add `PermissionGuard` to protected screens
- [ ] Use `context.hasPermission()` for conditional rendering
- [ ] Use `context.showPermissionDenied()` for error messages
- [ ] Check permissions before API calls

### Services
- [ ] Import ServiceLocator in screens
- [ ] Initialize services in main.dart
- [ ] Use lazy loading pattern with cache
- [ ] Invalidate cache after mutations

### Cache
- [ ] Wrap API calls with `cacheService.getOrLoad()`
- [ ] Set appropriate TTL values
- [ ] Invalidate cache after mutations
- [ ] Monitor cache statistics

### Responsive
- [ ] Wrap screens with `ResponsiveBuilder`
- [ ] Implement mobile, tablet, desktop views
- [ ] Add keyboard shortcuts for desktop
- [ ] Test on multiple screen sizes

### Backup
- [ ] Add backup UI in settings
- [ ] Configure auto-backup schedule
- [ ] Add restore functionality
- [ ] Test backup/restore workflow

---

## 🎯 Common Integration Patterns

### 1. Load Data with Cache
```dart
final data = await ServiceLocator.cacheService.getOrLoad(
  key: CacheKeys.customer(id),
  loader: () => ServiceLocator.customerService.getCustomer(id),
  ttl: Duration(hours: 1),
);
```

### 2. Check Permission
```dart
if (!context.hasPermission(AppPermissions.posManage)) {
  await context.showPermissionDeniedDialog();
  return;
}
```

### 3. Create and Cache
```dart
final customer = await service.createCustomer(...);
ServiceLocator.cacheService.invalidatePattern('customers:*');
```

### 4. Responsive Layout
```dart
ResponsiveBuilder(
  mobileBuilder: (_) => MobileView(),
  tabletBuilder: (_) => TabletView(),
  desktopBuilder: (_) => DesktopView(),
)
```

### 5. Keyboard Shortcuts
```dart
KeyboardShortcutHandler(
  shortcuts: {
    ShortcutKey.ctrl(LogicalKeyboardKey.keyS): () => save(),
  },
  child: MyWidget(),
)
```

---

## 📱 Testing Integration

### Unit Tests
```dart
test('CustomerService integration', () async {
  final service = ServiceLocator.customerService;
  final customer = await service.getCustomer(1);
  expect(customer, isNotNull);
});
```

### Widget Tests
```dart
testWidgets('PermissionGuard blocks unauthorized', (tester) async {
  // Setup auth with no permissions
  await tester.pumpWidget(TestApp());
  expect(find.text('Access Denied'), findsOneWidget);
});
```

### Integration Tests
```dart
test('Cache service integration', () async {
  final cache = ServiceLocator.cacheService;
  cache.set('test', 'value', ttl: Duration(minutes: 1));
  expect(cache.get('test'), equals('value'));
});
```

---

## 🚀 Next Steps

1. **Phase 1**: Update main.dart and initialize services
2. **Phase 2**: Update existing screens with new services
3. **Phase 3**: Add responsive layouts and keyboard shortcuts
4. **Phase 4**: Implement caching for key screens
5. **Phase 5**: Add settings and backup UI
6. **Phase 6**: Comprehensive testing
7. **Phase 7**: Deploy to stores

---

**Ready to integrate!** Start with main.dart, then update screens one by one.
