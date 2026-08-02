import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/purchase_return.dart';

class PurchaseReturnListScreen extends StatelessWidget {
  const PurchaseReturnListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final canCreate =
        context.watch<AuthSession>().hasPermission(AppPermissions.purchasesCreate);

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Supplier Returns',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                if (canCreate)
                  FilledButton.icon(
                    onPressed: () => context.go('/purchase-returns/new'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Return'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AppPaginatedTable<PurchaseReturn>(
              loadPage: ({required page, required perPage}) =>
                  services.purchaseReturns.listPaginated(page: page, perPage: perPage),
              onRowTap: (r) => context.go('/purchase-returns/${r.id}'),
              columns: const [
                TableColumnDef(label: 'Return #', flex: 1.2, cellBuilder: _numberCell),
                TableColumnDef(label: 'Supplier', flex: 1.8, cellBuilder: _supplierCell),
                TableColumnDef(label: 'Branch', flex: 1.4, cellBuilder: _branchCell),
                TableColumnDef(label: 'Date', flex: 1, cellBuilder: _dateCell),
                TableColumnDef(label: 'Reason', flex: 1, cellBuilder: _reasonCell),
                TableColumnDef(
                  label: 'Amount',
                  flex: 1,
                  align: TextAlign.right,
                  cellBuilder: _amountCell,
                ),
                TableColumnDef(
                  label: 'Status',
                  flex: 0.9,
                  align: TextAlign.center,
                  cellBuilder: _statusCell,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _numberCell(BuildContext context, PurchaseReturn r) => Text(
        r.returnNumber,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );

  static Widget _supplierCell(BuildContext context, PurchaseReturn r) =>
      Text(r.supplier?.name ?? '—');

  static Widget _branchCell(BuildContext context, PurchaseReturn r) => Text(
        r.branchName ?? '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppTheme.textSecondary),
      );

  static Widget _dateCell(BuildContext context, PurchaseReturn r) => Text(r.dateOnly);

  static Widget _reasonCell(BuildContext context, PurchaseReturn r) {
    final color = switch (r.reason.toLowerCase()) {
      'expired' => AppTheme.warning,
      'damaged' => AppTheme.danger,
      _ => AppTheme.textSecondary,
    };
    return Text(
      r.reasonLabel,
      style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 12),
    );
  }

  static Widget _amountCell(BuildContext context, PurchaseReturn r) => Text(
        '₹${r.totalAmount.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      );

  static Widget _statusCell(BuildContext context, PurchaseReturn r) => Text(
        r.status,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      );
}
