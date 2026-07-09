import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/emr.dart';
import 'quick_visit_sheet.dart';
import 'widgets/visit_card.dart';

class VisitListScreen extends StatefulWidget {
  const VisitListScreen({super.key});

  @override
  State<VisitListScreen> createState() => _VisitListScreenState();
}

class _VisitListScreenState extends State<VisitListScreen> {
  static const _filters = ['all', 'open', 'bill_on_hold', 'completed'];

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

  String _filterLabel(String status) {
    switch (status) {
      case 'all':
        return 'All';
      case 'bill_on_hold':
        return 'On hold';
      case 'open':
        return 'Open';
      case 'completed':
        return 'Completed';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  IconData? _filterIcon(String status, {required bool selected}) {
    switch (status) {
      case 'open':
        return Icons.inbox_outlined;
      case 'bill_on_hold':
        return Icons.schedule_outlined;
      case 'completed':
        return Icons.check_circle_outline_rounded;
      default:
        return selected ? Icons.check_rounded : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = context.watch<AuthSession>().hasPermission('emr.visits.create');
    final services = context.read<AppServices>();
    final search = _search.text.trim();
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, isMobile ? 12 : 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Visit Records',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: isMobile ? 22 : 24,
                                ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "View and manage your pet's visit history",
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canCreate) ...[
                      const SizedBox(width: 12),
                      if (!isMobile)
                        OutlinedButton.icon(
                          onPressed: () => showQuickVisitSheet(context),
                          icon: const Icon(Icons.bolt, size: 18),
                          label: const Text('Quick visit'),
                        ),
                      if (!isMobile) const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => context.push('/emr/visits/new'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New visit'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Search visits...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters
                        .map(
                          (status) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _VisitFilterChip(
                              label: _filterLabel(status),
                              icon: _filterIcon(status, selected: _statusFilter == status),
                              selected: _statusFilter == status,
                              accentColor: status == 'completed' ? AppTheme.accent : null,
                              onSelected: () => setState(() => _statusFilter = status),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
              mobileItemBuilder: isMobile
                  ? (context, visit) => VisitRecordCard(
                        visit: visit,
                        statusColor: _statusColor(visit.status),
                        onTap: () => context.push('/emr/visits/${visit.id}'),
                      )
                  : null,
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
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        VisitRecordCard.statusLabel(v.status),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
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

class _VisitFilterChip extends StatelessWidget {
  const _VisitFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.accentColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? Colors.white
        : (accentColor ?? AppTheme.textSecondary);

    return FilterChip(
      selected: selected,
      showCheckmark: false,
      avatar: icon != null
          ? Icon(icon, size: 16, color: iconColor)
          : (selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null),
      label: Text(label),
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
