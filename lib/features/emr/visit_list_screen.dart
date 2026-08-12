import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/emr.dart';
import 'quick_visit_sheet.dart';
import 'widgets/visit_card.dart';

final _visitDateDisplay = DateFormat('dd-MM-yyyy');

String _formatVisitDate(String raw) {
  if (raw.isEmpty) return '—';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return _visitDateDisplay.format(parsed);
}

class VisitListScreen extends StatefulWidget {
  const VisitListScreen({super.key});

  @override
  State<VisitListScreen> createState() => _VisitListScreenState();
}

ButtonStyle get _visitOutlinedButtonStyle => OutlinedButton.styleFrom(
      foregroundColor: AppTheme.primary,
      side: const BorderSide(color: AppTheme.primary, width: 1.5),
      minimumSize: const Size(0, 44),
      fixedSize: const Size.fromHeight(44),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );

ButtonStyle get _visitFilledButtonStyle => FilledButton.styleFrom(
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 44),
      fixedSize: const Size.fromHeight(44),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );

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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          hintText: 'Search visits...',
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => setState(() {}),
                        onChanged: (_) {
                          if (_search.text.trim().isEmpty) setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 150,
                      child: AppDropdownButtonFormField<String>(
                        value: _statusFilter,
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(value: 'open', child: Text('Open')),
                          DropdownMenuItem(value: 'bill_on_hold', child: Text('On hold')),
                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _statusFilter = v);
                        },
                      ),
                    ),
                    if (canCreate) ...[
                      if (!isMobile) ...[
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => showQuickVisitSheet(context),
                          icon: const Icon(Icons.bolt, size: 18),
                          label: const Text('Quick visit'),
                          style: _visitOutlinedButtonStyle,
                        ),
                      ],
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => context.push('/emr/visits/new'),
                        style: _visitFilledButtonStyle,
                        child: const Text('New visit'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: AppPaginatedTable<PetVisit>(
              key: ValueKey('$_statusFilter-$search'),
              emptyMessage: search.length >= 2
                  ? 'No visits match your search.'
                  : 'No visit records yet.',
              emptyBuilder: (context) => _VisitEmptyState(
                hasSearch: search.length >= 2,
                canCreate: canCreate,
                onQuickVisit: () => showQuickVisitSheet(context),
                onNewVisit: () => context.push('/emr/visits/new'),
              ),
              headerFontSize: 9,
              cellFontSize: 12,
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
                  cellBuilder: (c, v) => Text(_formatVisitDate(v.visitDate)),
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

class _VisitEmptyState extends StatelessWidget {
  const _VisitEmptyState({
    required this.hasSearch,
    required this.canCreate,
    required this.onQuickVisit,
    required this.onNewVisit,
  });

  final bool hasSearch;
  final bool canCreate;
  final VoidCallback onQuickVisit;
  final VoidCallback onNewVisit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              hasSearch ? Icons.search_off_rounded : Icons.medical_services_outlined,
              size: 36,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasSearch ? 'No matching visits' : 'No visit records yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              hasSearch
                  ? 'Try a different search or clear filters to see all visits.'
                  : 'Create a visit to start recording consultations, treatments, and billing.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          if (canCreate && !hasSearch) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onQuickVisit,
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('Quick visit'),
                  style: _visitOutlinedButtonStyle,
                ),
                FilledButton(
                  onPressed: onNewVisit,
                  style: _visitFilledButtonStyle,
                  child: const Text('New visit'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
