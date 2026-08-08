import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
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
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Purchases',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                if (canCreate)
                  FilledButton.icon(
                    onPressed: () => context.go('/purchases/new'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Purchase'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AppPaginatedTable<Purchase>(
              loadPage: ({required page, required perPage}) =>
                  services.purchases.listPaginated(page: page, perPage: perPage),
              onRowTap: (p) => context.go('/purchases/${p.id}'),
              headerFontSize: 9,
              cellFontSize: 12,
              columns: const [
                TableColumnDef(label: 'Purchase #', flex: 1.2, cellBuilder: _numberCell),
                TableColumnDef(label: 'Supplier', flex: 1.8, cellBuilder: _supplierCell),
                TableColumnDef(label: 'Branch', flex: 1.5, cellBuilder: _branchCell),
                TableColumnDef(label: 'Date', flex: 1, cellBuilder: _dateCell),
                TableColumnDef(
                  label: 'Amount',
                  flex: 1,
                  align: TextAlign.right,
                  cellBuilder: _amountCell,
                ),
                TableColumnDef(
                  label: 'Due',
                  flex: 1,
                  align: TextAlign.right,
                  cellBuilder: _dueCell,
                ),
                TableColumnDef(
                  label: 'Payment',
                  flex: 0.9,
                  align: TextAlign.center,
                  cellBuilder: _paymentCell,
                ),
                TableColumnDef(
                  label: 'Status',
                  flex: 0.8,
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

  static Widget _numberCell(BuildContext context, Purchase p) => Text(
        p.purchaseNumber,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      );

  static Widget _supplierCell(BuildContext context, Purchase p) => Text(
        p.supplier?.name ?? '—',
        style: const TextStyle(fontSize: 12),
      );

  static Widget _branchCell(BuildContext context, Purchase p) => Text(
        p.branchName ?? '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      );

  static Widget _dateCell(BuildContext context, Purchase p) => Text(
        p.dateOnly,
        style: const TextStyle(fontSize: 12),
      );

  static Widget _amountCell(BuildContext context, Purchase p) => Text(
        '₹${p.totalAmount.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      );

  static Widget _dueCell(BuildContext context, Purchase p) {
    final due = p.dueAmount ?? 0;
    if (due <= 0) {
      return const Text(
        '—',
        textAlign: TextAlign.right,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      );
    }
    return Text(
      '₹${due.toStringAsFixed(2)}',
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: AppTheme.danger,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }

  static Widget _paymentCell(BuildContext context, Purchase p) {
    final status = (p.paymentStatus ?? '').toLowerCase();
    final due = p.dueAmount ?? 0;
    final label = status.isNotEmpty
        ? status
        : (due > 0 ? 'unpaid' : 'paid');

    final Color color;
    switch (label) {
      case 'paid':
        color = AppTheme.accent;
      case 'partial':
        color = AppTheme.warning;
      default:
        color = due > 0 ? AppTheme.danger : AppTheme.textSecondary;
    }

    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }

  static Widget _statusCell(BuildContext context, Purchase p) => Text(
        p.status,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      );
}
