import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_date_range_picker.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/emr.dart';
import '../../data/models/shop.dart';
import '../../data/models/visit_report.dart';
import 'report_date_range.dart';
import 'report_formatters.dart';
import 'widgets/report_charts.dart';

/// Super-admin visit report: Common / All doctors / Individual doctor.
class VisitReportScreen extends StatefulWidget {
  const VisitReportScreen({super.key});

  @override
  State<VisitReportScreen> createState() => _VisitReportScreenState();
}

class _VisitReportScreenState extends State<VisitReportScreen> {
  String _mode = 'common'; // common | all_doctors | doctor
  String _preset = 'month';
  ReportDateRange _range = ReportDateRange.preset('month');
  String _groupBy = 'day';
  String _status = 'all';
  String _visitType = 'all';
  int? _branchId;
  int? _doctorId;

  bool _loading = true;
  String? _error;
  VisitReportData? _data;
  List<Branch> _branches = [];
  List<DoctorLite> _doctors = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final services = context.read<AppServices>();
      final results = await Future.wait([
        services.branches.list(),
        services.emr.listDoctors(),
      ]);
      if (!mounted) return;
      setState(() {
        _branches = (results[0] as List<Branch>).where((b) => b.isActive).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _doctors = results[1] as List<DoctorLite>;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doctorId = _mode == 'doctor' ? _doctorId : null;
      final data = await context.read<AppServices>().reports.visits(
            dateFrom: _range.fromYmd,
            dateTo: _range.toYmd,
            branchId: _branchId,
            doctorId: doctorId,
            status: _status,
            visitType: _visitType,
            groupBy: _groupBy,
          );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyPreset(String key) {
    setState(() {
      _preset = key;
      _range = ReportDateRange.preset(key);
      if (key == 'year' || key == 'last_month') {
        _groupBy = 'month';
      } else if (key == 'today' || key == 'yesterday' || key == 'week') {
        _groupBy = 'day';
      }
    });
    _load();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showAppDateRangePicker(
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
      final days = picked.end.difference(picked.start).inDays;
      _groupBy = days > 45 ? 'month' : 'day';
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final crossCount = isMobile ? 2 : 4;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _Toolbar(
            mode: _mode,
            preset: _preset,
            range: _range,
            groupBy: _groupBy,
            status: _status,
            visitType: _visitType,
            branchId: _branchId,
            doctorId: _doctorId,
            branches: _branches,
            doctors: _doctors,
            onMode: (m) {
              setState(() {
                _mode = m;
                if (m == 'doctor' && _doctorId == null && _doctors.isNotEmpty) {
                  _doctorId = _doctors.first.id;
                }
              });
              _load();
            },
            onPreset: _applyPreset,
            onCustomRange: _pickCustomRange,
            onGroupBy: (v) {
              setState(() => _groupBy = v);
              _load();
            },
            onStatus: (v) {
              setState(() => _status = v);
              _load();
            },
            onVisitType: (v) {
              setState(() => _visitType = v);
              _load();
            },
            onBranch: (v) {
              setState(() => _branchId = v);
              _load();
            },
            onDoctor: (v) {
              setState(() => _doctorId = v);
              _load();
            },
            onRefresh: _load,
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, style: const TextStyle(color: AppTheme.danger)),
                        ),
                      )
                    : _data == null
                        ? const Center(child: Text('No data'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: EdgeInsets.all(isMobile ? 12 : 16),
                              children: [
                                if (_mode == 'all_doctors')
                                  ..._allDoctorsBody(_data!, crossCount)
                                else
                                  ..._commonBody(_data!, crossCount, isMobile),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  List<Widget> _kpiRow(VisitReportSummary s, int crossCount) {
    return [
      GridView.count(
        crossAxisCount: crossCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: ResponsiveLayout.isMobile(context) ? 1.35 : 1.7,
        children: [
          ReportKpiCard(
            title: 'Visits',
            value: '${s.visits}',
            subtitle: '${s.uniquePatients} patients',
            icon: Icons.medical_services_outlined,
            color: AppTheme.primary,
          ),
          ReportKpiCard(
            title: 'Billed',
            value: '${s.billed}',
            subtitle: '${s.open} open · ${s.onHold} hold',
            icon: Icons.receipt_long_outlined,
            color: AppTheme.accent,
          ),
          ReportKpiCard(
            title: 'Billable total',
            value: formatReportCurrencyCompact(s.billableTotal),
            subtitle: 'Service + treatment + medicine',
            icon: Icons.payments_outlined,
            color: const Color(0xFF0F766E),
          ),
          ReportKpiCard(
            title: 'Food on visits',
            value: formatReportCurrencyCompact(s.foodTotal),
            subtitle: 'Pet food lines only',
            icon: Icons.restaurant_outlined,
            color: const Color(0xFFB45309),
          ),
        ],
      ),
    ];
  }

  List<Widget> _commonBody(VisitReportData data, int crossCount, bool isMobile) {
    final s = data.summary;
    final periodLabels = data.byPeriod.map((e) => e.label).toList();
    final statusData = [
      for (var i = 0; i < data.byStatus.length; i++)
        ChartDatum(
          label: titleCaseStatus(data.byStatus[i].key),
          value: data.byStatus[i].count.toDouble(),
          color: chartColorAt(i),
        ),
    ];
    final typeData = [
      for (var i = 0; i < data.byVisitType.length; i++)
        ChartDatum(
          label: data.byVisitType[i].key,
          value: data.byVisitType[i].count.toDouble(),
          color: chartColorAt(i + 2),
        ),
    ];

    return [
      ..._kpiRow(s, crossCount),
      const SizedBox(height: 16),
      ReportSectionCard(
        title: _groupBy == 'month' ? 'Visits by month' : 'Visits by day',
        subtitle: _range.label,
        height: 280,
        child: periodLabels.isEmpty
            ? const ReportEmptyChart()
            : ReportBarChart(
                labels: periodLabels.length > 14
                    ? periodLabels.sublist(periodLabels.length - 14)
                    : periodLabels,
                series: [
                  (
                    name: 'Visits',
                    color: AppTheme.primary,
                    values: (periodLabels.length > 14
                            ? data.byPeriod.sublist(data.byPeriod.length - 14)
                            : data.byPeriod)
                        .map((e) => e.visits.toDouble())
                        .toList(),
                  ),
                ],
              ),
      ),
      const SizedBox(height: 16),
      if (isMobile) ...[
        ReportSectionCard(
          title: 'Status mix',
          height: 260,
          child: statusData.isEmpty
              ? const ReportEmptyChart()
              : ReportPieChart(data: statusData),
        ),
        const SizedBox(height: 16),
        ReportSectionCard(
          title: 'Visit type',
          height: 260,
          child: typeData.isEmpty
              ? const ReportEmptyChart()
              : ReportDonutChart(
                  data: typeData,
                  centerValue: '${s.visits}',
                  centerLabel: 'visits',
                ),
        ),
      ] else
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ReportSectionCard(
                title: 'Status mix',
                height: 280,
                child: statusData.isEmpty
                    ? const ReportEmptyChart()
                    : ReportPieChart(data: statusData),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ReportSectionCard(
                title: 'Visit type',
                height: 280,
                child: typeData.isEmpty
                    ? const ReportEmptyChart()
                    : ReportDonutChart(
                        data: typeData,
                        centerValue: '${s.visits}',
                        centerLabel: 'visits',
                      ),
              ),
            ),
          ],
        ),
      const SizedBox(height: 16),
      ReportSectionCard(
        title: 'Revenue mix (visit lines)',
        height: 280,
        child: ReportBarChart(
          labels: const ['Service', 'Treatment', 'Medicine', 'Food'],
          series: [
            (
              name: 'Amount',
              color: AppTheme.primary,
              values: [
                s.serviceChargeTotal,
                s.treatmentTotal,
                s.medicineTotal,
                s.foodTotal,
              ],
            ),
          ],
          barColors: [
            chartColorAt(0),
            chartColorAt(1),
            chartColorAt(2),
            const Color(0xFFB45309),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _LineTable(
        title: 'Treatments',
        rows: data.treatments,
        empty: 'No treatments in this period.',
      ),
      const SizedBox(height: 12),
      _LineTable(
        title: 'Medicines',
        rows: data.medicines,
        empty: 'No medicines in this period.',
      ),
      const SizedBox(height: 12),
      _LineTable(
        title: 'Pet food on visits',
        rows: data.foodLines,
        empty: 'No pet food lines on visits.',
        highlight: true,
      ),
      const SizedBox(height: 12),
      _ServiceProductTable(rows: data.serviceProducts),
      const SizedBox(height: 16),
      _VisitDetailTable(rows: data.visits),
    ];
  }

  List<Widget> _allDoctorsBody(VisitReportData data, int crossCount) {
    final doctors = data.byDoctor;
    final labels = doctors.take(10).map((d) => d.doctorName.split(' ').first).toList();
    return [
      ..._kpiRow(data.summary, crossCount),
      const SizedBox(height: 16),
      ReportSectionCard(
        title: 'Visits by doctor',
        height: 280,
        child: labels.isEmpty
            ? const ReportEmptyChart()
            : ReportBarChart(
                labels: labels,
                series: [
                  (
                    name: 'Visits',
                    color: AppTheme.primary,
                    values: doctors.take(10).map((d) => d.visits.toDouble()).toList(),
                  ),
                  (
                    name: 'Billed',
                    color: AppTheme.accent,
                    values: doctors.take(10).map((d) => d.billed.toDouble()).toList(),
                  ),
                ],
              ),
      ),
      const SizedBox(height: 16),
      ReportSectionCard(
        title: 'Billable by doctor',
        height: 280,
        child: labels.isEmpty
            ? const ReportEmptyChart()
            : ReportBarChart(
                labels: labels,
                series: [
                  (
                    name: 'Billable',
                    color: const Color(0xFF0F766E),
                    values: doctors.take(10).map((d) => d.billableTotal).toList(),
                  ),
                ],
                barColors: [
                  for (var i = 0; i < labels.length; i++) chartColorAt(i),
                ],
              ),
      ),
      const SizedBox(height: 16),
      _DoctorComparisonTable(
        rows: doctors,
        onOpen: (row) {
          if (row.doctorId == null) return;
          setState(() {
            _mode = 'doctor';
            _doctorId = row.doctorId;
          });
          _load();
        },
      ),
    ];
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.mode,
    required this.preset,
    required this.range,
    required this.groupBy,
    required this.status,
    required this.visitType,
    required this.branchId,
    required this.doctorId,
    required this.branches,
    required this.doctors,
    required this.onMode,
    required this.onPreset,
    required this.onCustomRange,
    required this.onGroupBy,
    required this.onStatus,
    required this.onVisitType,
    required this.onBranch,
    required this.onDoctor,
    required this.onRefresh,
  });

  final String mode;
  final String preset;
  final ReportDateRange range;
  final String groupBy;
  final String status;
  final String visitType;
  final int? branchId;
  final int? doctorId;
  final List<Branch> branches;
  final List<DoctorLite> doctors;
  final ValueChanged<String> onMode;
  final ValueChanged<String> onPreset;
  final VoidCallback onCustomRange;
  final ValueChanged<String> onGroupBy;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onVisitType;
  final ValueChanged<int?> onBranch;
  final ValueChanged<int?> onDoctor;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Visit & Treatment Report',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Based on visit records only · Super admin',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'common', label: Text('Common')),
                  ButtonSegment(value: 'all_doctors', label: Text('All doctors')),
                  ButtonSegment(value: 'doctor', label: Text('By doctor')),
                ],
                selected: {mode},
                onSelectionChanged: (s) => onMode(s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
                ),
              ),
              for (final key in const ['today', 'week', 'month', 'last_month', 'year'])
                ChoiceChip(
                  label: Text(_presetLabel(key), style: const TextStyle(fontSize: 12)),
                  selected: preset == key,
                  onSelected: (_) => onPreset(key),
                  visualDensity: VisualDensity.compact,
                ),
              ActionChip(
                label: Text(
                  preset == 'custom' ? range.label : 'Custom',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: onCustomRange,
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(
                width: 120,
                child: AppDropdownButtonFormField<String>(
                  value: groupBy,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Group',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'day', child: Text('Day')),
                    DropdownMenuItem(value: 'month', child: Text('Month')),
                  ],
                  onChanged: (v) {
                    if (v != null) onGroupBy(v);
                  },
                ),
              ),
              SizedBox(
                width: 140,
                child: AppDropdownButtonFormField<String>(
                  value: status,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(value: 'bill_on_hold', child: Text('On hold')),
                    DropdownMenuItem(value: 'billed', child: Text('Billed')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (v) {
                    if (v != null) onStatus(v);
                  },
                ),
              ),
              SizedBox(
                width: 150,
                child: AppDropdownButtonFormField<String>(
                  value: visitType,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All types')),
                    DropdownMenuItem(value: 'consultation', child: Text('Consultation')),
                    DropdownMenuItem(value: 'followup', child: Text('Follow-up')),
                    DropdownMenuItem(value: 'surgery', child: Text('Surgery')),
                    DropdownMenuItem(value: 'wellness', child: Text('Wellness')),
                    DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
                  ],
                  onChanged: (v) {
                    if (v != null) onVisitType(v);
                  },
                ),
              ),
              if (branches.length > 1)
                SizedBox(
                  width: 160,
                  child: AppDropdownButtonFormField<int?>(
                    value: branchId,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Branch',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All branches')),
                      for (final b in branches)
                        DropdownMenuItem(value: b.id, child: Text(b.name)),
                    ],
                    onChanged: onBranch,
                  ),
                ),
              if (mode == 'doctor')
                SizedBox(
                  width: 180,
                  child: AppDropdownButtonFormField<int?>(
                    value: doctorId,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Doctor',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      for (final d in doctors)
                        DropdownMenuItem(value: d.id, child: Text(d.name)),
                    ],
                    onChanged: onDoctor,
                  ),
                ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _presetLabel(String key) => switch (key) {
        'today' => 'Today',
        'week' => 'Week',
        'month' => 'Month',
        'last_month' => 'Last month',
        'year' => 'Year',
        _ => key,
      };
}

