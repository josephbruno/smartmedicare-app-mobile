import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../core/widgets/web_page.dart';
import '../../data/models/api_response.dart';
import '../../data/models/emr.dart';
import 'widgets/appointment_week_calendar.dart';

/// Patient appointments — mirrors `frontend/src/pages/emr/PatientAppointmentPage.vue`
/// (KPIs that act as tabs, filters, status tabs with counts, rows).
/// The app keeps its week-calendar view as an extra toggle.
class PatientAppointmentListScreen extends StatefulWidget {
  const PatientAppointmentListScreen({super.key});

  @override
  State<PatientAppointmentListScreen> createState() => _PatientAppointmentListScreenState();
}

class _PatientAppointmentListScreenState extends State<PatientAppointmentListScreen> {
  bool _calendarView = false;
  DateTime _weekStartDate = DateTime(
    mondayOfWeek(DateTime.now()).year,
    mondayOfWeek(DateTime.now()).month,
    mondayOfWeek(DateTime.now()).day,
  );

  final _search = TextEditingController();
  Timer? _debounce;
  String _appliedSearch = '';
  String? _status; // pending | completed | cancelled | no_show
  String? _type;
  String? _dateFrom;
  String? _dateTo;
  String _sort = 'date_desc';
  int _reloadToken = 0;
  PaginationMetaView _meta = const PaginationMetaView();

