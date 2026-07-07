import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/purchase.dart';

class PurchaseListScreen extends StatelessWidget {
  const PurchaseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final canCreate = context.watch<AuthSession>().hasPermission(AppPermissions.purchasesCreate);

    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => context.go('/purchases/new'),
              child: const Icon(Icons.add),
            )
          : null,
      body: AppPaginatedTable<Purchase>(
        loadPage: ({required page, required perPage}) =>
            services.purchases.listPaginated(page: page, perPage: perPage),
        onRowTap: (p) => context.go('/purchases/${p.id}'),
        columns: const [
          TableColumnDef(label: 'Purchase #', flex: 1.2, cellBuilder: _numberCell),
          TableColumnDef(label: 'Supplier', flex: 2, cellBuilder: _supplierCell),
          TableColumnDef(label: 'Date', flex: 1, cellBuilder: _dateCell),
          TableColumnDef(
            label: 'Amount',
            flex: 1,
            align: TextAlign.right,
            cellBuilder: _amountCell,
          ),
          TableColumnDef(
            label: 'Status',
            flex: 0.8,
            align: TextAlign.center,
            cellBuilder: _statusCell,
          ),
        ],
      ),
    );
  }

  static Widget _numberCell(BuildContext context, Purchase p) => Text(
        p.purchaseNumber,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );

  static Widget _supplierCell(BuildContext context, Purchase p) =>
      Text(p.supplier?.name ?? '—');

  static Widget _dateCell(BuildContext context, Purchase p) => Text(p.purchaseDate);

  static Widget _amountCell(BuildContext context, Purchase p) => Text(
        '₹${p.totalAmount.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      );

  static Widget _statusCell(BuildContext context, Purchase p) => Text(
        p.status,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      );
}