class _LineTable extends StatelessWidget {
  const _LineTable({
    required this.title,
    required this.rows,
    required this.empty,
    this.highlight = false,
  });

  final String title;
  final List<VisitReportLineRow> rows;
  final String empty;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return ReportSectionCard(
      title: title,
      subtitle: rows.isEmpty ? empty : '${rows.length} items',
      child: rows.isEmpty
          ? Text(empty, style: const TextStyle(color: AppTheme.textSecondary))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: highlight
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 4, child: Text('Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      Expanded(child: Text('Qty', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      Expanded(child: Text('Visits', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                    ],
                  ),
                ),
                for (final r in rows.take(15))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            r.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                              color: highlight ? const Color(0xFF9A3412) : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text('${r.qty}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
                        ),
                        Expanded(
                          child: Text('${r.visits}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            formatReportCurrency(r.amount),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ServiceProductTable extends StatelessWidget {
  const _ServiceProductTable({required this.rows});

  final List<VisitReportLineRow> rows;

  @override
  Widget build(BuildContext context) {
    return ReportSectionCard(
      title: 'Service charge products',
      subtitle: rows.isEmpty ? 'No service charges' : '${rows.length} products',
      child: rows.isEmpty
          ? const Text('No service charges in this period.', style: TextStyle(color: AppTheme.textSecondary))
          : Column(
              children: [
                for (final r in rows.take(12))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(r.name, style: const TextStyle(fontSize: 12))),
                        Text('${r.count ?? r.visits}×', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(width: 12),
                        Text(formatReportCurrency(r.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DoctorComparisonTable extends StatelessWidget {
  const _DoctorComparisonTable({required this.rows, required this.onOpen});

  final List<VisitReportDoctorRow> rows;
  final ValueChanged<VisitReportDoctorRow> onOpen;

  @override
  Widget build(BuildContext context) {
    return ReportSectionCard(
      title: 'Doctor comparison',
      subtitle: 'Tap a row to open individual report',
      child: rows.isEmpty
          ? const Text('No doctor data.', style: TextStyle(color: AppTheme.textSecondary))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 44,
                columns: const [
                  DataColumn(label: Text('Doctor')),
                  DataColumn(label: Text('Visits'), numeric: true),
                  DataColumn(label: Text('Billed'), numeric: true),
                  DataColumn(label: Text('Service'), numeric: true),
                  DataColumn(label: Text('Treatment'), numeric: true),
                  DataColumn(label: Text('Medicine'), numeric: true),
                  DataColumn(label: Text('Food'), numeric: true),
                  DataColumn(label: Text('Total'), numeric: true),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      onSelectChanged: r.doctorId == null ? null : (_) => onOpen(r),
                      cells: [
                        DataCell(Text(r.doctorName, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text('${r.visits}')),
                        DataCell(Text('${r.billed}')),
                        DataCell(Text(formatReportCurrency(r.serviceCharge))),
                        DataCell(Text(formatReportCurrency(r.treatmentTotal))),
                        DataCell(Text(formatReportCurrency(r.medicineTotal))),
                        DataCell(Text(
                          formatReportCurrency(r.foodTotal),
                          style: TextStyle(
                            color: r.foodTotal > 0 ? const Color(0xFF9A3412) : null,
                            fontWeight: r.foodTotal > 0 ? FontWeight.w600 : null,
                          ),
                        )),
                        DataCell(Text(
                          formatReportCurrency(r.billableTotal),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        )),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _VisitDetailTable extends StatelessWidget {
  const _VisitDetailTable({required this.rows});

  final List<VisitReportVisitRow> rows;

  @override
  Widget build(BuildContext context) {
    return ReportSectionCard(
      title: 'Visit details',
      subtitle: rows.isEmpty ? 'No visits' : 'Showing ${rows.length} visits',
      child: rows.isEmpty
          ? const Text('No visits in this period.', style: TextStyle(color: AppTheme.textSecondary))
          : SizedBox(
              height: 420,
              child: AppPaginatedTable<VisitReportVisitRow>(
                emptyMessage: 'No visits',
                headerFontSize: 9,
                cellFontSize: 12,
                loadPage: ({required page, required perPage}) async {
                  final pageData = paginateList(rows, page: page, perPage: perPage);
                  return (items: pageData.items, meta: pageData.meta);
                },
                columns: [
                  TableColumnDef(
                    label: 'Visit #',
                    flex: 1.1,
                    cellBuilder: (c, v) => Text(v.visitNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  TableColumnDef(label: 'Date', flex: 0.9, cellBuilder: (c, v) => Text(v.visitDate)),
                  TableColumnDef(label: 'Pet', flex: 1, cellBuilder: (c, v) => Text(v.petName ?? '—')),
                  TableColumnDef(label: 'Doctor', flex: 1, cellBuilder: (c, v) => Text(v.doctorName ?? '—')),
                  TableColumnDef(label: 'Type', flex: 0.9, cellBuilder: (c, v) => Text(v.visitType)),
                  TableColumnDef(
                    label: 'Status',
                    flex: 0.8,
                    cellBuilder: (c, v) => Text(titleCaseStatus(v.status)),
                  ),
                  TableColumnDef(
                    label: 'Total',
                    flex: 1,
                    align: TextAlign.right,
                    cellBuilder: (c, v) => Text(
                      formatReportCurrency(v.billableTotal),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
