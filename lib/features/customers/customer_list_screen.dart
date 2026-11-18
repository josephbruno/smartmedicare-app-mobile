import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/ist.dart';
import '../../core/utils/save_file.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../core/widgets/web_page.dart';
import '../../data/models/api_response.dart';
import '../../data/models/customer.dart';

/// Customer list — mirrors `frontend/src/pages/customers/CustomerListPage.vue`:
/// KPIs, search + type/pets/status filters, sortable table, CSV export.
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  String _appliedSearch = '';
  String? _type;
  String? _pets;
  String? _status;
  String _sortBy = 'created_at';
  bool _sortAsc = false;
  int _reloadToken = 0;
  Map<String, dynamic>? _stats;
  bool _exporting = false;

  static const _typeOptions = {
    'individual': 'Individual',
    'business': 'Business',
    'corporate': 'Corporate',
    'insurance': 'Insurance',
    'others': 'Others',
  };
  static const _petOptions = {'with': 'With pets', 'without': 'Without pets'};
  static const _statusOptions = {'active': 'Active', 'inactive': 'Inactive'};

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _appliedSearch.isNotEmpty ||
      _type != null ||
      _pets != null ||
      _status != null ||
      _sortBy != 'created_at' ||
      _sortAsc;

  Map<String, dynamic> get _filters => {
        'customer_type': _type,
        'pets': _pets,
        'status': _status,
        'sort_by': _sortBy,
        'sort_dir': _sortAsc ? 'asc' : 'desc',
      };

  void _reload() => setState(() => _reloadToken++);

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _appliedSearch = v.trim();
      _reload();
    });
  }

  void _reset() {
    _search.clear();
    _appliedSearch = '';
    _type = null;
    _pets = null;
    _status = null;
    _sortBy = 'created_at';
    _sortAsc = false;
    _reload();
  }

  void _onSort(String key) {
    if (_sortBy == key) {
      _sortAsc = !_sortAsc;
    } else {
      _sortBy = key;
      _sortAsc = key == 'name';
    }
    _reload();
  }

  Future<void> _openCreate() async {
    final created = await context.push<Customer>('/customers/new');
    if (mounted && created != null) _reload();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final res = await context.read<AppServices>().customers.listPaginated(
            page: 1,
            perPage: 1000,
            search: _appliedSearch,
            filters: _filters,
          );
      final saved = await saveCsv(
        'customers-${todayIst()}.csv',
        const ['Code', 'Name', 'Type', 'Phone', 'Email', 'City', 'Pets', 'Status', 'Joined On'],
        res.items.map((c) => [
              c.customerCode,
              c.name,
              c.customerType,
              c.phone,
              c.email,
              c.city,
              c.petsCount ?? c.pets?.length ?? 0,
              c.isActive ? 'Active' : 'Inactive',
              formatDateIst(c.createdAt),
            ]),
      );
      if (!mounted || saved == null) return;
      final total = res.meta?.total ?? res.items.length;
      AppMessenger.success(
        context,
        total > res.items.length
            ? 'Exported the first ${res.items.length} of $total customers'
            : 'Exported ${res.items.length} customers',
      );
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _toggleActive(Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.isActive ? 'Mark customer inactive' : 'Mark customer active'),
        content: Text(c.isActive
            ? '${c.name} will be hidden from POS customer search.'
            : '${c.name} will be available again for billing.'),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().customers.update(c.id, {'is_active': !c.isActive});
      if (!mounted) return;
      AppMessenger.success(context, 'Customer updated');
      _reload();
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Failed to update customer: $e');
    }
  }

  void _rowMenu(String key, Customer c) {
    final digits = c.phone.replaceAll(RegExp(r'\D'), '');
    switch (key) {
      case 'call':
        launchUrl(Uri.parse('tel:${c.phone}'));
      case 'whatsapp':
        launchUrl(
          Uri.parse('https://wa.me/${digits.length == 10 ? '91$digits' : digits}'),
          mode: LaunchMode.externalApplication,
        );
      case 'email':
        launchUrl(Uri.parse('mailto:${c.email}'));
      case 'toggle':
        _toggleActive(c);
      default:
        context.go('/customers/${c.id}');
    }
  }

  List<KpiData> _kpis(bool vet) {
    final st = _stats;
    int n(String k) => (st?[k] as num?)?.toInt() ?? 0;
    List<double> series(String k) {
      final s = st?['series'];
      if (s is Map && s[k] is List) {
        return (s[k] as List).map((e) => (e as num?)?.toDouble() ?? 0).toList();
      }
      return const [];
    }

    final total = n('total');
    String pct(int v) =>
        '${total == 0 ? 0 : (v / total * 1000).round() / 10}% of customers';
    final change = st?['change'];
    final newThisMonth = n('new_this_month');
    return [
      KpiData(
        label: 'Total Customers',
        value: '$total',
        icon: Icons.people,
        sub: change != null ? '+$change% from last month' : '+$newThisMonth this month',
        subUp: newThisMonth > 0,
        series: series('total'),
      ),
      if (vet)
        KpiData(
          label: 'Pet Owners',
          value: '${n('pet_owners')}',
          icon: Icons.pets,
          tone: KpiTone.sky,
          sub: pct(n('pet_owners')),
          series: series('pet_owners'),
        ),
      KpiData(
        label: 'With Phone',
        value: '${n('with_phone')}',
        icon: Icons.call_outlined,
        tone: KpiTone.purple,
        sub: pct(n('with_phone')),
        series: series('with_phone'),
      ),
      KpiData(
        label: 'With Email',
        value: '${n('with_email')}',
        icon: Icons.mail_outline,
        tone: KpiTone.orange,
        sub: pct(n('with_email')),
        series: series('with_email'),
      ),
    ];
  }

  Widget _select(String hint, Map<String, String> options, String? value, ValueChanged<String?> onChanged) {
    return AppDropdownButtonFormField<String?>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(hintText: hint),
      hint: Text(hint),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(hint)),
        for (final e in options.entries)
          DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
      ],
      onChanged: (v) {
        onChanged(v);
        _reload();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = context.watch<AuthSession>();
    final vet = auth.isVeterinary;
    final canCreate = auth.hasPermission(AppPermissions.customersCreate);
    final canEdit = auth.hasPermission(AppPermissions.customersEdit);

    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        title: 'Customers',
        subtitle: vet
            ? 'Manage pet owners and their contact details'
            : 'Manage customers and their contact details',
        icon: Icons.people,
        breadcrumbs: [Crumb(vet ? 'Owners' : auth.responsiblePartiesLabel), const Crumb('Customers')],
        actions: [
          OutlinedButton.icon(
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined, color: AppTokens.warning),
            label: const Text('Export'),
          ),
          if (canCreate)
            FilledButton(onPressed: _openCreate, child: const Text('Add Customer')),
        ],
        kpis: _kpis(vet),
        filters: FilterCard(
          searchController: _search,
          searchHint: 'Search by name, phone or email...',
          onSearchChanged: _onSearch,
          filters: [
            if (!vet) _select('All Customers', _typeOptions, _type, (v) => _type = v),
            if (vet) _select('All Pet Owners', _petOptions, _pets, (v) => _pets = v),
            _select('All Status', _statusOptions, _status, (v) => _status = v),
          ],
          onReset: _reset,
          resetEnabled: _hasFilters,
        ),
        body: AppPaginatedTable<Customer>(
          key: ValueKey('customers-$_reloadToken'),
          perPage: 10,
          emptyMessage: _hasFilters ? 'No customers match your filters.' : 'No customers yet.',
          loadPage: ({required page, required perPage}) => services.customers.listPaginated(
            page: page,
            perPage: perPage,
            search: _appliedSearch,
            filters: _filters,
            withStats: true,
          ),
          onLoaded: (PaginationMeta? m) {
            final st = m?.stats;
            if (st != null && mounted) setState(() => _stats = st);
          },
          sortKey: _sortBy,
          sortAsc: _sortAsc,
          onSort: _onSort,
          onRowTap: (c) => context.go('/customers/${c.id}'),
          mobileItemBuilder: (context, c) => _MobileCustomerCard(
            customer: c,
            vet: vet,
            onTap: () => context.go('/customers/${c.id}'),
          ),
          columns: [
            TableColumnDef(
              label: 'Customer',
              flex: 2.4,
              minWidth: 220,
              sortKey: 'name',
              cellBuilder: (context, c) => _PersonCell(customer: c),
            ),
            TableColumnDef(
              label: 'Phone',
              flex: 1.3,
              minWidth: 130,
              cellBuilder: (context, c) => _ContactCell(icon: Icons.call_outlined, text: c.phone),
            ),
            TableColumnDef(
              label: 'Email',
              flex: 1.8,
              minWidth: 170,
              cellBuilder: (context, c) => _ContactCell(icon: Icons.mail_outline, text: c.email),
            ),
            if (vet)
              TableColumnDef(
                label: 'Pets Count',
                flex: 1,
                minWidth: 110,
                sortKey: 'pets_count',
                cellBuilder: (context, c) {
                  final count = c.petsCount ?? c.pets?.length ?? 0;
                  return StatusPill('$count',
                      icon: Icons.pets, tone: count > 0 ? PillTone.purple : PillTone.grey);
                },
              ),
            TableColumnDef(
              label: 'Status',
              flex: 1,
              minWidth: 100,
              cellBuilder: (context, c) => c.isActive
                  ? const StatusPill('Active', icon: Icons.check_circle, tone: PillTone.green)
                  : const StatusPill('Inactive', icon: Icons.error, tone: PillTone.amber),
            ),
            TableColumnDef(
              label: 'Joined On',
              flex: 1.2,
              minWidth: 130,
              sortKey: 'created_at',
              cellBuilder: (context, c) => _ContactCell(
                icon: Icons.calendar_today_outlined,
                text: formatDateIst(c.createdAt),
                muted: true,
              ),
            ),
            TableColumnDef(
              label: 'Actions',
              flex: 1.3,
              minWidth: 150,
              cellBuilder: (context, c) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TableIconButton(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View',
                    onPressed: () => context.go('/customers/${c.id}'),
                  ),
                  if (canEdit) ...[
                    const SizedBox(width: 8),
                    TableIconButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      plain: true,
                      onPressed: () async {
                        await context.push('/customers/${c.id}/edit');
                        if (mounted) _reload();
                      },
                    ),
                  ],
                  const SizedBox(width: 8),
                  _RowMenu(customer: c, canEdit: canEdit, onSelected: (k) => _rowMenu(k, c)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonCell extends StatelessWidget {
  const _PersonCell({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return Row(
      children: [
        InitialsAvatar(c.name),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              if ((c.customerCode ?? '').isNotEmpty)
                Text(c.customerCode!,
                    style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactCell extends StatelessWidget {
  const _ContactCell({required this.icon, required this.text, this.muted = false});

  final IconData icon;
  final String? text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = (text ?? '').trim();
    if (t.isEmpty) return const Text('—', style: TextStyle(color: AppTokens.text3));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: muted ? AppTokens.text3 : AppTokens.primary),
        const SizedBox(width: 8),
        Flexible(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.customer, required this.canEdit, required this.onSelected});

  final Customer customer;
  final bool canEdit;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return PopupMenuButton<String>(
      tooltip: 'More',
      onSelected: onSelected,
      itemBuilder: (_) => [
        if (c.phone.isNotEmpty) ...[
          const PopupMenuItem(value: 'call', child: Text('Call')),
          const PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
        ],
        if ((c.email ?? '').isNotEmpty) const PopupMenuItem(value: 'email', child: Text('Send email')),
        if (canEdit) ...[
          const PopupMenuDivider(),
          PopupMenuItem(value: 'toggle', child: Text(c.isActive ? 'Mark as inactive' : 'Mark as active')),
        ],
        if (c.phone.isEmpty && (c.email ?? '').isEmpty && !canEdit)
          const PopupMenuItem(value: 'view', child: Text('View details')),
      ],
      child: const TableIconButton(icon: Icons.more_vert, plain: true, onPressed: null),
    );
  }
}

class _MobileCustomerCard extends StatelessWidget {
  const _MobileCustomerCard({required this.customer, required this.vet, required this.onTap});

  final Customer customer;
  final bool vet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final pets = c.petsCount ?? c.pets?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTokens.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                InitialsAvatar(c.name, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTokens.text1)),
                      const SizedBox(height: 2),
                      Text(
                        [c.phone, if ((c.email ?? '').isNotEmpty) c.email!].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppTokens.text3),
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        c.isActive
                            ? const StatusPill('Active', tone: PillTone.green)
                            : const StatusPill('Inactive', tone: PillTone.amber),
                        if (vet)
                          StatusPill('$pets', icon: Icons.pets, tone: pets > 0 ? PillTone.purple : PillTone.grey),
                      ]),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTokens.placeholder),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