  static const _typeLabels = {
    'consultation': 'Consultation',
    'followup': 'Follow-up',
    'surgery': 'Surgery',
    'wellness': 'Wellness',
    'emergency': 'Emergency',
    'vaccination': 'Vaccination',
    'deworming': 'Deworming',
  };
  static const _statusFilterOptions = {
    'pending': 'Pending (scheduled, confirmed, in progress)',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    'no_show': 'No Show',
  };
  static const _sortOptions = {'date_desc': 'Date (Latest)', 'date_asc': 'Date (Earliest)', 'newest': 'Recently Added'};
  static const _tabs = [
    ('all', 'All', Icons.layers),
    ('completed', 'Completed', Icons.check_circle),
    ('pending', 'Pending', Icons.schedule),
    ('cancelled', 'Cancelled', Icons.cancel),
    ('no_show', 'No Show', Icons.block),
  ];
  static const _speciesEmoji = {'dog': '🐶', 'cat': '🐱', 'bird': '🐦', 'rabbit': '🐰', 'fish': '🐟'};

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _reloadToken++);

  void _setTab(String key) {
    _status = key == 'all' ? null : key;
    _reload();
  }

  void _openAppointment(PatientAppointment a) {
    if (a.visitId != null) {
      context.push('/emr/visits/${a.visitId}');
    } else {
      context.push('/emr/appointments/${a.id}/edit');
    }
  }

  static (String, PillTone, IconData) _statusMeta(String s) => switch (s) {
        'completed' => ('Completed', PillTone.green, Icons.check_circle),
        'cancelled' => ('Cancelled', PillTone.red, Icons.cancel),
        'no_show' => ('No Show', PillTone.grey, Icons.block),
        'in_progress' => ('In Progress', PillTone.blue, Icons.monitor_heart_outlined),
        'confirmed' => ('Confirmed', PillTone.amber, Icons.check_circle_outline),
        _ => ('Pending', PillTone.amber, Icons.schedule),
      };

  static PillTone _typeTone(String t) => switch (t) {
        'surgery' => PillTone.red,
        'emergency' => PillTone.amber,
        'wellness' || 'vaccination' || 'deworming' => PillTone.green,
        'followup' => PillTone.purple,
        _ => PillTone.blue,
      };

  Future<void> _confirm(PatientAppointment a) async {
    try {
      await context.read<AppServices>().emr.confirmAppointment(a.id);
      if (mounted) AppMessenger.success(context, 'Appointment confirmed');
      _reload();
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Failed to confirm: $e');
    }
  }

  Future<void> _cancel(PatientAppointment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel appointment'),
        content: Text('Cancel ${a.appointmentNumber ?? 'this appointment'} for ${a.pet?.name ?? 'the patient'}?'),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTokens.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().emr.cancelAppointment(a.id);
      if (mounted) AppMessenger.success(context, 'Appointment cancelled');
      _reload();
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Failed to cancel: $e');
    }
  }

  Future<void> _rowMenu(String key, PatientAppointment a) async {
    switch (key) {
      case 'start':
        context.push('/emr/visits/new?appointment_id=${a.id}');
      case 'confirm':
        await _confirm(a);
      case 'visit':
        context.push('/emr/visits/${a.visitId}');
      case 'timeline':
        context.push('/emr/pets/${a.petId}/timeline');
      case 'edit':
        context.push('/emr/appointments/${a.id}/edit');
      case 'copy':
        await Clipboard.setData(ClipboardData(text: a.appointmentNumber ?? '${a.id}'));
        if (mounted) AppMessenger.success(context, 'Copied');
    }
  }

  List<KpiData> _kpis() {
    final total = _meta.stat('total');
    String pct(double n) => total == 0 ? '0%' : '${(n / total * 1000).round() / 10}%';
    String sub(String key, String fallback, {bool inverse = false}) {
      final ch = _meta.change(key);
      if (ch == null) return fallback;
      return '${ch >= 0 ? '▲' : '▼'} ${ch.abs()}% · $fallback';
    }

    return [
      KpiData(
          label: 'Total Appointments',
          value: '${total.toInt()}',
          icon: Icons.calendar_today_outlined,
          sub: sub('total', _meta.stats?['change_label']?.toString() ?? 'vs last month'),
          subUp: (_meta.change('total') ?? 0) > 0,
          series: _meta.series('total')),
      KpiData(
          label: 'Completed',
          value: '${_meta.stat('completed').toInt()}',
          icon: Icons.check_circle_outline,
          tone: KpiTone.green,
          sub: sub('completed', pct(_meta.stat('completed'))),
          series: _meta.series('completed')),
      KpiData(
          label: 'Pending',
          value: '${_meta.stat('pending').toInt()}',
          icon: Icons.schedule,
          tone: KpiTone.orange,
          sub: sub('pending', pct(_meta.stat('pending'))),
          series: _meta.series('pending')),
      KpiData(
          label: 'Cancelled',
          value: '${_meta.stat('cancelled').toInt()}',
          icon: Icons.cancel_outlined,
          tone: KpiTone.red,
          sub: sub('cancelled', '${pct(_meta.stat('cancelled'))} (incl. no-show)'),
          series: _meta.series('cancelled')),
    ];
  }

  int _count(String key) {
    final c = _meta.meta?.raw['counts'];
    if (c is Map) return (c[key] as num?)?.toInt() ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission(AppPermissions.patientAppointmentsCreate);
    final canEdit = auth.hasPermission('patient_appointments.edit');
    final canCancel = auth.hasPermission('patient_appointments.cancel');
    final canStartVisit = auth.hasPermission('emr.visits.create');
    final desktop = useWebLikeShell(context);
    final activeTab = _status ?? 'all';
    const tabForKpi = ['all', 'completed', 'pending', 'cancelled'];
    final kpis = _kpis();

    final viewToggle = desktop
        ? SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('List'), icon: Icon(Icons.list)),
              ButtonSegment(value: true, label: Text('Week'), icon: Icon(Icons.calendar_view_week)),
            ],
            selected: {_calendarView},
            onSelectionChanged: (s) => setState(() => _calendarView = s.first),
          )
        : null;

    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        title: 'Patient Appointments',
        subtitle: 'Schedule and manage medical consultations for your patients.',
        icon: Icons.event_outlined,
        breadcrumbs: [Crumb(auth.responsiblePartiesLabel), const Crumb('Appointments')],
        actions: [
          if (viewToggle != null) viewToggle,
          if (canCreate)
            FilledButton(onPressed: () => context.push('/emr/appointments/new'), child: const Text('New Appointment')),
        ],
        // KPI cards double as tab shortcuts (web `setTab(kpi.tab)`).
        filters: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth < 768 ? 2 : 4;
              final w = (c.maxWidth - 12 * (cols - 1)) / cols;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                for (var i = 0; i < kpis.length; i++)
                  SizedBox(
                    width: w,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(onTap: () => _setTab(tabForKpi[i]), child: KpiCard(data: kpis[i])),
                    ),
                  ),
              ]);
            }),
          ),
          if (!_calendarView) ...[
            FilterCard(
              searchController: _search,
              searchHint: 'Search patient, pet, owner...',
              onSearchChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () {
                  if (!mounted) return;
                  _appliedSearch = v.trim();
                  _reload();
                });
              },
              filters: [
                FilterSelect<String>(hint: 'All statuses', options: _statusFilterOptions, value: _status, onChanged: (v) {
                  _status = v;
                  _reload();
                }),
                FilterSelect<String>(hint: 'All types', options: _typeLabels, value: _type, onChanged: (v) {
                  _type = v;
                  _reload();
                }),
                FilterSelect<String>(hint: 'Sort', options: _sortOptions, value: _sort, onChanged: (v) {
                  _sort = v ?? 'date_desc';
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
                _type = null;
                _dateFrom = null;
                _dateTo = null;
                _sort = 'date_desc';
                _reload();
              },
              resetEnabled:
                  _appliedSearch.isNotEmpty || _status != null || _type != null || _dateFrom != null || _sort != 'date_desc',
            ),
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
                        label: Text('${t.$2} (${_count(t.$1)})',
                            style: TextStyle(
                                fontWeight: activeTab == t.$1 ? FontWeight.w600 : FontWeight.w500,
                                color: activeTab == t.$1 ? AppTokens.primary : AppTokens.text2)),
                        onSelected: (_) => _setTab(t.$1),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ]),
        body: _calendarView
            ? AppointmentWeekCalendar(
                weekStart: _weekStartDate,
                onWeekChanged: (d) => setState(() => _weekStartDate = DateTime(d.year, d.month, d.day)),
                onAppointmentTap: _openAppointment,
              )
            : AppPaginatedTable<PatientAppointment>(
                key: ValueKey('appointments-$_reloadToken'),
                perPage: 10,
                emptyMessage: 'No appointments found',
                loadPage: ({required page, required perPage}) => services.emr.listAppointmentsPaginated(
                  page: page,
                  perPage: perPage,
                  search: _appliedSearch,
                  status: _status,
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                  filters: {'sort': _sort, 'appointment_type': _type},
                  withStats: true,
                ),
                onLoaded: (m) {
                  if (mounted) setState(() => _meta = PaginationMetaView(m));
                },
                onRowTap: _openAppointment,
                columns: [
                  TableColumnDef(
                    label: 'Date & Time',
                    flex: 1.3,
                    minWidth: 150,
                    cellBuilder: (_, a) {
                      final d = DateTime.tryParse(a.appointmentDate);
                      return Row(children: [
                        Container(
                          width: 46,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTokens.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(children: [
                            Text(d == null ? '' : DateFormat('MMM').format(d).toUpperCase(),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTokens.primary)),
                            Text(d == null ? '—' : '${d.day}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTokens.text1)),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(_time(a.appointmentTime), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(d == null ? '' : DateFormat('EEEE').format(d),
                              style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                        ]),
                      ]);
                    },
                  ),
                  TableColumnDef(
                    label: auth.isVeterinary ? 'Pet' : 'Patient',
                    flex: 1.6,
                    minWidth: 160,
                    cellBuilder: (_, a) {
                      final p = a.pet;
                      final g = (p?.gender ?? '').toLowerCase();
                      return Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFF3E8FF),
                          backgroundImage: (p?.imageUrl ?? '').isNotEmpty ? NetworkImage(p!.imageUrl!) : null,
                          child: (p?.imageUrl ?? '').isNotEmpty ? null : Text(_speciesEmoji[(p?.species ?? '').toLowerCase()] ?? '🐾'),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text(p?.name ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${_title(p?.species ?? 'Pet')}${g == 'male' ? ' ♂' : g == 'female' ? ' ♀' : ''}',
                              style: const TextStyle(fontSize: 12, color: AppTokens.text3),
                            ),
                          ]),
                        ),
                      ]);
                    },
                  ),
                  TableColumnDef(
                    label: auth.isVeterinary ? 'Owner' : 'Responsible Party',
                    flex: 1.3,
                    minWidth: 130,
                    cellBuilder: (_, a) => Text(a.customer?.name ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  TableColumnDef(
                    label: 'Doctor',
                    flex: 1.3,
                    minWidth: 130,
                    cellBuilder: (_, a) => Text(
                      (a.doctor?.name ?? '').isEmpty ? 'Unassigned' : 'Dr. ${a.doctor!.name.replaceFirst(RegExp(r'^Dr\.?\s*', caseSensitive: false), '')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: (a.doctor?.name ?? '').isEmpty ? AppTokens.text3 : AppTokens.text1),
                    ),
                  ),
                  TableColumnDef(
                    label: 'Type',
                    flex: 1.2,
                    minWidth: 120,
                    cellBuilder: (_, a) => StatusPill(_typeLabels[a.appointmentType] ?? _title(a.appointmentType), tone: _typeTone(a.appointmentType)),
                  ),
                  TableColumnDef(
                    label: 'Chief Complaint',
                    flex: 1.8,
                    minWidth: 170,
                    cellBuilder: (_, a) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text((a.chiefComplaint ?? '').isEmpty ? 'No complaint recorded' : a.chiefComplaint!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: (a.chiefComplaint ?? '').isEmpty ? AppTokens.text3 : AppTokens.text1)),
                      if ((a.notes ?? '').isNotEmpty)
                        Text(a.notes!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                    ]),
                  ),
                  TableColumnDef(
                    label: 'Status',
                    flex: 1.1,
                    minWidth: 120,
                    cellBuilder: (_, a) {
                      final m = _statusMeta(a.status);
                      return StatusPill(m.$1, tone: m.$2, icon: m.$3);
                    },
                  ),
                  TableColumnDef(
                    label: 'Actions',
                    flex: 1.1,
                    minWidth: 120,
                    cellBuilder: (_, a) {
                      final open = const ['scheduled', 'confirmed', 'in_progress'].contains(a.status);
                      return Row(mainAxisSize: MainAxisSize.min, children: [
                        if (!const ['completed', 'cancelled', 'no_show'].contains(a.status) && canCancel)
                          TableIconButton(
                            icon: Icons.close,
                            tooltip: 'Cancel appointment',
                            plain: true,
                            color: AppTokens.error,
                            onPressed: () => _cancel(a),
                          ),
                        const SizedBox(width: 6),
                        PopupMenuButton<String>(
                          tooltip: 'More actions for ${a.appointmentNumber ?? ''}',
                          onSelected: (k) => _rowMenu(k, a),
                          itemBuilder: (_) => [
                            if (open && canStartVisit) const PopupMenuItem(value: 'start', child: Text('Start visit')),
                            if (a.status == 'scheduled' && canEdit) const PopupMenuItem(value: 'confirm', child: Text('Confirm')),
                            if (open && canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            if (a.visitId != null) const PopupMenuItem(value: 'visit', child: Text('Open visit')),
                            if (a.petId != 0) const PopupMenuItem(value: 'timeline', child: Text('Patient timeline')),
                            const PopupMenuItem(value: 'copy', child: Text('Copy appointment number')),
                          ],
                          child: const TableIconButton(icon: Icons.more_vert, plain: true, onPressed: null),
                        ),
                      ]);
                    },
                  ),
                ],
              ),
      ),
    );
  }

  static String _title(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).replaceAll('_', ' ')}';

  static String _time(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $ampm';
  }
}
