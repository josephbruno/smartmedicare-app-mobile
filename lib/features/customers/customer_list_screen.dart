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
  int _reloadToken = 0;
  int? _selectedId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _splitPane => useWebLikeShell(context) && MediaQuery.sizeOf(context).width >= 1100;

  void _refreshTable({int? selectCustomerId}) {
    if (!mounted) return;
    setState(() {
      _reloadToken++;
      if (selectCustomerId != null) _selectedId = selectCustomerId;
    });
  }

  Future<void> _openCreateCustomer() async {
    final created = await context.push<Customer>('/customers/new');
    if (!mounted || created == null) return;
    _refreshTable(selectCustomerId: created.id);
  }

  void _applySearch() => setState(() {});

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
                  decoration: InputDecoration(
                    hintText: 'Search customers by name or phone…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    helperText: search.isNotEmpty && search.length <= 2
                        ? 'Type more than 2 characters to search'
                        : null,
                    helperMaxLines: 1,
                    suffixIcon: search.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _search.clear();
                              _applySearch();
                            },
                          )
                        : null,
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => _applySearch(),
                  onSubmitted: (_) => _applySearch(),
                ),
              ),
              if (canCreate) ...[
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
            // Remount when search or reload token changes so loadPage re-runs.
            // Search applies only after more than 2 characters.
            key: ValueKey('${search.length > 2 ? search : ''}-$_reloadToken'),
            emptyMessage: search.length > 2
                ? 'No customers match your search.'
                : 'No customers found.',
            headerFontSize: 9,
            cellFontSize: 12,
            loadPage: ({required page, required perPage}) =>
                services.customers.listPaginated(
                  page: page,
                  perPage: perPage,
                  search: search.length > 2 ? search : null,
                ),
            isRowSelected: (c) => c.id == _selectedId,
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
              TableColumnDef(label: 'Pets', flex: 0.6, align: TextAlign.center, cellBuilder: _petsCell),
              TableColumnDef(label: 'Balance', flex: 1, align: TextAlign.right, cellBuilder: _balanceCell),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
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

  static Widget _petsCell(BuildContext context, Customer c) =>
      Text('${c.pets?.length ?? 0}');

  static Widget _balanceCell(BuildContext context, Customer c) {
    final balance = c.outstandingBalance ?? 0;
    if (balance <= 0) return const Text('—');
    return Text(
      '₹${balance.toStringAsFixed(2)}',
      style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600),
    );
  }
}
