import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/ist.dart';
import '../../core/utils/save_file.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../core/widgets/web_page.dart';
import '../../data/models/api_response.dart';
import '../../data/models/purchase.dart';

/// Purchases — mirrors `frontend/src/pages/purchase/PurchaseListPage.vue`.
class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  State<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends State<PurchaseListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _appliedSearch = '';
  String? _status;
  String? _paymentStatus;
  int? _supplierId;
  String? _dateFrom;
  String? _dateTo;
  String _sortBy = 'purchase_date';
  bool _sortAsc = false;
  int _reloadToken = 0;
  PaginationMetaView _meta = const PaginationMetaView();
  List<Supplier> _suppliers = const [];
  bool _exporting = false;

  static const _statusOptions = {
    'draft': 'Draft',
    'ordered': 'Ordered',
    'received': 'Received',
    'partial': 'Partial',
    'cancelled': 'Cancelled',
  };
  static const _paymentOptions = {'unpaid': 'Unpaid', 'partial': 'Partially paid', 'paid': 'Paid'};

  static final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);
  static final _compact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final list = await context.read<AppServices>().suppliers.list(query: {'per_page': 500});
        if (mounted) setState(() => _suppliers = list);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _reloadToken++);

  bool get _hasFilters =>
      _appliedSearch.isNotEmpty ||
      _status != null ||
      _paymentStatus != null ||
      _supplierId != null ||
      _dateFrom != null;

  Map<String, dynamic> get _filters => {
        'status': _status,
        'payment_status': _paymentStatus,
        'supplier_id': _supplierId,
        'date_from': _dateFrom,
        'date_to': _dateTo,
        'branch_id': context.read<AuthSession>().currentBranchId,
        'sort_by': _sortBy,
        'sort_dir': _sortAsc ? 'asc' : 'desc',
      };

  void _onSort(String key) {
    if (_sortBy == key) {
      _sortAsc = !_sortAsc;
    } else {
      _sortBy = key;
      _sortAsc = false;
    }
    _reload();
  }

  Future<bool> _confirm(String title, String body, {bool danger = false, String ok = 'Confirm'}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: AppTokens.error) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ok),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _rowMenu(String key, Purchase p) async {
    final svc = context.read<AppServices>().purchases;
    Future<void> run(Future<void> Function() action, String success, String failure) async {
      try {
        await action();
        if (mounted) AppMessenger.success(context, success);
        _reload();
      } catch (e) {
        if (mounted) AppMessenger.error(context, '$failure: $e');
      }
    }

    switch (key) {
      case 'return':
        context.push('/purchase-returns/new?supplier_id=${p.supplierId}');
      case 'call':
        launchUrl(Uri.parse('tel:${p.supplier?.phone}'));
      case 'receive':
        if (await _confirm('Mark as received', 'Receive ${p.purchaseNumber} into inventory? Stock will be added for all items.',
            ok: 'Receive')) {
          await run(() => svc.receive(p.id), 'Stock received into inventory', 'Failed to receive purchase');
        }
      case 'cancel':
        if (await _confirm('Cancel purchase', 'Cancel ${p.purchaseNumber}?', danger: true, ok: 'Cancel Purchase')) {
          await run(() => svc.update(p.id, {'status': 'cancelled'}), 'Purchase cancelled', 'Failed to cancel purchase');
        }
      case 'delete':
        if (await _confirm('Delete purchase', 'Delete ${p.purchaseNumber}? This cannot be undone.', danger: true, ok: 'Delete')) {
          await run(() => svc.deletePurchase(p.id), 'Purchase deleted', 'Failed to delete purchase');
        }
      default:
        context.go('/purchases/${p.id}');
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final res = await context.read<AppServices>().purchases.listPaginated(
            page: 1,
            perPage: 1000,
            search: _appliedSearch,
            filters: _filters,
          );
      if (res.items.isEmpty) {
        if (mounted) AppMessenger.error(context, 'Nothing to export');
        return;
      }
      final saved = await saveCsv(
        'purchases-${todayIst()}.csv',
        const ['Purchase #', 'Date', 'Supplier', 'Amount', 'Paid', 'Due', 'Status', 'Payment'],
        res.items.map((p) => [
              p.purchaseNumber,
              p.dateOnly,
              p.supplier?.name,
              p.totalAmount.toStringAsFixed(2),
              (p.paidAmount ?? 0).toStringAsFixed(2),
              (p.dueAmount ?? 0).toStringAsFixed(2),
              p.status,
              p.paymentStatus,
            ]),
      );
      if (mounted && saved != null) AppMessenger.success(context, 'Exported ${res.items.length} purchases');
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  KpiData _kpi(String label, String key, double value, IconData icon, KpiTone tone, {bool lowerIsGood = false, bool money = true}) {
    final ch = _meta.change(key);
    final good = ch == null ? false : (lowerIsGood ? ch <= 0 : ch >= 0);
    return KpiData(
      label: label,
      value: money ? _compact.format(value) : value.toInt().toString(),
      icon: icon,
      tone: tone,
      sub: ch == null ? '— vs last month' : '${ch >= 0 ? '▲' : '▼'} ${ch.abs()}% vs last month',
      subUp: good,
      series: _meta.series(key, last: key == 'orders' ? 7 : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission(AppPermissions.purchasesCreate);
    final canEdit = auth.hasPermission('purchases.edit');
    final canDelete = auth.hasPermission('purchases.delete');

    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        title: 'Purchases',
        subtitle:
            'Manage purchase orders, supplier payments and inventory procurement${auth.currentBranch != null ? ' · ${auth.currentBranch!.name}' : ''}',
        icon: Icons.shopping_cart_outlined,
        breadcrumbs: const [Crumb('Billing'), Crumb('Purchases')],
        actions: [
          OutlinedButton.icon(
            onPressed: _exporting ? null : _export,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text(_exporting ? 'Exporting…' : 'Export'),
          ),
          if (canCreate) FilledButton(onPressed: () => context.go('/purchases/new'), child: const Text('New Purchase')),
        ],
        kpis: [
          _kpi('Total Purchases', 'total', _meta.stat('total_amount'), Icons.shopping_cart_outlined, KpiTone.blue),
          _kpi('Paid Amount', 'paid', _meta.stat('paid_amount'), Icons.account_balance_wallet_outlined, KpiTone.green),
          _kpi('Due to Suppliers', 'due', _meta.stat('due_amount'), Icons.hourglass_bottom, KpiTone.orange, lowerIsGood: true),
          _kpi('Total Orders', 'orders', _meta.stat('orders'), Icons.description_outlined, KpiTone.purple, money: false),
        ],
        filters: FilterCard(
          searchController: _search,
          searchHint: 'Search purchase #, supplier name, or invoice...',
          onSearchChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () {
              if (!mounted) return;
              _appliedSearch = v.trim();
              _reload();
            });
          },
          filters: [
            FilterSelect<String>(hint: 'All Status', options: _statusOptions, value: _status, onChanged: (v) {
              _status = v;
              _reload();
            }),
            FilterSelect<String>(hint: 'All Payments', options: _paymentOptions, value: _paymentStatus, onChanged: (v) {
              _paymentStatus = v;
              _reload();
            }),
            FilterSelect<int>(
              hint: 'All Suppliers',
              options: {for (final s in _suppliers) s.id: s.name},
              value: _supplierId,
              onChanged: (v) {
                _supplierId = v;
                _reload();
              },
            ),
          ],
          trailing: [
            DateRangeFilter(
              from: _dateFrom,
              to: _dateTo,
              onChanged: (f, t) {
                _dateFrom = f;
                _dateTo = t;
                _reload();
              },
            ),
          ],
          onReset: () {
            _search.clear();
            _appliedSearch = '';
            _status = null;
            _paymentStatus = null;
            _supplierId = null;
            _dateFrom = null;
            _dateTo = null;
            _reload();
          },
          resetEnabled: _hasFilters,
        ),
        body: AppPaginatedTable<Purchase>(
          key: ValueKey('purchases-$_reloadToken-${auth.currentBranchId}'),
          perPage: 10,
          emptyMessage: 'No purchases found',
          loadPage: ({required page, required perPage}) => services.purchases.listPaginated(
            page: page,
            perPage: perPage,
            search: _appliedSearch,
            filters: _filters,
            withStats: true,
          ),
          onLoaded: (m) {
            if (mounted) setState(() => _meta = PaginationMetaView(m));
          },
          sortKey: _sortBy,
          sortAsc: _sortAsc,
          onSort: _onSort,
          onRowTap: (p) => context.go('/purchases/${p.id}'),
          columns: [
            TableColumnDef(
              label: '#',
              flex: 1.3,
              minWidth: 130,
              sortKey: 'purchase_number',
              cellBuilder: (_, p) =>
                  Text(p.purchaseNumber, style: const TextStyle(color: AppTokens.primary, fontWeight: FontWeight.w600)),
            ),
            TableColumnDef(label: 'Date', flex: 1, minWidth: 110, sortKey: 'purchase_date', cellBuilder: (_, p) => Text(formatDateIst(p.purchaseDate))),
            TableColumnDef(
              label: 'Supplier',
              flex: 1.9,
              minWidth: 180,
              cellBuilder: (_, p) => Row(children: [
                InitialsAvatar(p.supplier?.name ?? '?', size: 34),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(p.supplier?.name ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if ((p.supplier?.phone ?? '').isNotEmpty)
                      Text(p.supplier!.phone, style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                  ]),
                ),
              ]),
            ),
            TableColumnDef(
              label: 'Amount (₹)',
              flex: 1.2,
              minWidth: 120,
              align: TextAlign.right,
              sortKey: 'total_amount',
              cellBuilder: (_, p) => Text(_money.format(p.totalAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            TableColumnDef(
              label: 'Paid (₹)',
              flex: 1.2,
              minWidth: 120,
              align: TextAlign.right,
              sortKey: 'paid_amount',
              cellBuilder: (_, p) => Text(_money.format(p.paidAmount ?? 0), style: const TextStyle(color: AppTokens.success)),
            ),
            TableColumnDef(
              label: 'Due (₹)',
              flex: 1.2,
              minWidth: 120,
              align: TextAlign.right,
              sortKey: 'due_amount',
              cellBuilder: (_, p) {
                final due = p.dueAmount ?? 0;
                return Text(_money.format(due),
                    style: TextStyle(color: due > 0 ? AppTokens.error : AppTokens.text3, fontWeight: FontWeight.w600));
              },
            ),
            TableColumnDef(label: 'Status', flex: 1, minWidth: 110, sortKey: 'status', cellBuilder: (_, p) => _purchaseStatus(p.status)),
            TableColumnDef(
              label: 'Payment',
              flex: 1,
              minWidth: 110,
              sortKey: 'payment_status',
              cellBuilder: (_, p) {
                final ps = (p.paymentStatus ?? ((p.dueAmount ?? 0) > 0 ? 'unpaid' : 'paid')).toLowerCase();
                return StatusPill(
                  ps == 'partial' ? 'Partially paid' : '${ps[0].toUpperCase()}${ps.substring(1)}',
                  tone: ps == 'paid' ? PillTone.green : ps == 'partial' ? PillTone.amber : PillTone.red,
                );
              },
            ),
            TableColumnDef(
              label: 'Actions',
              flex: 1,
              minWidth: 100,
              cellBuilder: (_, p) => Row(mainAxisSize: MainAxisSize.min, children: [
                TableIconButton(icon: Icons.visibility_outlined, tooltip: 'View', onPressed: () => context.go('/purchases/${p.id}')),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (k) => _rowMenu(k, p),
                  itemBuilder: (_) {
                    final danger = <PopupMenuEntry<String>>[
                      if (canEdit && const ['draft', 'ordered'].contains(p.status))
                        const PopupMenuItem(value: 'cancel', child: Text('Cancel Purchase', style: TextStyle(color: AppTokens.error))),
                      if (canDelete && const ['draft', 'ordered', 'cancelled'].contains(p.status))
                        const PopupMenuItem(value: 'delete', child: Text('Delete Purchase', style: TextStyle(color: AppTokens.error))),
                    ];
                    return [
                      const PopupMenuItem(value: 'view', child: Text('View details')),
                      if (canEdit && const ['draft', 'ordered', 'partial'].contains(p.status))
                        const PopupMenuItem(value: 'receive', child: Text('Mark as Received')),
                      if (const ['received', 'partial'].contains(p.status) && canCreate)
                        const PopupMenuItem(value: 'return', child: Text('Create Purchase Return')),
                      if ((p.supplier?.phone ?? '').isNotEmpty) const PopupMenuItem(value: 'call', child: Text('Call supplier')),
                      if (danger.isNotEmpty) ...[const PopupMenuDivider(), ...danger],
                    ];
                  },
                  child: const TableIconButton(icon: Icons.more_vert, plain: true, onPressed: null),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _purchaseStatus(String status) {
  final tone = switch (status) {
    'received' => PillTone.green,
    'partial' => PillTone.amber,
    'ordered' => PillTone.blue,
    'cancelled' => PillTone.red,
    _ => PillTone.grey,
  };
  return StatusPill(status.isEmpty ? '—' : '${status[0].toUpperCase()}${status.substring(1)}', tone: tone);
}
