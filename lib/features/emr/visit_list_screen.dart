import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/emr.dart';
import 'quick_visit_sheet.dart';

class VisitListScreen extends StatefulWidget {
  const VisitListScreen({super.key});

  @override
  State<VisitListScreen> createState() => _VisitListScreenState();
}

class _VisitListScreenState extends State<VisitListScreen> {
  String _statusFilter = 'all';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'billed':
      case 'completed':
        return AppTheme.accent;
      case 'bill_on_hold':
        return Colors.orange;
      case 'open':
        return AppTheme.primary;
      case 'cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = context.watch<AuthSession>().hasPermission('emr.visits.create');
    final services = context.read<AppServices>();
    final search = _search.text.trim();

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/emr/visits/new'),
              icon: const Icon(Icons.add),
              label: const Text('New visit'),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Visit Records',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (canCreate)
                  OutlinedButton.icon(
                    onPressed: () => showQuickVisitSheet(context),
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text('Quick visit'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search visits...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'open', 'bill_on_hold', 'completed', 'billed', 'cancelled']
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            s == 'all'
                                ? 'All'
                                : s == 'bill_on_hold'
                                    ? 'On hold'
                                    : s[0].toUpperCase() + s.substring(1),
                          ),
                          selected: _statusFilter == s,
                          onSelected: (_) => setState(() => _statusFilter = s),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AppPaginatedTable<PetVisit>(
              key: ValueKey('$_statusFilter-$search'),
              loadPage: ({required page, required perPage}) =>
                  services.emr.listVisitsPaginated(
                    page: page,
                    perPage: perPage,
                    status: _statusFilter,
                    search: search.length >= 2 ? search : null,
                  ),
              onRowTap: (v) => context.push('/emr/visits/${v.id}'),
              columns: [
                TableColumnDef(
                  label: 'Visit #',
                  flex: 1,
                  cellBuilder: (c, v) => Text(
                    v.visitNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TableColumnDef(
                  label: 'Pet',
                  flex: 1.2,
                  cellBuilder: (c, v) => Text(v.pet?.name ?? '—'),
                ),
                TableColumnDef(
                  label: 'Doctor',
                  flex: 1.2,
                  cellBuilder: (c, v) => Text(v.doctor?.name ?? '—'),
                ),
                TableColumnDef(
                  label: 'Date',
                  flex: 1,
                  cellBuilder: (c, v) => Text(v.visitDate),
                ),
                TableColumnDef(
                  label: 'Type',
                  flex: 0.9,
                  cellBuilder: (c, v) => Text(v.visitType),
                ),
                TableColumnDef(
                  label: 'Status',
                  flex: 0.9,
                  align: TextAlign.center,
                  cellBuilder: (c, v) {
                    final color = _statusColor(v.status);
                    return Text(
                      v.status,
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
