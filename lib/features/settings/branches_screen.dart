import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/shop.dart';

class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();

    return Scaffold(
      body: AppPaginatedTable<Branch>(
        loadPage: ({required page, required perPage}) async {
          final all = await services.branches.list();
          return paginateList(all, page: page, perPage: perPage);
        },
        columns: const [
          TableColumnDef(label: 'Branch', flex: 2, cellBuilder: _nameCell),
          TableColumnDef(label: 'Code', flex: 1, cellBuilder: _codeCell),
          TableColumnDef(
            label: 'Main',
            flex: 0.7,
            align: TextAlign.center,
            cellBuilder: _mainCell,
          ),
          TableColumnDef(
            label: 'Active',
            flex: 0.7,
            align: TextAlign.center,
            cellBuilder: _activeCell,
          ),
        ],
      ),
    );
  }

  static Widget _nameCell(BuildContext context, Branch b) => Text(
        b.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );

  static Widget _codeCell(BuildContext context, Branch b) => Text(b.code ?? '—');

  static Widget _mainCell(BuildContext context, Branch b) =>
      Text(b.isMain ? 'Yes' : '—');

  static Widget _activeCell(BuildContext context, Branch b) =>
      Text(b.isActive ? 'Yes' : 'No');
}
