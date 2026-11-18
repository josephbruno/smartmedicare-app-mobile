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
import '../../data/models/purchase_return.dart';

/// Purchase returns — mirrors `frontend/src/pages/purchases/PurchaseReturnListPage.vue`.
class PurchaseReturnListScreen extends StatefulWidget {
  const PurchaseReturnListScreen({super.key});

  @override
  State<PurchaseReturnListScreen> createState() => _PurchaseReturnListScreenState();
}

class _PurchaseReturnListScreenState extends State<PurchaseReturnListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _appliedSearch = '';
  String? _reason;
  String? _status;
  String? _dateFrom;
  String? _dateTo;
  String _sortBy = 'return_date';
  bool _sortAsc = false;
  int _reloadToken = 0;
  PaginationMetaView _meta = const PaginationMetaView();
  bool _exporting = false;

  static const _reasons = {'expired': 'Expired', 'damaged': 'Damaged', 'other': 'Other'};
  static const _statuses = {'completed': 'Completed', 'pending': 'Pending', 'cancelled': 'Cancelled'};
  static final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _reloadToken++);

  Map<String, dynamic> get _filters => {
        'reason': _reason,
        'status': _status,
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
      _sortAsc = key == 'supplier';
    }
    _reload();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final res = await context
          .read<AppServices>()
          .purchaseReturns
          .listPaginated(page: 1, perPage: 1000, search: _appliedSearch, filters: _filters);
      if (res.items.isEmpty) {
        if (mounted) AppMessenger.error(context, 'Nothing to export');
        return;
      }
      await saveCsv(
        'purchase-returns-${todayIst()}.csv',
        const ['Return #', 'Date', 'Supplier', 'Reason', 'Subtotal', 'Total', 'Status', 'Notes'],
        res.items.map((r) => [
              r.returnNumber,
              r.dateOnly,
              r.supplier?.name,
              _reasons[r.reason] ?? r.reason,
              r.subtotal?.toStringAsFixed(2),
              r.totalAmount.toStringAsFixed(2),
              r.status,
              r.notes,
            ]),
      );
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _rowMenu(String key, PurchaseReturn r) {
    final phone = r.supplier?.phone ?? '';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    switch (key) {
      case 'again':
        context.push('/purchase-returns/new?supplier_id=${r.supplierId}');
      case 'call':
        launchUrl(Uri.parse('tel:$phone'));
      case 'whatsapp':
        launchUrl(Uri.parse('https://wa.me/${digits.length == 10 ? '91$digits' : digits}'),
            mode: LaunchMode.externalApplication);
      case 'email':
        launchUrl(Uri.parse('mailto:${r.supplier?.email}'));
      default:
        context.go('/purchase-returns/${r.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission(AppPermissions.purchasesCreate);
    int st(String k) => _meta.stat(k).toInt();

    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        title: 'Purchase Returns',
        subtitle:
            'Manage purchase returns and track supplier returns${auth.currentBranch != null ? ' · ${auth.currentBranch!.name}' : ''}',
        icon: Icons.assignment_return_outlined,
        breadcrumbs: const [Crumb('Billing'), Crumb('Purchase Returns')],
        actions: [
          OutlinedButton.icon(
            onPressed: _exporting ? null : _export,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text(_exporting ? 'Exporting…' : 'Export'),
          ),
          if (canCreate)
            FilledButton(onPressed: () => context.go('/purchase-returns/new'), child: const Text('New Return')),
        ],
        kpis: [
          KpiData(label: 'Total Returns', value: '${st('total')}', icon: Icons.inventory_2_outlined),
          KpiData(label: 'Completed', value: '${st('completed')}', icon: Icons.check_circle, tone: KpiTone.green),
          KpiData(label: 'Pending', value: '${st('pending')}', icon: Icons.schedule, tone: KpiTone.orange),
          KpiData(label: 'Cancelled', value: '${st('cancelled')}', icon: Icons.block, tone: KpiTone.red),
        ],
        filters: FilterCard(
          searchController: _search,
          searchHint: 'Search return #, supplier name...',
          onSearchChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () {
              if (!mounted) return;
              _appliedSearch = v.trim();
              _reload();
            });
          },
          filters: [
            FilterSelect<String>(hint: 'All Reasons', options: _reasons, value: _reason, onChanged: (v) {
              _reason = v;
              _reload();
            }),
            FilterSelect<String>(hint: 'All Status', options: _statuses, value: _status, onChanged: (v) {
              _status = v;
              _reload();
            }),
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
            _reason = null;
            _status = null;
            _dateFrom = null;
            _dateTo = null;
            _reload();
          },
          resetEnabled: _appliedSearch.isNotEmpty || _reason != null || _status != null || _dateFrom != null,
        ),
        body: AppPaginatedTable<PurchaseReturn>(
          key: ValueKey('returns-$_reloadToken-${auth.currentBranchId}'),
          perPage: 10,
          emptyMessage: 'No purchase returns found',
          loadPage: ({required page, required perPage}) => services.purchaseReturns.listPaginated(
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
          onRowTap: (r) => context.go('/purchase-returns/${r.id}'),
          columns: [
            TableColumnDef(
              label: 'Return #',
              flex: 1.3,
              minWidth: 130,
              sortKey: 'return_number',
              cellBuilder: (_, r) =>
                  Text(r.returnNumber, style: const TextStyle(color: AppTokens.primary, fontWeight: FontWeight.w600)),
            ),
            TableColumnDef(
              label: 'Date',
              flex: 1,
              minWidth: 110,
              sortKey: 'return_date',
              cellBuilder: (_, r) => Text(r.returnDate.isEmpty ? '—' : formatDateIst(r.returnDate)),
            ),
            TableColumnDef(
              label: 'Supplier',
              flex: 2.2,
              minWidth: 220,
              sortKey: 'supplier',
              cellBuilder: (_, r) => Row(children: [
                InitialsAvatar(r.supplier?.name ?? '?', size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(r.supplier?.name ?? '—',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if ((r.supplier?.companyName ?? '').isNotEmpty)
                      Text(r.supplier!.companyName!, style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                  ]),
                ),
                if ((r.supplier?.phone ?? '').isNotEmpty)
                  IconButton(
                    tooltip: 'Call ${r.supplier!.phone}',
                    icon: const Icon(Icons.call, size: 16, color: AppTokens.primary),
                    onPressed: () => launchUrl(Uri.parse('tel:${r.supplier!.phone}')),
                  ),
                if ((r.supplier?.email ?? '').isNotEmpty)
                  IconButton(
                    tooltip: r.supplier!.email,
                    icon: const Icon(Icons.mail, size: 16, color: AppTokens.primary),
                    onPressed: () => launchUrl(Uri.parse('mailto:${r.supplier!.email}')),
                  ),
              ]),
            ),
            TableColumnDef(
              label: 'Reason',
              flex: 1,
              minWidth: 100,
              cellBuilder: (_, r) => StatusPill(_reasons[r.reason] ?? r.reason, tone: PillTone.grey),
            ),
            TableColumnDef(
              label: 'Amount',
              flex: 1.1,
              minWidth: 110,
              align: TextAlign.right,
              sortKey: 'total_amount',
              cellBuilder: (_, r) => Text(_money.format(r.totalAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            TableColumnDef(
              label: 'Status',
              flex: 1,
              minWidth: 110,
              sortKey: 'status',
              cellBuilder: (_, r) => StatusPill(
                '● ${r.status.isEmpty ? '—' : '${r.status[0].toUpperCase()}${r.status.substring(1)}'}',
                tone: switch (r.status) {
                  'completed' => PillTone.green,
                  'pending' => PillTone.amber,
                  'cancelled' => PillTone.red,
                  _ => PillTone.grey,
                },
              ),
            ),
            TableColumnDef(
              label: 'Actions',
              flex: 1.2,
              minWidth: 130,
              cellBuilder: (_, r) => Row(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 10)),
                  onPressed: () => context.go('/purchase-returns/${r.id}'),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View'),
                ),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  tooltip: 'More actions for ${r.returnNumber}',
                  onSelected: (k) => _rowMenu(k, r),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'view', child: Text('View details')),
                    if (canCreate) const PopupMenuItem(value: 'again', child: Text('New return for this supplier')),
                    if ((r.supplier?.phone ?? '').isNotEmpty) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'call', child: Text('Call supplier')),
                      const PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp supplier')),
                    ],
                    if ((r.supplier?.email ?? '').isNotEmpty) const PopupMenuItem(value: 'email', child: Text('Email supplier')),
                  ],
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
