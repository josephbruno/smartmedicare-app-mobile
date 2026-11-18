import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/ist.dart';
import '../../core/utils/save_file.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../core/widgets/web_page.dart';
import '../../data/models/api_response.dart';
import '../../data/models/emr.dart';
import 'quick_visit_sheet.dart';
import 'widgets/visit_card.dart';

/// Visit records — mirrors `frontend/src/pages/emr/PetVisitListPage.vue`:
/// today's schedule strip, KPIs, filters, status tabs, table.
class VisitListScreen extends StatefulWidget {
  const VisitListScreen({super.key});

  @override
  State<VisitListScreen> createState() => _VisitListScreenState();
}

class _VisitListScreenState extends State<VisitListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _appliedSearch = '';
  String? _status;
  String? _visitType;
  String? _dateFrom;
  String? _dateTo;
  String _sort = 'date_desc';
  int _reloadToken = 0;
  PaginationMetaView _meta = const PaginationMetaView();
  List<PatientAppointment> _today = const [];
  bool _exporting = false;

  static const _statusOptions = {
    'open': 'Open',
    'bill_on_hold': 'Bill On Hold',
    'completed': 'Completed',
    'billed': 'Billed',
    'cancelled': 'Cancelled',
  };
  static const _typeOptions = {
    'consultation': 'Consultation',
    'followup': 'Follow-up',
    'surgery': 'Surgery',
    'wellness': 'Wellness',
    'emergency': 'Emergency',
  };
  static const _tabs = [
    ('all', 'All', Icons.layers),
    ('completed', 'Completed', Icons.check_circle_outline),
    ('open', 'Open', Icons.radio_button_unchecked),
    ('bill_on_hold', 'On Hold', Icons.pause_circle),
    ('billed', 'Billed', Icons.account_balance_wallet),
    ('cancelled', 'Cancelled', Icons.cancel_outlined),
  ];
  static const _speciesEmoji = {'dog': '🐶', 'cat': '🐱', 'bird': '🐦', 'rabbit': '🐰', 'fish': '🐟'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadToday());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadToday() async {
    try {
      final list = await context.read<AppServices>().emr.todayAppointments();
      if (mounted) {
        setState(() => _today = list.where((a) => const ['scheduled', 'confirmed'].contains(a.status)).toList());
      }
    } catch (_) {
      // non-critical
    }
  }

  void _reload() => setState(() => _reloadToken++);

  Map<String, dynamic> get _filters => {
        'sort': _sort,
        'status': _status,
        'visit_type': _visitType,
        'date_from': _dateFrom,
        'date_to': _dateTo,
      };

  bool get _hasFilters =>
      _appliedSearch.isNotEmpty || _status != null || _visitType != null || _dateFrom != null;

  void _toggleSort(String key) {
    _sort = switch ((key, _sort)) {
      ('date', 'date_desc') => 'date_asc',
      ('date', _) => 'date_desc',
      ('number', 'number_desc') => 'number_asc',
      _ => 'number_desc',
    };
    _reload();
  }

  int _tabCount(String key) {
    int n(String k) => _meta.stat(k).toInt();
    return switch (key) {
      'all' => n('total'),
      _ => n(key) != 0 ? n(key) : n('${key}_count'),
    };
  }

  static String _title(String s) => s
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  static (String, PillTone, IconData?) _statusMeta(String status) => switch (status) {
        'completed' => ('Completed', PillTone.green, Icons.check_circle),
        'billed' => ('Billed', PillTone.green, null),
        'bill_on_hold' => ('Bill On Hold', PillTone.amber, Icons.pause_circle),
        'cancelled' => ('Cancelled', PillTone.red, null),
        'open' => ('Open', PillTone.blue, null),
        _ => (_title(status), PillTone.grey, null),
      };

  static PillTone _typeTone(String t) => switch (t) {
        'surgery' => PillTone.red,
        'emergency' => PillTone.amber,
        'wellness' => PillTone.green,
        'followup' => PillTone.purple,
        _ => PillTone.blue,
      };

  static IconData _typeIcon(String t) => switch (t) {
        'surgery' => Icons.healing_outlined,
        'emergency' => Icons.warning_amber_outlined,
        'wellness' => Icons.favorite_border,
        'followup' => Icons.replay,
        _ => Icons.medical_services_outlined,
      };

  bool _canEdit(PetVisit v) => !const ['billed', 'cancelled'].contains(v.status);

  Future<void> _rowMenu(String key, PetVisit v) async {
    switch (key) {
      case 'timeline':
        context.push('/emr/pets/${v.petId}/timeline');
      case 'invoice':
        context.push('/invoices/${v.invoiceId}');
      case 'copy':
        await Clipboard.setData(ClipboardData(text: v.visitNumber));
        if (mounted) AppMessenger.success(context, 'Copied');
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final res = await context.read<AppServices>().emr.listVisitsPaginated(
            page: 1,
            perPage: 1000,
            search: _appliedSearch,
            filters: _filters,
          );
      await saveCsv(
        'visits-${todayIst()}.csv',
        const ['Visit #', 'Date', 'Time', 'Patient', 'Owner', 'Type', 'Status', 'Chief Complaint'],
        res.items.map((v) => [
              v.visitNumber,
              v.visitDate,
              v.visitTime,
              v.pet?.name,
              v.pet?.customerName,
              _title(v.visitType),
              _statusMeta(v.status).$1,
              v.chiefComplaint,
            ]),
      );
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<KpiData> _kpis() {
    final total = _meta.stat('total');
    String pct(double n) => total == 0 ? '0% of total' : '${(n / total * 1000).round() / 10}% of total';
    final ch = _meta.change();
    return [
      KpiData(
        label: 'Total Visits',
        value: '${total.toInt()}',
        icon: Icons.people_outline,
        sub: ch == null
            ? (_meta.stats?['change_label']?.toString() ?? 'vs last month')
            : '${ch >= 0 ? '▲' : '▼'} ${ch.abs()}% ${_meta.stats?['change_label'] ?? 'vs last month'}',
        subUp: (ch ?? 0) >= 0 && ch != null,
        series: _meta.series('total'),
      ),
      KpiData(
        label: 'Completed',
        value: '${_meta.stat('finished').toInt()}',
        icon: Icons.check_circle_outline,
        tone: KpiTone.green,
        sub: '${pct(_meta.stat('finished'))} (incl. billed)',
        series: _meta.series('finished'),
      ),
      KpiData(
        label: 'In Progress',
        value: '${_meta.stat('in_progress').toInt()}',
        icon: Icons.schedule,
        tone: KpiTone.sky,
        sub: '${pct(_meta.stat('in_progress'))} (open + on hold)',
        series: _meta.series('in_progress'),
      ),
      KpiData(
        label: 'Cancelled',
        value: '${_meta.stat('cancelled').toInt()}',
        icon: Icons.error_outline,
        tone: KpiTone.red,
        sub: pct(_meta.stat('cancelled')),
        series: _meta.series('cancelled'),
      ),
    ];
  }

  Widget _todayStrip() {
    if (_today.isEmpty) return const SizedBox.shrink();
    return WebCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        const Icon(Icons.calendar_today_outlined, size: 16, color: AppTokens.primary),
        const SizedBox(width: 8),
        Text("Today's schedule (${_today.length})",
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppTokens.text1)),
        const SizedBox(width: 16),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final a in _today)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTokens.border),
                  ),
                  child: Row(children: [
                    Text(a.appointmentTime.length >= 5 ? a.appointmentTime.substring(0, 5) : a.appointmentTime,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text(a.pet?.name ?? '—'),
                    const SizedBox(width: 6),
                    Text(a.customer?.name ?? '', style: const TextStyle(color: AppTokens.text3)),
                    const SizedBox(width: 8),
                    StatusPill(_title(a.appointmentType), tone: _typeTone(a.appointmentType)),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: () => context.push('/emr/visits/new?appointment_id=${a.id}'),
                      child: const Text('Start Visit →'),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission(AppPermissions.emrVisitsCreate);
    final isCheckIn = canCreate && !auth.hasPermission(AppPermissions.emrVisitsEdit);
    final vet = auth.isVeterinary;
    final services = context.read<AppServices>();
    final activeTab = _status ?? 'all';

    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        title: 'Visit Records',
        subtitle: 'View and manage all consultation and medical visit history.',
        icon: Icons.medical_services_outlined,
        breadcrumbs: const [Crumb('Medical Records'), Crumb('Visit Records')],
        actions: [
          OutlinedButton.icon(
            onPressed: _exporting ? null : _export,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Export'),
          ),
          if (canCreate)
            OutlinedButton.icon(
              onPressed: () => showQuickVisitSheet(context),
              icon: const Icon(Icons.flash_on_outlined, size: 18),
              label: Text(isCheckIn ? 'Quick check-in' : 'Quick Visit'),
            ),
          if (canCreate) FilledButton(onPressed: () => context.push('/emr/visits/new'), child: const Text('New Visit')),
        ],
        kpis: _kpis(),
        filters: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _todayStrip(),
          FilterCard(
            searchController: _search,
            searchHint: 'Search by pet, owner, visit no. or complaint...',
            onSearchChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                if (!mounted) return;
                _appliedSearch = v.trim();
                _reload();
              });
            },
            filters: [
              FilterSelect<String>(hint: 'All Status', options: _statusOptions, value: _status, onChanged: (v) {
                _status = v;
                _reload();
              }),
              FilterSelect<String>(hint: 'All Visit Types', options: _typeOptions, value: _visitType, onChanged: (v) {
                _visitType = v;
                _reload();
              }),
            ],
            trailing: [
              DateRangeFilter(
                from: _dateFrom,
                to: _dateTo,
                onChanged: (f, t) {
                  _dateFrom = f;
                  _dateTo = t;
                  _reload();
                },
              ),
            ],
            onReset: () {
              _search.clear();
              _appliedSearch = '';
              _status = null;
              _visitType = null;
              _dateFrom = null;
              _dateTo = null;
              _sort = 'date_desc';
              _reload();
            },
            resetEnabled: _hasFilters,
          ),
          // Status tabs with counts (web `vl-tabs`).
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final t in _tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: activeTab == t.$1,
                      showCheckmark: false,
                      selectedColor: AppTokens.primaryLight,
                      side: BorderSide(color: activeTab == t.$1 ? AppTokens.primary : AppTokens.border),
                      avatar: Icon(t.$3, size: 16, color: activeTab == t.$1 ? AppTokens.primary : AppTokens.text3),
                      label: Text('${t.$2} (${_tabCount(t.$1)})',
                          style: TextStyle(
                              fontWeight: activeTab == t.$1 ? FontWeight.w600 : FontWeight.w500,
                              color: activeTab == t.$1 ? AppTokens.primary : AppTokens.text2)),
                      onSelected: (_) {
                        _status = t.$1 == 'all' ? null : t.$1;
                        _reload();
                      },
                    ),
                  ),
              ]),
            ),
          ),
        ]),
        body: AppPaginatedTable<PetVisit>(
          key: ValueKey('visits-$_reloadToken'),
          perPage: 10,
          emptyMessage: 'No visits found',
          loadPage: ({required page, required perPage}) => services.emr.listVisitsPaginated(
            page: page,
            perPage: perPage,
            search: _appliedSearch,
            filters: _filters,
            withStats: true,
          ),
          onLoaded: (m) {
            if (mounted) setState(() => _meta = PaginationMetaView(m));
          },
          sortKey: _sort.startsWith('date') ? 'date' : 'number',
          sortAsc: _sort.endsWith('asc'),
          onSort: _toggleSort,
          onRowTap: (v) => context.push('/emr/visits/${v.id}'),
          mobileItemBuilder: (context, v) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VisitRecordCard(
              visit: v,
              onTap: () => context.push('/emr/visits/${v.id}'),
              statusColor: switch (_statusMeta(v.status).$2) {
                PillTone.green => AppTokens.success,
                PillTone.amber => AppTokens.warning,
                PillTone.red => AppTokens.error,
                PillTone.blue => AppTokens.primary,
                _ => AppTokens.text3,
              },
            ),
          ),
          columns: [
            TableColumnDef(
              label: 'Visit #',
              flex: 1.2,
              minWidth: 120,
              sortKey: 'number',
              cellBuilder: (_, v) =>
                  Text(v.visitNumber, style: const TextStyle(color: AppTokens.primary, fontWeight: FontWeight.w600)),
            ),
            TableColumnDef(
              label: vet ? 'Pet / Patient' : 'Patient',
              flex: 1.8,
              minWidth: 170,
              cellBuilder: (_, v) {
                final p = v.pet;
                final sub = [p?.species, p?.breed].where((e) => (e ?? '').isNotEmpty).join(' · ');
                return Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFF3E8FF),
                    backgroundImage: (p?.imageUrl ?? '').isNotEmpty ? NetworkImage(p!.imageUrl!) : null,
                    child: (p?.imageUrl ?? '').isNotEmpty
                        ? null
                        : Text(_speciesEmoji[(p?.species ?? '').toLowerCase()] ?? '🐾'),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(p?.name ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (sub.isNotEmpty)
                        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                    ]),
                  ),
                ]);
              },
            ),
            TableColumnDef(
              label: vet ? 'Owner' : 'Responsible Party',
              flex: 1.4,
              minWidth: 140,
              cellBuilder: (_, v) => Text(v.pet?.customerName ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            TableColumnDef(
              label: 'Type',
              flex: 1.2,
              minWidth: 130,
              cellBuilder: (_, v) => StatusPill(_title(v.visitType), tone: _typeTone(v.visitType), icon: _typeIcon(v.visitType)),
            ),
            TableColumnDef(
              label: 'Date & Time',
              flex: 1.2,
              minWidth: 130,
              sortKey: 'date',
              cellBuilder: (_, v) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_today_outlined, size: 13, color: AppTokens.text3),
                  const SizedBox(width: 6),
                  Text(formatDateIst(v.visitDate)),
                ]),
                if ((v.visitTime ?? '').isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.schedule, size: 13, color: AppTokens.text3),
                    const SizedBox(width: 6),
                    Text(v.visitTime!.length >= 5 ? v.visitTime!.substring(0, 5) : v.visitTime!,
                        style: const TextStyle(color: AppTokens.text3)),
                  ]),
              ]),
            ),
            TableColumnDef(
              label: 'Status',
              flex: 1.1,
              minWidth: 120,
              cellBuilder: (_, v) {
                final m = _statusMeta(v.status);
                return StatusPill(m.$1, tone: m.$2, icon: m.$3);
              },
            ),
            TableColumnDef(
              label: 'Chief Complaint',
              flex: 1.8,
              minWidth: 170,
              cellBuilder: (_, v) => Tooltip(
                message: v.chiefComplaint ?? '',
                child: Text((v.chiefComplaint ?? '').isEmpty ? '—' : v.chiefComplaint!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ),
            TableColumnDef(
              label: 'Actions',
              flex: 1.4,
              minWidth: 160,
              cellBuilder: (_, v) => Row(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 10)),
                  onPressed: () => context.push('/emr/visits/${v.id}'),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View'),
                ),
                const SizedBox(width: 6),
                TableIconButton(
                  icon: Icons.edit_outlined,
                  plain: true,
                  tooltip: _canEdit(v) ? 'Edit visit' : 'Billed and cancelled visits cannot be edited',
                  onPressed: _canEdit(v) ? () => context.push('/emr/visits/${v.id}/edit') : null,
                ),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  tooltip: 'More actions for ${v.visitNumber}',
                  onSelected: (k) => _rowMenu(k, v),
                  itemBuilder: (_) => [
                    if (v.petId != 0) const PopupMenuItem(value: 'timeline', child: Text('Patient timeline')),
                    if (v.invoiceId != null) const PopupMenuItem(value: 'invoice', child: Text('Open invoice')),
                    const PopupMenuItem(value: 'copy', child: Text('Copy visit number')),
                  ],
                  child: const TableIconButton(icon: Icons.more_horiz, plain: true, onPressed: null),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
