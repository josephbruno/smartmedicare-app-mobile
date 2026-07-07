import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/purchase.dart';

class SupplierListScreen extends StatelessWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();

    return Scaffold(
      body: AppPaginatedTable<Supplier>(
        loadPage: ({required page, required perPage}) =>
            services.suppliers.listPaginated(page: page, perPage: perPage),
        columns: const [
          TableColumnDef(label: 'Name', flex: 2, cellBuilder: _nameCell),
          TableColumnDef(label: 'Phone', flex: 1.2, cellBuilder: _phoneCell),
          TableColumnDef(label: 'Email', flex: 1.5, cellBuilder: _emailCell),
          TableColumnDef(label: 'GSTIN', flex: 1.2, cellBuilder: _gstinCell),
        ],
      ),
    );
  }

  static Widget _nameCell(BuildContext context, Supplier s) => Text(
        s.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );

  static Widget _phoneCell(BuildContext context, Supplier s) => Text(s.phone);

  static Widget _emailCell(BuildContext context, Supplier s) => Text(s.email ?? '—');

  static Widget _gstinCell(BuildContext context, Supplier s) => Text(s.gstin ?? '—');
}
