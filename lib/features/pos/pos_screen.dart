import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/core/messaging/app_messenger.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/connectivity/connectivity_notifier.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/session/auth_session.dart';
import '../emr/widgets/visit_billing_queue_panel.dart';
import '../../data/local/offline_invoice_queue.dart';
import '../../data/local/product_local_dao.dart';
import '../../data/local/sync_coordinator.dart';
import '../../data/repositories/pos_product_repository.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';
import '../../data/models/invoice.dart';
import '../../core/theme/app_theme.dart';
import 'pos_cart_notifier.dart';
import 'pos_checkout_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  List<Product> _hits = [];
  bool _searching = false;
  String? _searchError;
  Timer? _searchDebounce;
  int _localCatalogCount = 0;
  SyncCoordinator? _syncCoordinator;
  bool _loadingVisit = false;
  String? _loadedVisitNumber;
  int? _lastLoadedVisitId;

  Future<void> _runSearch(String q, {bool immediate = false}) async {
    _searchDebounce?.cancel();
    if (!immediate) {
      _searchDebounce = Timer(const Duration(milliseconds: 180), () {
        unawaited(_executeSearch(q));
      });
      return;
    }
    await _executeSearch(q);
  }

  Future<void> _executeSearch(String q) async {
    final auth = context.read<AuthSession>();
    final branchId = auth.currentBranchId;
    if (branchId == null) return;

    final online = context.read<ConnectivityNotifier>().isOnline;
    final repo = context.read<PosProductRepository>();

    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final list = await repo.search(branchId, q, online: online);
      if (!mounted) return;
      setState(() {
        _hits = list;
        _localCatalogCount = list.length;
      });
    } catch (e) {
      if (mounted) setState(() => _searchError = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onSearchFocusChanged() {
    if (_searchFocus.hasFocus) {
      unawaited(_runSearch(_search.text, immediate: true));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCoordinator ??= context.read<SyncCoordinator>();
    final visitIdStr = GoRouterState.of(context).uri.queryParameters['visit_id'];
    final visitId = int.tryParse(visitIdStr ?? '');
    if (visitId != null && visitId != _lastLoadedVisitId && !_loadingVisit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadVisitFromQuery());
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onSearchFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthSession>();
      final branchId = auth.currentBranchId;
      if (branchId != null) {
        _syncCoordinator ??= context.read<SyncCoordinator>();
        _syncCoordinator!.startPosSyncLoop(branchId);
        unawaited(_refreshLocalCatalogCount(branchId));
      }
      if (useWebLikeShell(context)) {
        _searchFocus.requestFocus();
      }
      unawaited(_loadVisitFromQuery());
    });
  }

  Future<void> _loadVisitFromQuery() async {
    final visitIdStr = GoRouterState.of(context).uri.queryParameters['visit_id'];
    final visitId = int.tryParse(visitIdStr ?? '');
    if (visitId == null) return;
    if (_loadingVisit || visitId == _lastLoadedVisitId) return;

    setState(() => _loadingVisit = true);
    final services = context.read<AppServices>();
    final cart = context.read<PosCartNotifier>();
    final auth = context.read<AuthSession>();
    final branchId = auth.currentBranchId;
    final online = context.read<ConnectivityNotifier>().isOnline;
    final productRepo = context.read<PosProductRepository>();

    try {
      final visit = await services.emr.getVisit(visitId);
      if (!mounted) return;

      if (visit.status != 'completed') {
        AppMessenger.show(
          context,
          SnackBar(
            content: Text(
              visit.status == 'bill_on_hold'
                  ? 'Visit ${visit.visitNumber} is still on hold — doctor must send to cashier first.'
                  : 'Visit ${visit.visitNumber} is not ready for billing (${visit.status}).',
            ),
          ),
        );
        return;
      }

      Future<Product?> fetchProduct(int productId) async {
        if (productId <= 0) return null;
        try {
          return await services.products.get(productId);
        } catch (_) {
          if (branchId == null) return null;
          final local = await productRepo.search(branchId, '', online: online);
          for (final p in local) {
            if (p.id == productId) return p;
          }
          try {
            final bySku = await services.products.findByBarcode('SVC-CONSULT');
            if (bySku?.id == productId) return bySku;
          } catch (_) {}
          return null;
        }
      }

      Future<Product?> fetchDefaultServiceProduct() async {
        if (visit.serviceChargeProduct != null) return visit.serviceChargeProduct;
        if (visit.serviceChargeProductId != null && visit.serviceChargeProductId! > 0) {
          final p = await fetchProduct(visit.serviceChargeProductId!);
          if (p != null) return p;
        }
        try {
          final byBarcode = await services.products.findByBarcode('SVC-CONSULT');
          if (byBarcode != null) return byBarcode;
        } catch (_) {}
        try {
          final list = await services.products.list(
            query: {'type': 'service', 'per_page': 10, 'search': 'consult'},
          );
          if (list.isNotEmpty) return list.first;
        } catch (_) {}
        try {
          final list = await services.products.list(
            query: {'type': 'service', 'per_page': 5},
          );
          return list.isNotEmpty ? list.first : null;
        } catch (_) {
          return null;
        }
      }

      final result = await cart.loadFromVisit(
        visit,
        fetchProduct,
        fetchDefaultServiceProduct: fetchDefaultServiceProduct,
      );
      if (!mounted) return;
      _lastLoadedVisitId = visitId;

      if (visit.customerId > 0) {
        try {
          final customer = await services.customers.get(visit.customerId);
          if (mounted) cart.setCustomer(customer);
        } catch (_) {}
      }

      if (!result.success) {
        AppMessenger.show(
          context,
          SnackBar(
            content: Text(
              result.skipped.isEmpty
                  ? 'No billable items with products on visit ${visit.visitNumber}.'
                  : 'Could not load items: ${result.skipped.join(', ')}',
            ),
          ),
        );
        return;
      }

      setState(() => _loadedVisitNumber = visit.visitNumber);
      if (result.skipped.isNotEmpty) {
        AppMessenger.show(
          context,
          SnackBar(
            content: Text(
              'Loaded ${result.linesAdded} item(s) from ${visit.visitNumber}. Skipped: ${result.skipped.join(', ')}',
            ),
          ),
        );
      } else {
        AppMessenger.show(
          context,
          SnackBar(
            content: Text('Loaded ${result.linesAdded} item(s) from visit ${visit.visitNumber}.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('Failed to load visit: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingVisit = false);
    }
  }

  Future<void> _onSearchSubmitted(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;

    final auth = context.read<AuthSession>();
    final branchId = auth.currentBranchId;
    final online = context.read<ConnectivityNotifier>().isOnline;
    final repo = context.read<PosProductRepository>();
    final cart = context.read<PosCartNotifier>();

    if (!q.contains(' ') && q.length >= 4 && branchId != null) {
      final product = await repo.findByBarcode(branchId, q, online: online);
      if (product != null && mounted) {
        final msg = cart.addProduct(product);
        _search.clear();
        if (msg != 'added' && msg != 'incremented') {
          AppMessenger.show(
            context,
            SnackBar(
              content: Text(
                msg == 'out_of_stock' ? 'Out of stock!' : 'Maximum stock capacity reached.',
              ),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
        _searchFocus.requestFocus();
        return;
      }
    }

    await _runSearch(q, immediate: true);
  }

  Future<void> _refreshLocalCatalogCount(int branchId) async {
    final count = await context.read<PosProductRepository>().localCount(branchId);
    if (mounted) setState(() => _localCatalogCount = count);
  }

  Future<void> _editCartLinePrice(PosCartNotifier cart, int index) async {
    final item = cart.items[index];
    final controller = TextEditingController(text: item.unitPrice.toStringAsFixed(2));
    final updated = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.isServiceCharge ? 'Edit service charge' : 'Edit price'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount (₹)',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v == null || v < 0) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated != null && mounted) {
      cart.updateUnitPrice(index, updated);
    }
  }

  Future<void> _checkout() async {
    final cart = context.read<PosCartNotifier>();
    if (cart.items.isEmpty) return;
    final online = context.read<ConnectivityNotifier>().isOnline;
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final payload = cart.buildCreateInvoicePayload(invoiceDate: date);
    payload.remove('payments');

    final printItems = cart.items
        .map(
          (c) => InvoiceItem(
            id: 0,
            productId: c.productId,
            productName: c.productName,
            quantity: c.quantity.toDouble(),
            unitPrice: c.unitPrice,
            totalAmount: c.totalAmount,
          ),
        )
        .toList();

    final completed = await showPosCheckoutDialog(
      context: context,
      services: context.read<AppServices>(),
      auth: context.read<AuthSession>(),
      invoicePayload: payload,
      grandTotal: cart.grandTotal,
      printItems: printItems,
      isOnline: online,
      offlineQueue: context.read<OfflineInvoiceQueue>(),
      productDao: context.read<ProductLocalDao>(),
      branchId: context.read<AuthSession>().currentBranchId,
      customerPhone: cart.customer?.phone,
    );

    if (!completed || !mounted) return;
    cart.clear();
    setState(() {
      _loadedVisitNumber = null;
      _lastLoadedVisitId = null;
    });
    final term = _search.text.trim();
    if (term.isNotEmpty) {
      await _runSearch(term, immediate: true);
    } else {
      await _runSearch('', immediate: true);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _syncCoordinator?.stopPosSyncLoop();
    _searchFocus.removeListener(_onSearchFocusChanged);
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    unawaited(_runSearch('', immediate: true));
    _searchFocus.requestFocus();
  }

  bool get _desktop => AppConfig.isDesktopPlatform;

  double _ic(double size) =>
      _desktop ? size * AppConfig.desktopIconScale : size;

  double _fs(double size) => _desktop ? size + 3 : size;

  Widget _shortcutHint(String keys, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: _desktop ? 8 : 6, vertical: _desktop ? 4 : 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(keys, style: TextStyle(fontSize: _fs(11), fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: _fs(12), color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildCartCustomerSection(PosCartNotifier cart) {
    final customer = cart.customer;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _desktop ? 14 : 12, vertical: _desktop ? 12 : 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: _desktop ? 20 : 18,
            backgroundColor: customer == null
                ? const Color(0xFFE2E8F0)
                : AppTheme.primary.withOpacity(0.12),
            child: Icon(
              customer == null ? Icons.person_outline_rounded : Icons.person_pin_rounded,
              color: customer == null ? AppTheme.textSecondary : AppTheme.primary,
              size: _ic(20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BILLING CUSTOMER',
                  style: TextStyle(
                    fontSize: _fs(10),
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  customer?.name ?? 'Walk-in Customer',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: _fs(14),
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (customer?.phone.isNotEmpty == true)
                  Text(
                    customer!.phone,
                    style: TextStyle(fontSize: _fs(12), color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
          if (customer != null)
            IconButton(
              tooltip: 'Clear customer',
              icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: _ic(18)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => cart.setCustomer(null),
            ),
          TextButton.icon(
            onPressed: () async {
              final selected = await showSearch<Customer?>(
                context: context,
                delegate: _CustomerSearchDelegate(context.read<AppServices>()),
              );
              if (selected != null) cart.setCustomer(selected);
            },
            icon: Icon(Icons.search_rounded, size: _ic(16)),
            label: Text(customer == null ? 'Select' : 'Change', style: TextStyle(fontSize: _fs(13))),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: _desktop ? 10 : 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartHeldBillsSection(PosCartNotifier cart) {
    if (cart.heldBills.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.pause_circle_filled_rounded, color: AppTheme.warning, size: _ic(16)),
          Text(
            'Held:',
            style: TextStyle(fontSize: _fs(12), fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          for (final h in cart.heldBills)
            ActionChip(
              label: Text(h.id.split('-').last, style: TextStyle(fontSize: _fs(11))),
              visualDensity: _desktop ? VisualDensity.standard : VisualDensity.compact,
              backgroundColor: AppTheme.warning.withOpacity(0.08),
              side: const BorderSide(color: AppTheme.warning),
              labelStyle: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold, fontSize: _fs(11)),
              onPressed: () => cart.restoreHeldBill(h.id),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PosCartNotifier>();
    final auth = context.watch<AuthSession>();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final desktopShortcuts = useWebLikeShell(context);
    final showBillingQueue = desktopShortcuts && auth.hasPermission('emr.visits.bill');

    final cartPanel = Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: EdgeInsets.all(_desktop ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cart Workspace',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: _fs(18),
                      ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: _desktop ? 12 : 10, vertical: _desktop ? 6 : 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${cart.items.length} items',
                    style: TextStyle(color: AppTheme.primary, fontSize: _fs(12), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCartCustomerSection(cart),
            _buildCartHeldBillsSection(cart),
            const SizedBox(height: 12),
            Expanded(
              child: cart.items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: _ic(44), color: AppTheme.textSecondary.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          Text(
                            'Cart is empty',
                            style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: _fs(14)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select products on the left',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: _fs(12)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: cart.items.length,
                      itemBuilder: (c, i) {
                        final it = cart.items[i];
                        final billingVisit = cart.pendingVisitId != null;
                        final canEditPrice = billingVisit && it.isServiceCharge;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: _desktop ? 14 : 12, vertical: _desktop ? 12 : 10),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        it.productName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: _fs(13),
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: canEditPrice
                                            ? () => _editCartLinePrice(cart, i)
                                            : null,
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '₹${it.unitPrice.toStringAsFixed(2)} × ${it.quantity}',
                                                style: TextStyle(
                                                  fontSize: _fs(12),
                                                  color: canEditPrice
                                                      ? AppTheme.primary
                                                      : AppTheme.textSecondary,
                                                  decoration: canEditPrice
                                                      ? TextDecoration.underline
                                                      : null,
                                                ),
                                              ),
                                              if (canEditPrice) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.edit_outlined,
                                                  size: _ic(14),
                                                  color: AppTheme.primary,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Quantity counter (service charge stays qty 1)
                                if (!it.isServiceCharge)
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (it.quantity > 1) {
                                          cart.updateQuantity(i, it.quantity - 1);
                                        } else {
                                          cart.removeItem(i);
                                        }
                                      },
                                      child: Container(
                                        width: _desktop ? 42 : 32,
                                        height: _desktop ? 42 : 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(_desktop ? 10 : 6),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Icon(
                                          Icons.remove,
                                          size: _ic(_desktop ? 22 : 16),
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: _desktop ? 12 : 8),
                                      child: Text(
                                        '${it.quantity}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: _fs(_desktop ? 16 : 13),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        cart.updateQuantity(i, it.quantity + 1);
                                      },
                                      child: Container(
                                        width: _desktop ? 42 : 32,
                                        height: _desktop ? 42 : 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(_desktop ? 10 : 6),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          size: _ic(_desktop ? 22 : 16),
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                                else
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: _desktop ? 12 : 8),
                                    child: Text(
                                      'Qty 1',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: _fs(_desktop ? 14 : 12),
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                SizedBox(width: _desktop ? 14 : 12),
                                // Total
                                Text(
                                  '₹${it.totalAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: _fs(_desktop ? 16 : 13),
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                SizedBox(width: _desktop ? 4 : 6),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppTheme.danger,
                                    size: _ic(_desktop ? 26 : 20),
                                  ),
                                  iconSize: _ic(_desktop ? 26 : 20),
                                  padding: EdgeInsets.all(_desktop ? 8 : 4),
                                  constraints: BoxConstraints(
                                    minWidth: _desktop ? 48 : 36,
                                    minHeight: _desktop ? 48 : 36,
                                  ),
                                  onPressed: () => cart.removeItem(i),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 24),
            // Billing totals summary
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal', style: TextStyle(color: AppTheme.textSecondary, fontSize: _fs(13))),
                  Text(
                    '₹${cart.subtotal.toStringAsFixed(2)}',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: _fs(13)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('GST (CGST + SGST)', style: TextStyle(color: AppTheme.textSecondary, fontSize: _fs(13))),
                  Text(
                    '₹${cart.totalGst.toStringAsFixed(2)}',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: _fs(13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: EdgeInsets.all(_desktop ? 14 : 12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('GRAND TOTAL', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: _fs(14))),
                  Text(
                    '₹${cart.grandTotal.toStringAsFixed(2)}',
                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: _fs(18)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Actions Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: cart.items.isEmpty ? null : () => cart.holdBill(),
                    icon: Icon(Icons.pause_circle_outline_rounded, size: _ic(18)),
                    label: Text('Hold Bill', style: TextStyle(fontSize: _fs(14))),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: _desktop ? 14 : 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: cart.items.isEmpty ? null : _checkout,
                    icon: Icon(Icons.shopping_cart_checkout_rounded, size: _ic(18)),
                    label: Text('Checkout', style: TextStyle(fontSize: _fs(14))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: EdgeInsets.symmetric(vertical: _desktop ? 14 : 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final searchPanel = Padding(
      padding: EdgeInsets.all(_desktop ? 16 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadingVisit)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_loadedVisitNumber != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.medical_services_outlined, size: 18, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Billing visit $_loadedVisitNumber',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (showBillingQueue && !wide)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VisitBillingQueuePanel(compact: true, maxHeight: 200),
            ),
          TextField(
            controller: _search,
            focusNode: _searchFocus,
            autofocus: desktopShortcuts,
            style: TextStyle(fontSize: _fs(14)),
            decoration: InputDecoration(
              labelText: 'Search items by name, category, or barcode...',
              labelStyle: TextStyle(fontSize: _fs(14)),
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: _ic(22)),
              suffixIcon: _search.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: _ic(18)),
                      onPressed: () {
                        _search.clear();
                        unawaited(_runSearch('', immediate: true));
                        _searchFocus.requestFocus();
                      },
                    )
                  : null,
            ),
            onChanged: (v) => _runSearch(v),
            onSubmitted: _onSearchSubmitted,
            onTap: () => _runSearch(_search.text, immediate: true),
          ),
          const SizedBox(height: 8),
          if (_searching) const ClipRRect(borderRadius: BorderRadius.all(Radius.circular(4)), child: LinearProgressIndicator(minHeight: 3)),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_searchError!, style: TextStyle(color: AppTheme.danger, fontSize: _fs(13))),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _hits.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: _ic(40), color: AppTheme.textSecondary.withOpacity(0.3)),
                        const SizedBox(height: 10),
                        Text(
                          _searching ? 'Loading catalog…' : 'No matching products',
                          style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: _fs(14)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _localCatalogCount > 0
                              ? '$_localCatalogCount items in local catalog — search or tap the field'
                              : 'Syncing catalog — works offline once loaded',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: _fs(12)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _hits.length,
                    itemBuilder: (c, i) {
                      final p = _hits[i];
                      final isLowStock = (p.currentStock ?? 0) <= p.reorderLevel;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            final msg = cart.addProduct(p);
                            if (context.mounted && msg != 'added' && msg != 'incremented') {
                              AppMessenger.show(context,
                                SnackBar(
                                  content: Text(msg == 'out_of_stock' ? 'Out of stock!' : 'Maximum stock capacity reached.'),
                                  backgroundColor: AppTheme.danger,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: EdgeInsets.all(_desktop ? 14 : 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(_desktop ? 12 : 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    p.isService ? Icons.cut_rounded : Icons.pets_rounded,
                                    color: AppTheme.primary,
                                    size: _ic(22),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: _fs(14),
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '₹${p.sellingPrice.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: _fs(13),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 4,
                                            height: 4,
                                            decoration: const BoxDecoration(color: AppTheme.textSecondary, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Tax ${p.gstRate}%',
                                            style: TextStyle(color: AppTheme.textSecondary, fontSize: _fs(12)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Stock Indicator Badge
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (p.trackInventory)
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: _desktop ? 10 : 8, vertical: _desktop ? 5 : 3),
                                        decoration: BoxDecoration(
                                          color: isLowStock ? AppTheme.warning.withOpacity(0.12) : AppTheme.accent.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Stock: ${p.currentStock?.toInt() ?? 0}',
                                          style: TextStyle(
                                            color: isLowStock ? AppTheme.warning : AppTheme.accent,
                                            fontSize: _fs(11),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: _desktop ? 10 : 8, vertical: _desktop ? 5 : 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accent.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Service/Infinity',
                                          style: TextStyle(
                                            color: AppTheme.accent,
                                            fontSize: _fs(11),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: _ic(20)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    final sessionBar = Padding(
      padding: EdgeInsets.fromLTRB(_desktop ? 16 : 12, _desktop ? 10 : 8, _desktop ? 16 : 12, 0),
      child: Row(
        children: [
          Icon(Icons.store_rounded, size: _ic(16), color: AppTheme.textSecondary.withOpacity(0.8)),
          const SizedBox(width: 6),
          Text(auth.currentBranch?.name ?? 'Branch', style: TextStyle(fontWeight: FontWeight.w600, fontSize: _fs(13))),
          const SizedBox(width: 12),
          Icon(Icons.person_outline_rounded, size: _ic(16), color: AppTheme.textSecondary.withOpacity(0.8)),
          const SizedBox(width: 6),
          Text(auth.user?.name ?? 'Cashier', style: TextStyle(color: AppTheme.textSecondary, fontSize: _fs(13))),
          const Spacer(),
          Text(
            DateFormat('EEE, d MMM · HH:mm').format(DateTime.now()),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: _fs(12)),
          ),
        ],
      ),
    );

    final shortcutBar = desktopShortcuts
        ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _shortcutHint('Ctrl+B', 'Search'),
                _shortcutHint('Enter', 'Scan / search'),
                _shortcutHint('Ctrl+↵', 'Checkout'),
                _shortcutHint('Ctrl+H', 'Hold bill'),
                _shortcutHint('Ctrl+E', 'Clear cart'),
                _shortcutHint('Esc', 'Clear search'),
              ],
            ),
          )
        : const SizedBox.shrink();

    Widget body;
    if (wide) {
      body = Container(
        color: AppTheme.background,
        child: Column(
          children: [
            sessionBar,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showBillingQueue) ...[
                    SizedBox(
                      width: 280,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                        child: VisitBillingQueuePanel(compact: true),
                      ),
                    ),
                  ],
                  Expanded(flex: 3, child: searchPanel),
                  Expanded(flex: 2, child: cartPanel),
                ],
              ),
            ),
            shortcutBar,
          ],
        ),
      );
    } else {
      body = DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          body: Column(
            children: [
              const TabBar(
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Browse Products'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Review Cart'),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [searchPanel, cartPanel],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!desktopShortcuts) return body;

    return KeyboardShortcutHandler(
      shortcuts: {
        ShortcutKey.ctrl(LogicalKeyboardKey.keyB): () => _searchFocus.requestFocus(),
        ShortcutKey.ctrl(LogicalKeyboardKey.enter): () {
          if (cart.items.isNotEmpty) _checkout();
        },
        ShortcutKey.ctrl(LogicalKeyboardKey.keyE): cart.clear,
        ShortcutKey.ctrl(LogicalKeyboardKey.keyH): () {
          if (cart.items.isNotEmpty) cart.holdBill();
        },
        ShortcutKey(logicalKey: LogicalKeyboardKey.escape): _clearSearch,
      },
      child: Focus(autofocus: true, child: body),
    );
  }
}

class _CustomerSearchDelegate extends SearchDelegate<Customer?> {
  _CustomerSearchDelegate(this._services);

  final AppServices _services;

  bool get _desktop => AppConfig.isDesktopPlatform;

  double _ic(double size) =>
      _desktop ? size * AppConfig.desktopIconScale : size;

  double _fs(double size) => _desktop ? size + 3 : size;

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(onPressed: () => query = '', icon: Icon(Icons.clear, size: _ic(22))),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: Icon(Icons.arrow_back, size: _ic(24)),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _build(context);

  @override
  Widget buildSuggestions(BuildContext context) => _build(context);

  Widget _build(BuildContext context) {
    if (query.trim().length < 2) {
      return Center(child: Text('Type at least 2 characters to search...', style: TextStyle(fontSize: _fs(14))));
    }
    return FutureBuilder<List<Customer>>(
      future: _services.customers.search(query.trim()),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('${snap.error}', style: TextStyle(fontSize: _fs(14))));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return Center(child: Text('No customers found.', style: TextStyle(fontSize: _fs(14))));
        }
        return ListView.builder(
          padding: EdgeInsets.all(_desktop ? 16 : 12),
          itemCount: list.length,
          itemBuilder: (c, i) {
            final cu = list[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  padding: EdgeInsets.all(_desktop ? 10 : 8),
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), shape: BoxShape.circle),
                  child: Icon(Icons.person_rounded, color: AppTheme.primary, size: _ic(22)),
                ),
                title: Text(cu.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: _fs(15))),
                subtitle: Text(cu.phone, style: TextStyle(fontSize: _fs(13))),
                onTap: () => close(context, cu),
              ),
            );
          },
        );
      },
    );
  }
}
