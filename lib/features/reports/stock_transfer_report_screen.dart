import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/shop.dart';
import '../../data/models/stock_transfer.dart';
import '../../data/services/reports_service.dart';
import 'report_date_range.dart';
import 'report_formatters.dart';

class StockTransferReportScreen extends StatefulWidget {
  const StockTransferReportScreen({super.key});

  @override
  State<StockTransferReportScreen> createState() =>
      _StockTransferReportScreenState();
}

class _StockTransferReportScreenState extends State<StockTransferReportScreen> {
  String _preset = 'month';
  ReportDateRange _range = ReportDateRange.preset('month');
  String? _status;
  int? _fromBranchId;
  int? _toBranchId;

  List<Branch> _branches = [];
  StockTransferReportSummary? _summary;
  int _tableEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBranches());
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await context.read<AppServices>().branches.list();
      if (!mounted) return;
      setState(() => _branches = branches.where((b) => b.isActive).toList());
    } catch (_) {}
  }

  void _reloadTable() => setState(() => _tableEpoch++);

  void _applyPreset(String key) {
    setState(() {
      _preset = key;
      _range = ReportDateRange.preset(key);
      _tableEpoch++;
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _range.from, end: _range.to),
    );
    if (picked == null) return;
    setState(() {
      _preset = 'custom';
      _range = ReportDateRange(
        from: picked.start,
        to: picked.end,
        label: 'Custom range',
      );
      _tableEpoch++;
    });
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'accepted':
        return AppTheme.accent;
      case 'pending':
        return AppTheme.warning;
      case 'rejected':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(),
          if (_summary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SummaryChip(label: 'Total', value: '${_summary!.total}', color: AppTheme.primary),
                  _SummaryChip(label: 'Pending', value: '${_summary!.pending}', color: AppTheme.warning),
                  _SummaryChip(label: 'Accepted', value: '${_summary!.accepted}', color: AppTheme.accent),
                  _SummaryChip(label: 'Rejected', value: '${_summary!.rejected}', color: AppTheme.danger),
                  _SummaryChip(label: 'Cancelled', value: '${_summary!.cancelled}', color: AppTheme.textSecondary),
                  _SummaryChip(
                    label: 'Qty requested',
                    value: formatReportNumber(_summary!.requestedQty),
                    color: AppTheme.primary,
                  ),
                  _SummaryChip(
                    label: 'Qty accepted',
                    value: formatReportNumber(_summary!.acceptedQty),
                    color: AppTheme.accent,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: AppPaginatedTable<StockTransfer>(
              key: ValueKey(
                '$_tableEpoch-$_status-$_fromBranchId-$_toBranchId-${_range.fromYmd}-${_range.toYmd}',
              ),
              emptyMessage: 'No stock transfers in this period.',
              loadPage: ({required page, required perPage}) async {
                final result = await services.reports.stockTransfers(
                  fromDate: _range.fromYmd,
                  toDate: _range.toYmd,
                  status: _status,
                  fromBranchId: _fromBranchId,
                  toBranchId: _toBranchId,
                  page: page,
                  perPage: perPage,
                );
                if (mounted && page == 1) {
                  final summary = result.summary;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _summary = summary);
                  });
                }
                return (items: result.items, meta: result.meta);
              },
              onRowTap: (t) => context.push('/stock-transfers/${t.id}'),
              columns: [
                TableColumnDef(
                  label: 'Transfer #',
                  flex: 1.1,
                  cellBuilder: (_, t) => Text(
                    t.transferNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TableColumnDef(
                  label: 'From',
                  flex: 1.2,
                  cellBuilder: (_, t) => Text(t.fromBranchName ?? '—'),
                ),
                TableColumnDef(
                  label: 'To',
                  flex: 1.2,
                  cellBuilder: (_, t) => Text(t.toBranchName ?? '—'),
                ),
                TableColumnDef(
                  label: 'Items',
                  flex: 0.7,
                  align: TextAlign.center,
                  cellBuilder: (_, t) => Text('${t.items.length}'),
                ),
                TableColumnDef(
                  label: 'Requested by',
                  flex: 1.1,
                  cellBuilder: (_, t) => Text(t.requestedByName ?? '—'),
                ),
                TableColumnDef(
                  label: 'Date',
                  flex: 1,
                  cellBuilder: (_, t) => Text(shortDateLabel(t.createdAt)),
                ),
                TableColumnDef(
                  label: 'Status',
                  flex: 0.9,
                  align: TextAlign.center,
                  cellBuilder: (_, t) {
                    final color = _statusColor(t.status);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        titleCaseStatus(t.status),
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

  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stock Transfer Report',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Shop-wide transfer history (Super Admin)',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _preset == 'custom' ? null : _preset,
                hint: Text(_preset == 'custom' ? _range.label : 'Period'),
                items: ReportDateRange.presetOptions.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) _applyPreset(v);
                },
              ),
              OutlinedButton.icon(
                onPressed: _pickCustomRange,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text('${_range.fromYmd} → ${_range.toYmd}'),
              ),
              DropdownButton<String?>(
                value: _status,
                hint: const Text('All statuses'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All statuses')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (v) {
                  setState(() {
                    _status = v;
                    _tableEpoch++;
                  });
                },
              ),
              DropdownButton<int?>(
                value: _fromBranchId,
                hint: const Text('From branch'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('From: All')),
                  ..._branches.map(
                    (b) => DropdownMenuItem(value: b.id, child: Text('From: ${b.name}')),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _fromBranchId = v;
                    _tableEpoch++;
                  });
                },
              ),
              DropdownButton<int?>(
                value: _toBranchId,
                hint: const Text('To branch'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('To: All')),
                  ..._branches.map(
                    (b) => DropdownMenuItem(value: b.id, child: Text('To: ${b.name}')),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _toBranchId = v;
                    _tableEpoch++;
                  });
                },
              ),
              IconButton(onPressed: _reloadTable, icon: const Icon(Icons.refresh)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
