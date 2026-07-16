import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/customer.dart';
import 'widgets/customer_detail_body.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _search = TextEditingController();
  final _tableKey = GlobalKey<AppPaginatedTableState<Customer>>();
  int? _selectedId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _splitPane => useWebLikeShell(context) && MediaQuery.sizeOf(context).width >= 1100;

  Future<void> _refreshTable({int? selectCustomerId}) async {
    await _tableKey.currentState?.refresh();
    if (!mounted || selectCustomerId == null) return;
    setState(() => _selectedId = selectCustomerId);
  }

  Future<void> _openCreateCustomer() async {
    final created = await context.push<Customer>('/customers/new');
    if (!mounted || created == null) return;
    await _refreshTable(selectCustomerId: created.id);
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final canCreate = context.watch<AuthSession>().hasPermission(AppPermissions.customersCreate);
    final search = _search.text.trim();

    final table = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Search customers by name or phone…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onSubmitted: (_) => setState(() {}),
                ),
              ),
              if (canCreate && _splitPane) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _openCreateCustomer,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Customer'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AppPaginatedTable<Customer>(
            key: _tableKey,
            emptyMessage: 'No customers found.',
            loadPage: ({required page, required perPage}) =>
                services.customers.listPaginated(
                  page: page,
                  perPage: perPage,
                  search: search.length >= 2 ? search : null,
                ),
            onRowTap: (c) {
              if (_splitPane) {
                setState(() => _selectedId = c.id);
              } else {
                context.go('/customers/${c.id}');
              }
            },
            columns: const [
              TableColumnDef(label: 'Name', flex: 2, cellBuilder: _nameCell),
              TableColumnDef(label: 'Phone', flex: 1.2, cellBuilder: _phoneCell),
              TableColumnDef(label: 'Email', flex: 1.5, cellBuilder: _emailCell),
              TableColumnDef(label: 'Pets', flex: 0.6, align: TextAlign.center, cellBuilder: _petsCell),
              TableColumnDef(label: 'City', flex: 1, cellBuilder: _cityCell),
              TableColumnDef(label: 'Balance', flex: 1, align: TextAlign.right, cellBuilder: _balanceCell),
              TableColumnDef(label: 'Status', flex: 0.8, align: TextAlign.center, cellBuilder: _statusCell),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: canCreate && !_splitPane
          ? FloatingActionButton(
              onPressed: _openCreateCustomer,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: _splitPane
          ? Row(
              children: [
                Expanded(flex: 5, child: table),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 4,
                  child: _selectedId == null
                      ? const Center(
                          child: Text(
                            'Select a customer',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : CustomerDetailBody(id: _selectedId!, compact: true),
                ),
              ],
            )
          : table,
    );
  }

  static Widget _nameCell(BuildContext context, Customer c) => Text(
        c.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );

  static Widget _phoneCell(BuildContext context, Customer c) =>
      Text(c.phone, style: const TextStyle(color: AppTheme.textSecondary));

  static Widget _emailCell(BuildContext context, Customer c) => Text(
        c.email ?? '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      );

  static Widget _petsCell(BuildContext context, Customer c) =>
      Text('${c.pets?.length ?? 0}');

  static Widget _cityCell(BuildContext context, Customer c) =>
      Text(c.city ?? '—', style: const TextStyle(color: AppTheme.textSecondary));

  static Widget _balanceCell(BuildContext context, Customer c) {
    final balance = c.outstandingBalance ?? 0;
    if (balance <= 0) return const Text('—');
    return Text(
      '₹${balance.toStringAsFixed(2)}',
      style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600),
    );
  }

  static Widget _statusCell(BuildContext context, Customer c) => Text(
        c.isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: c.isActive ? AppTheme.accent : AppTheme.danger,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      );
}
