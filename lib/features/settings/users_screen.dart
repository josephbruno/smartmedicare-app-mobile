import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/user.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();

    return Scaffold(
      body: AppPaginatedTable<User>(
        loadPage: ({required page, required perPage}) =>
            services.users.listPaginated(page: page, perPage: perPage),
        columns: const [
          TableColumnDef(label: 'Name', flex: 1.5, cellBuilder: _nameCell),
          TableColumnDef(label: 'Email', flex: 2, cellBuilder: _emailCell),
          TableColumnDef(label: 'Phone', flex: 1.2, cellBuilder: _phoneCell),
          TableColumnDef(label: 'Roles', flex: 1.5, cellBuilder: _rolesCell),
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

  static Widget _nameCell(BuildContext context, User u) => Text(
        u.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );

  static Widget _emailCell(BuildContext context, User u) => Text(u.email);

  static Widget _phoneCell(BuildContext context, User u) => Text(u.phone ?? '—');

  static Widget _rolesCell(BuildContext context, User u) => Text(u.roles.join(', '));

  static Widget _statusCell(BuildContext context, User u) =>
      Text(u.isActive ? 'Active' : 'Inactive');
}
