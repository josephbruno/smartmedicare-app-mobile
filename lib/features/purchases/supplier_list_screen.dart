import 'dart:async';

import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/web_page.dart';
import '../../data/models/api_response.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/purchase.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {

  Future<void> _openForm({Supplier? supplier}) async {
    final isEdit = supplier != null;
    final name = TextEditingController(text: supplier?.name ?? '');
    final company = TextEditingController(text: supplier?.companyName ?? '');
    final phone = TextEditingController(text: supplier?.phone ?? '');
    final email = TextEditingController(text: supplier?.email ?? '');
    final gstin = TextEditingController(text: supplier?.gstin ?? '');
    final creditLimit = TextEditingController(
      text: (supplier?.creditLimit ?? 0).toStringAsFixed(0),
    );
    final creditDays = TextEditingController(
      text: (supplier?.creditDays ?? 30).toString(),
    );

    Widget fields() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: appFormFieldDecoration(
              'Supplier Name *',
              hint: 'e.g. PetCare Distributors',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: company,
            textCapitalization: TextCapitalization.words,
            decoration: appFormFieldDecoration(
              'Company Name',
              hint: 'Legal entity name',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: appFormFieldDecoration('Phone *', hint: '10-digit number'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: appFormFieldDecoration('Email'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: gstin,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(15)],
            decoration: appFormFieldDecoration('GSTIN'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: creditLimit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: appFormFieldDecoration('Credit Limit (₹)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: creditDays,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: appFormFieldDecoration('Credit Days'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final title = isEdit ? 'Edit Supplier' : 'Add Supplier';
    final bool? saved;
    if (useCenteredFormDialog(context)) {
      saved = await showAppAlertForm<bool>(
        context: context,
        title: title,
        maxWidth: 560,
        content: fields(),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(true),
            child: Text(isEdit ? 'Update' : 'Create'),
          ),
        ],
      );
    } else {
      saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AppFormBottomSheetShell(
          title: title,
          icon: Icons.local_shipping_outlined,
          onClose: () => Navigator.pop(ctx, false),
          body: fields(),
          footer: AppFormFooter(
            primaryLabel: isEdit ? 'Update' : 'Create',
            onCancel: () => Navigator.pop(ctx, false),
            onSubmit: () => Navigator.pop(ctx, true),
          ),
        ),
      );
    }

    if (saved != true || !mounted) return;

    final nameText = name.text.trim();
    final phoneText = phone.text.trim();
    if (nameText.isEmpty) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Supplier name is required')),
      );
      return;
    }
    if (phoneText.isEmpty) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Phone is required')),
      );
      return;
    }

    final body = <String, dynamic>{
      'name': nameText,
      'company_name': company.text.trim().isEmpty ? null : company.text.trim(),
      'phone': phoneText,
      'email': email.text.trim().isEmpty ? null : email.text.trim(),
      'gstin': gstin.text.trim().isEmpty ? null : gstin.text.trim(),
      'credit_limit': double.tryParse(creditLimit.text.trim()) ?? 0,
      'credit_days': int.tryParse(creditDays.text.trim()) ?? 30,
    };

    try {
      final svc = context.read<AppServices>().suppliers;
      if (supplier != null) {
        await svc.update(supplier.id, body);
      } else {
        await svc.create(body);
      }
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(
          content: Text(isEdit ? 'Supplier updated' : 'Supplier created'),
        ),
      );
      _reload();
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    }
  }

  // ── list state (mirrors SupplierListPage.vue) ───────────────────────
  final _search = TextEditingController();
  Timer? _debounce;
  String _appliedSearch = '';
  String? _status;
  String? _creditLimit;
  String? _creditDays;
  String _sortBy = 'name';
  bool _sortAsc = true;
  int _reloadToken = 0;
  PaginationMetaView _meta = const PaginationMetaView();

  static const _statusOptions = {'active': 'Active', 'inactive': 'Inactive'};
  static const _creditLimitOptions = {
    'none': 'No credit (₹0)',
    'upto_25000': 'Up to ₹25,000',
    '25001_50000': '₹25,001 – ₹50,000',
    'above_50000': 'Above ₹50,000',
  };
  static const _creditDaysOptions = {
    'none': 'No credit (0 days)',
    '1_15': '1 – 15 days',
    '16_30': '16 – 30 days',
    '31_45': '31 – 45 days',
    'above_45': 'Above 45 days',
  };

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _reloadToken++);

  bool get _hasFilters =>
      _appliedSearch.isNotEmpty || _status != null || _creditLimit != null || _creditDays != null;

  void _onSort(String key) {
    if (_sortBy == key) {
      _sortAsc = !_sortAsc;
    } else {
      _sortBy = key;
      _sortAsc = key == 'name';
    }
    _reload();
  }

  Future<void> _rowMenu(String key, Supplier s) async {
    final digits = s.phone.replaceAll(RegExp(r'\D'), '');
    final svc = context.read<AppServices>().suppliers;
    switch (key) {
      case 'call':
        launchUrl(Uri.parse('tel:${s.phone}'));
      case 'whatsapp':
        launchUrl(Uri.parse('https://wa.me/${digits.length == 10 ? '91$digits' : digits}'),
            mode: LaunchMode.externalApplication);
      case 'email':
        launchUrl(Uri.parse('mailto:${s.email}'));
      case 'toggle':
        try {
          await svc.update(s.id, {'is_active': !s.isActive});
          if (mounted) AppMessenger.success(context, 'Supplier updated');
          _reload();
        } catch (e) {
          if (mounted) AppMessenger.error(context, 'Failed to update supplier: $e');
        }
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete supplier'),
            content: Text('Delete "${s.name}"? This cannot be undone.'),
            actions: [
              OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTokens.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        try {
          await svc.delete(s.id);
          if (mounted) AppMessenger.success(context, 'Supplier deleted');
          _reload();
        } catch (e) {
          if (mounted) AppMessenger.error(context, 'Failed to delete supplier: $e');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission(AppPermissions.suppliersCreate);
    final canEdit = auth.hasPermission(AppPermissions.suppliersEdit);
    final canDelete = auth.hasPermission('suppliers.delete');
    String money(double? v) => '₹${NumberFormat.decimalPattern('en_IN').format((v ?? 0).round())}';
    int st(String k) => _meta.stat(k).toInt();

    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        title: 'Suppliers',
        subtitle: 'Manage your suppliers, contact details, credit terms and status',
        icon: Icons.local_shipping_outlined,
        breadcrumbs: const [Crumb('Billing'), Crumb('Suppliers')],
        actions: [
          if (canCreate) FilledButton(onPressed: () => _openForm(), child: const Text('Add Supplier')),
        ],
        kpis: [
          KpiData(label: 'Total Suppliers', value: '${st('total')}', icon: Icons.people),
          KpiData(label: 'Active Suppliers', value: '${st('active')}', icon: Icons.person, tone: KpiTone.green),
          KpiData(label: 'Inactive Suppliers', value: '${st('inactive')}', icon: Icons.person_off_outlined, tone: KpiTone.red),
          KpiData(label: 'On Credit', value: '${st('on_credit')}', icon: Icons.account_balance_wallet, tone: KpiTone.orange),
        ],
        filters: FilterCard(
          searchController: _search,
          searchHint: 'Search suppliers by name, phone, email or GSTIN...',
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
            FilterSelect<String>(hint: 'Any Credit Limit', options: _creditLimitOptions, value: _creditLimit, onChanged: (v) {
              _creditLimit = v;
              _reload();
            }),
            FilterSelect<String>(hint: 'Any Credit Days', options: _creditDaysOptions, value: _creditDays, onChanged: (v) {
              _creditDays = v;
              _reload();
            }),
          ],
          onReset: () {
            _search.clear();
            _appliedSearch = '';
            _status = null;
            _creditLimit = null;
            _creditDays = null;
            _reload();
          },
          resetEnabled: _hasFilters,
        ),
        body: AppPaginatedTable<Supplier>(
          key: ValueKey('suppliers-$_reloadToken'),
          perPage: 10,
          emptyMessage: 'No suppliers found',
          loadPage: ({required page, required perPage}) => services.suppliers.listPaginated(
            page: page,
            perPage: perPage,
            search: _appliedSearch,
            filters: {
              'status': _status,
              'credit_limit': _creditLimit,
              'credit_days': _creditDays,
              'sort_by': _sortBy,
              'sort_dir': _sortAsc ? 'asc' : 'desc',
            },
            withStats: true,
          ),
          onLoaded: (m) {
            if (mounted) setState(() => _meta = PaginationMetaView(m));
          },
          sortKey: _sortBy,
          sortAsc: _sortAsc,
          onSort: _onSort,
          onRowTap: canEdit ? (s) => _openForm(supplier: s) : null,
          columns: [
            TableColumnDef(
              label: 'Supplier',
              flex: 2.2,
              minWidth: 210,
              sortKey: 'name',
              cellBuilder: (_, s) => Row(children: [
                InitialsAvatar(s.name),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if ((s.companyName ?? '').isNotEmpty)
                      Text(s.companyName!, style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                  ]),
                ),
              ]),
            ),
            TableColumnDef(label: 'Phone', flex: 1.2, minWidth: 120, sortKey: 'phone', cellBuilder: (_, s) => Text(s.phone.isEmpty ? '—' : s.phone)),
            TableColumnDef(
                label: 'Email',
                flex: 1.6,
                minWidth: 160,
                sortKey: 'email',
                cellBuilder: (_, s) => Text(s.email ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis)),
            TableColumnDef(label: 'GSTIN', flex: 1.3, minWidth: 140, sortKey: 'gstin', cellBuilder: (_, s) => Text(s.gstin ?? '—')),
            TableColumnDef(
                label: 'Credit Limit',
                flex: 1,
                minWidth: 110,
                sortKey: 'credit_limit',
                cellBuilder: (_, s) => Text(money(s.creditLimit), style: const TextStyle(fontWeight: FontWeight.w600))),
            TableColumnDef(
                label: 'Credit Days',
                flex: 0.9,
                minWidth: 100,
                cellBuilder: (_, s) => Text(s.creditDays == null ? '—' : '${s.creditDays} days')),
            TableColumnDef(
              label: 'Status',
              flex: 0.9,
              minWidth: 100,
              sortKey: 'is_active',
              cellBuilder: (_, s) => s.isActive
                  ? const StatusPill('Active', tone: PillTone.green)
                  : const StatusPill('Inactive', tone: PillTone.red),
            ),
            TableColumnDef(
              label: 'Actions',
              flex: 1,
              minWidth: 110,
              cellBuilder: (_, s) => Row(mainAxisSize: MainAxisSize.min, children: [
                if (canEdit) TableIconButton(icon: Icons.edit_outlined, tooltip: 'Edit', onPressed: () => _openForm(supplier: s)),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (k) => _rowMenu(k, s),
                  itemBuilder: (_) => [
                    if (s.phone.isNotEmpty) ...[
                      const PopupMenuItem(value: 'call', child: Text('Call')),
                      const PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                    ],
                    if ((s.email ?? '').isNotEmpty) const PopupMenuItem(value: 'email', child: Text('Send email')),
                    if (canEdit) ...[
                      const PopupMenuDivider(),
                      PopupMenuItem(value: 'toggle', child: Text(s.isActive ? 'Mark as inactive' : 'Mark as active')),
                    ],
                    if (canDelete) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete supplier', style: TextStyle(color: AppTokens.error))),
                    ],
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
