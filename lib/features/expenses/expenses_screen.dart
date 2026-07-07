import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/expense.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();

    return Scaffold(
      body: AppPaginatedTable<Expense>(
        loadPage: ({required page, required perPage}) =>
            services.expenses.listPaginated(page: page, perPage: perPage),
        columns: const [
          TableColumnDef(label: 'Expense #', flex: 1.2, cellBuilder: _numberCell),
          TableColumnDef(label: 'Category', flex: 1.5, cellBuilder: _categoryCell),
          TableColumnDef(label: 'Date', flex: 1, cellBuilder: _dateCell),
          TableColumnDef(label: 'Description', flex: 2, cellBuilder: _descCell),
          TableColumnDef(
            label: 'Amount',
            flex: 1,
            align: TextAlign.right,
            cellBuilder: _amountCell,
          ),
        ],
      ),
    );
  }

  static Widget _numberCell(BuildContext context, Expense e) => Text(
        e.expenseNumber,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );

  static Widget _categoryCell(BuildContext context, Expense e) =>
      Text(e.category?.name ?? '—');

  static Widget _dateCell(BuildContext context, Expense e) => Text(e.expenseDate);

  static Widget _descCell(BuildContext context, Expense e) => Text(
        e.description ?? '—',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );

  static Widget _amountCell(BuildContext context, Expense e) => Text(
        '₹${e.amount.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      );
}
