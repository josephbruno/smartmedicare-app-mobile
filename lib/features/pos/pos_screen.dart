import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
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
import '../emr/visit_billing_queue_notifier.dart';
import '../emr/widgets/visit_billing_queue_panel.dart';
import '../../data/local/offline_invoice_queue.dart';
import '../../data/local/product_local_dao.dart';
import '../../data/local/sync_coordinator.dart';
import '../../data/repositories/pos_product_repository.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';
import '../../data/models/invoice.dart';
import '../../data/models/cashier_cash_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/permission_service.dart';
import 'cashier_shift_panel.dart';
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

  CashierCashSession? _cashSession;
  CashierDayStatus? _dayStatus;
  CashierSuggestedOpening? _suggestedOpening;
  bool _dayClosed = false;
  bool _loadingCashSession = false;

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
    // Avoid re-running browse on every focus; initial load + sync cover empty list.
    if (_searchFocus.hasFocus && _search.text.trim().isNotEmpty) {
      unawaited(_runSearch(_search.text, immediate: true));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = context.read<SyncCoordinator>();
    if (!identical(_syncCoordinator, sync)) {
      _syncCoordinator?.removeListener(_onSyncChanged);
      _syncCoordinator = sync;
      _syncCoordinator!.addListener(_onSyncChanged);
    }
    final visitIdStr = GoRouterState.of(context).uri.queryParameters['visit_id'];
    final visitId = int.tryParse(visitIdStr ?? '');
    if (visitId != null && visitId != _lastLoadedVisitId && !_loadingVisit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadVisitFromQuery());
      });
    }
  }

  void _onSyncChanged() {
    if (!mounted) return;
    final sync = _syncCoordinator;
    if (sync == null || sync.isSyncing) return;
    final branchId = context.read<AuthSession>().currentBranchId;
    if (branchId == null) return;
    unawaited(_executeSearch(_search.text));
    unawaited(_refreshLocalCatalogCount(branchId));
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
        _syncCoordinator!.addListener(_onSyncChanged);
        _syncCoordinator!.startPosSyncLoop(branchId);
        unawaited(_refreshLocalCatalogCount(branchId));
        // Load catalog into the list immediately (online refresh + local).
        unawaited(_executeSearch(''));
      }
      if (useWebLikeShell(context)) {
        _searchFocus.requestFocus();
      }
      unawaited(_loadVisitFromQuery());
      unawaited(_refreshCashSession());
    });
  }

  Future<void> _refreshCashSession() async {
    if (!mounted) return;
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission(AppPermissions.cashierShiftView)) return;
    final online = context.read<ConnectivityNotifier>().isOnline;
    if (!online) return;

    setState(() => _loadingCashSession = true);
    try {
      final services = context.read<AppServices>();
      final current = await services.cashierCash.current();
      CashierDayStatus? day;
      try {
        day = await services.cashierCash.dayStatus(date: current.businessDate);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _cashSession = current.session;
        _dayClosed = current.dayClosed;
        _dayStatus = day;
        _suggestedOpening = current.suggestedOpening;
      });
    } catch (_) {
      // Keep POS usable if cash-session API is unavailable.
    } finally {
      if (mounted) setState(() => _loadingCashSession = false);
    }
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
        // Prefer local POS catalog — /products/{id} often omits current_stock,
        // while the POS sync payload includes inventory quantities.
        if (branchId != null) {
          final local = await productRepo.findById(branchId, productId);
          if (local != null) return local;
        }
        try {
          return await services.products.get(productId);
        } catch (_) {
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
    final services = context.read<AppServices>();
    final auth = context.read<AuthSession>();

    if (online &&
        auth.hasPermission(AppPermissions.cashierShiftStart) &&
        (_cashSession == null || !_cashSession!.isOpen)) {
      AppMessenger.show(
        context,
        const SnackBar(
          content: Text('Start your cash shift before checkout.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      unawaited(_refreshCashSession());
      return;
    }

    // Refresh customer so loyalty / advance balances are current at checkout.
    if (online && cart.customer != null && cart.customer!.id > 0) {
      try {
        final fresh = await services.customers.get(cart.customer!.id);
        if (mounted) cart.setCustomer(fresh);
      } catch (_) {}
    }

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
      services: services,
      auth: context.read<AuthSession>(),
      invoicePayload: payload,
      grandTotal: cart.grandTotal,
      printItems: printItems,
      isOnline: online,
      offlineQueue: context.read<OfflineInvoiceQueue>(),
      productDao: context.read<ProductLocalDao>(),
      branchId: context.read<AuthSession>().currentBranchId,
      customerPhone: cart.customer?.phone,
      customer: cart.customer,
    );

    if (!completed || !mounted) return;
    cart.clear();
    setState(() {
      _loadedVisitNumber = null;
      _lastLoadedVisitId = null;
    });
    unawaited(_refreshCashSession());
    unawaited(context.read<VisitBillingQueueNotifier>().refresh());
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
    _syncCoordinator?.removeListener(_onSyncChanged);
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
                if (customer != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (customer.advanceBalance > 0)
                        _PosBalanceChip(
                          label: 'Adv ₹${customer.advanceBalance.toStringAsFixed(0)}',
                          color: AppTheme.accent,
                          large: _desktop,
                        ),
                      if (customer.loyaltyPoints > 0)
                        _PosBalanceChip(
                          label: '${customer.loyaltyPoints} pts',
                          color: AppTheme.warning,
                          large: _desktop,
                        ),
                      if ((customer.creditLimit ?? 0) > 0)
                        _PosBalanceChip(
                          label: 'Limit ₹${customer.creditLimit!.toStringAsFixed(0)}',
                          color: AppTheme.textSecondary,
                          large: _desktop,
                        ),
                      if ((customer.outstandingBalance ?? 0) > 0)
                        _PosBalanceChip(
                          label: 'Due ₹${customer.outstandingBalance!.toStringAsFixed(0)}',
                          color: AppTheme.danger,
                          large: _desktop,
                        ),
                    ],
                  ),
                ],
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
              final auth = context.read<AuthSession>();
              final selected = await showSearch<Customer?>(
                context: context,
                delegate: _CustomerSearchDelegate(
                  context.read<AppServices>(),
                  canCreate: auth.hasPermission(AppPermissions.customersCreate),
                ),
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

    final cartPanel = Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(_desktop ? 12 : 10, _desktop ? 10 : 8, _desktop ? 12 : 10, _desktop ? 10 : 8),
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
                        fontSize: _fs(16),
                      ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: _desktop ? 10 : 8, vertical: _desktop ? 4 : 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${cart.items.length} items',
                    style: TextStyle(color: AppTheme.primary, fontSize: _fs(12), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CashierShiftPanel(
              session: _cashSession,
              dayStatus: _dayStatus,
              dayClosed: _dayClosed,
              suggestedOpening: _suggestedOpening,
              loading: _loadingCashSession,
              onRefresh: _refreshCashSession,
              compact: _desktop,
            ),
            const SizedBox(height: 8),
            _buildCartCustomerSection(cart),
            _buildCartHeldBillsSection(cart),
            const SizedBox(height: 8),
            Expanded(
              child: cart.items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: _ic(40), color: AppTheme.textSecondary.withOpacity(0.4)),
                          const SizedBox(height: 8),
                          Text(
                            'Cart is empty',
                            style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: _fs(14)),
                          ),
                          const SizedBox(height: 2),
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
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: _desktop ? 10 : 8, vertical: _desktop ? 8 : 6),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(10),
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
                                      const SizedBox(height: 2),
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
            const Divider(color: Color(0xFFE2E8F0), height: 16),
            // Billing totals summary
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
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
              padding: const EdgeInsets.symmetric(vertical: 2),
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
            const SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: _desktop ? 12 : 10,
                vertical: _desktop ? 10 : 8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
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
            const SizedBox(height: 10),
            // Actions Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: cart.items.isEmpty ? null : () => cart.holdBill(),
                    icon: Icon(Icons.pause_circle_outline_rounded, size: _ic(18)),
                    label: Text('Hold Bill', style: TextStyle(fontSize: _fs(14))),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: _desktop ? 10 : 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: cart.items.isEmpty
                        ? null
                        : () {
                            final auth = context.read<AuthSession>();
                            final online = context.read<ConnectivityNotifier>().isOnline;
                            if (online &&
                                auth.hasPermission(AppPermissions.cashierShiftStart) &&
                                (_cashSession == null || !_cashSession!.isOpen)) {
                              AppMessenger.show(
                                context,
                                const SnackBar(
                                  content: Text('Start your cash shift before checkout.'),
                                  backgroundColor: AppTheme.warning,
                                ),
                              );
                              return;
                            }
                            _checkout();
                          },
                    icon: Icon(Icons.shopping_cart_checkout_rounded, size: _ic(18)),
                    label: Text('Checkout', style: TextStyle(fontSize: _fs(14))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: EdgeInsets.symmetric(vertical: _desktop ? 10 : 8),
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
      padding: EdgeInsets.fromLTRB(_desktop ? 12 : 8, _desktop ? 10 : 8, _desktop ? 12 : 8, _desktop ? 10 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadingVisit)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_loadedVisitNumber != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              padding: const EdgeInsets.only(bottom: 6),
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
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          const SizedBox(height: 6),
          if (_searching) const ClipRRect(borderRadius: BorderRadius.all(Radius.circular(4)), child: LinearProgressIndicator(minHeight: 3)),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_searchError!, style: TextStyle(color: AppTheme.danger, fontSize: _fs(13))),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: _hits.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: _ic(36), color: AppTheme.textSecondary.withOpacity(0.3)),
                        const SizedBox(height: 8),
                        Text(
                          _searching ? 'Loading catalog…' : 'No matching products',
                          style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: _fs(14)),
                        ),
                        const SizedBox(height: 2),
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

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
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
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: _desktop ? 10 : 8,
                                vertical: _desktop ? 8 : 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    p.isService ? Icons.cut_rounded : Icons.pets_rounded,
                                    color: AppTheme.primary,
                                    size: _ic(20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: _fs(13),
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${p.sellingPrice.toStringAsFixed(2)} · Tax ${p.gstRate}%',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: _fs(12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    p.trackInventory
                                        ? 'Stock: ${p.currentStock?.toInt() ?? 0}'
                                        : 'Service',
                                    style: TextStyle(
                                      color: p.trackInventory && isLowStock
                                          ? AppTheme.warning
                                          : AppTheme.accent,
                                      fontSize: _fs(11),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: _ic(18)),
                                ],
                              ),
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
        ShortcutKey.ctrl(LogicalKeyboardKey.numpadEnter): () {
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
  _CustomerSearchDelegate(this._services, {this.canCreate = true});

  final AppServices _services;
  final bool canCreate;

  bool get _desktop => AppConfig.isDesktopPlatform;

  double _ic(double size) =>
      _desktop ? size * AppConfig.desktopIconScale : size;

  double _fs(double size) => _desktop ? size + 3 : size;

  @override
  String get searchFieldLabel => 'Search by name or phone…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: _fs(18),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: 'Clear',
            onPressed: () => query = '',
            icon: Icon(Icons.clear_rounded, size: _ic(22)),
          ),
        if (canCreate)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => _openQuickCreate(context),
              icon: Icon(Icons.person_add_alt_1_rounded, size: _ic(18)),
              label: Text(
                'New',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: _fs(13)),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: Icon(Icons.arrow_back_rounded, size: _ic(24)),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _build(context);

  @override
  Widget buildSuggestions(BuildContext context) => _build(context);

  Future<void> _openQuickCreate(BuildContext context) async {
    final created = await showDialog<Customer>(
      context: context,
      builder: (ctx) => _QuickCreateCustomerDialog(
        services: _services,
        initialQuery: query.trim(),
        desktop: _desktop,
      ),
    );
    if (created != null && context.mounted) {
      close(context, created);
    }
  }

  Widget _build(BuildContext context) {
    final q = query.trim();
    if (q.length < 2) {
      return _IdleSearchState(
        canCreate: canCreate,
        fontSize: _fs(14),
        iconSize: _ic(48),
        onCreate: () => _openQuickCreate(context),
      );
    }

    return FutureBuilder<List<Customer>>(
      future: _services.customers.search(q),
      builder: (context, snap) {
        if (snap.hasError) {
          return _MessageState(
            icon: Icons.error_outline_rounded,
            title: 'Search failed',
            subtitle: '${snap.error}',
            iconColor: AppTheme.danger,
            fontSize: _fs(14),
            iconSize: _ic(40),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = snap.data!;
        if (list.isEmpty) {
          return _EmptyResultsState(
            query: q,
            canCreate: canCreate,
            fontSize: _fs(14),
            iconSize: _ic(48),
            onCreate: () => _openQuickCreate(context),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            _desktop ? 20 : 14,
            12,
            _desktop ? 20 : 14,
            24,
          ),
          itemCount: list.length + (canCreate ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (c, i) {
            if (canCreate && i == list.length) {
              return _CreateCustomerBanner(
                query: q,
                onTap: () => _openQuickCreate(context),
                fontSize: _fs(13),
              );
            }
            final cu = list[i];
            return _CustomerResultTile(
              customer: cu,
              iconSize: _ic(22),
              fontSize: _fs(15),
              subtitleSize: _fs(13),
              onTap: () => close(context, cu),
            );
          },
        );
      },
    );
  }
}

class _IdleSearchState extends StatelessWidget {
  const _IdleSearchState({
    required this.canCreate,
    required this.fontSize,
    required this.iconSize,
    required this.onCreate,
  });

  final bool canCreate;
  final double fontSize;
  final double iconSize;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize + 28,
                height: iconSize + 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.person_search_rounded,
                  size: iconSize,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Find a customer',
                style: TextStyle(
                  fontSize: fontSize + 4,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Type at least 2 characters of a name or phone number.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: const [
                  _HintChip(icon: Icons.badge_outlined, label: 'Name'),
                  _HintChip(icon: Icons.phone_outlined, label: 'Phone'),
                ],
              ),
              if (canCreate) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: const Text('Create customer'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'New walk-in? Add them here without leaving POS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize - 1,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResultsState extends StatelessWidget {
  const _EmptyResultsState({
    required this.query,
    required this.canCreate,
    required this.fontSize,
    required this.iconSize,
    required this.onCreate,
  });

  final String query;
  final bool canCreate;
  final double fontSize;
  final double iconSize;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize + 28,
                height: iconSize + 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: iconSize,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No customers found',
                style: TextStyle(
                  fontSize: fontSize + 4,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nothing matched “$query”.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              if (canCreate) ...[
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: const Text('Create this customer'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.fontSize,
    required this.iconSize,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: fontSize + 2,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: fontSize, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateCustomerBanner extends StatelessWidget {
  const _CreateCustomerBanner({
    required this.query,
    required this.onTap,
    required this.fontSize,
  });

  final String query;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Can’t find them? Create “$query” as a new customer',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerResultTile extends StatelessWidget {
  const _CustomerResultTile({
    required this.customer,
    required this.iconSize,
    required this.fontSize,
    required this.subtitleSize,
    required this.onTap,
  });

  final Customer customer;
  final double iconSize;
  final double fontSize;
  final double subtitleSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (customer.phone.isNotEmpty) customer.phone,
      if (customer.loyaltyPoints > 0) '${customer.loyaltyPoints} pts',
      if (customer.advanceBalance > 0)
        'Adv ₹${customer.advanceBalance.toStringAsFixed(0)}',
      if ((customer.outstandingBalance ?? 0) > 0)
        'Due ₹${customer.outstandingBalance!.toStringAsFixed(0)}',
    ].join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: iconSize + 18,
                height: iconSize + 18,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_rounded, color: AppTheme.primary, size: iconSize),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: fontSize,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        style: TextStyle(
                          fontSize: subtitleSize,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCreateCustomerDialog extends StatefulWidget {
  const _QuickCreateCustomerDialog({
    required this.services,
    required this.initialQuery,
    required this.desktop,
  });

  final AppServices services;
  final String initialQuery;
  final bool desktop;

  @override
  State<_QuickCreateCustomerDialog> createState() =>
      _QuickCreateCustomerDialogState();
}

class _QuickCreateCustomerDialogState extends State<_QuickCreateCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;
  AutovalidateMode _auto = AutovalidateMode.disabled;

  static final _indiaPhonePattern = RegExp(r'^[6-9]\d{9}$');
  static final _namePattern = RegExp(r'^[A-Za-z]+(?: [A-Za-z]+)*$');

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery.trim();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    final looksLikePhone = digits.length >= 10;
    _name = TextEditingController(
      text: looksLikePhone ? '' : q.replaceAll(RegExp(r'\s+'), ' '),
    );
    _phone = TextEditingController(
      text: looksLikePhone
          ? (digits.length > 10 ? digits.substring(digits.length - 10) : digits)
          : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _auto = AutovalidateMode.onUserInteraction);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final created = await widget.services.customers.create({
        'name': _name.text.trim().replaceAll(RegExp(r'\s+'), ' '),
        'phone': _phone.text.trim(),
        'is_active': true,
        'whatsapp_opted': true,
      });
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = widget.desktop ? 15.0 : 14.0;
    return AlertDialog(
      title: const Text('Create customer'),
      content: SizedBox(
        width: widget.desktop ? 420 : 320,
        child: Form(
          key: _formKey,
          autovalidateMode: _auto,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: _name.text.isEmpty,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
                  LengthLimitingTextInputFormatter(150),
                ],
                validator: (v) {
                  final name = (v ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
                  if (name.isEmpty) return 'Name is required';
                  if (!_namePattern.hasMatch(name)) {
                    return 'Letters and spaces only';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Full name *',
                  hintText: 'Customer name',
                ),
                style: TextStyle(fontSize: fs),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                autofocus: _name.text.isNotEmpty && _phone.text.isEmpty,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saving ? null : _save(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  final phone = (v ?? '').trim();
                  if (phone.isEmpty) return 'Phone is required';
                  if (!_indiaPhonePattern.hasMatch(phone)) {
                    return 'Enter a valid 10-digit mobile number';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  hintText: '10-digit mobile',
                ),
                style: TextStyle(fontSize: fs),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(_saving ? 'Saving…' : 'Create & select'),
        ),
      ],
    );
  }
}

class _PosBalanceChip extends StatelessWidget {
  const _PosBalanceChip({
    required this.label,
    required this.color,
    this.large = false,
  });

  final String label;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 8 : 6,
        vertical: large ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: large ? 12 : 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
